#!/bin/bash

. `dirname $0`/../repos.sh

REPOS=`echo "$REPOS$DEMOS" | cut -d ":" -f1 | sort -u | egrep -v 'spring-guides|spring-petclinic-vaadin-flow|_jdk'`

usage() {
  cat <<EOF

The list for all repositories is:
$REPOS

Usage $0 [--help] | [--list=repo_name [update|grep-expr] merge] | [--all [update|grep-expr] merge] | [--merge=repo_name pr_number] | [--close=repo_name pr_number] | [--start=branch_name vaadin_version]

  --help: show this help
  --list: list all PRs for the given repository
  --all: list all PRs for all repositories
  --merge: merge the given PR
  --close: close the given PR
  --start: create PR for the start wizard project

EOF
}

V=vaadin

## repositories in the list may carry their own owner (owner/name), otherwise they belong to $V
fullName() {
  case "$1" in
    */*) echo "$1";;
    *) echo "$V/$1";;
  esac
}

## verify that the tools, the network and the credentials are usable before doing anything
checkConnection() {
  for c in gh jq curl git
  do
    command -v $c >/dev/null 2>&1 || { echo "ERROR: '$c' is not installed or not in the PATH" >&2; exit 1; }
  done

  O=`gh api user --jq .login 2>&1`
  if [ $? != 0 ]; then
    if echo "$O" | egrep -qi 'connect|network|timeout|dial|no such host|resolve|EOF'; then
      echo "ERROR: cannot reach github.com, check your internet connection or https://githubstatus.com" >&2
    elif echo "$O" | egrep -qi '401|Bad credentials|expired|revoked|authentication'; then
      echo "ERROR: github credentials are not valid, run 'gh auth login' or export a valid GITHUB_TOKEN" >&2
    else
      echo "ERROR: cannot query the github API" >&2
    fi
    echo "$O" >&2
    exit 1
  fi
  U="$O"

  S=`gh api -i user 2>/dev/null | egrep -i '^X-OAuth-Scopes:' | cut -d: -f2- | tr -d ' \r'`
  case ",$S," in
    *,repo,*) ;;
    *) echo "WARN: the token used has no 'repo' scope [$S], listing may work but merging will fail" >&2;;
  esac

  if [ -n "$GITHUB_TOKEN" ]; then
    C=`curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user`
    [ "$C" = "200" ] || { echo "ERROR: GITHUB_TOKEN is set but rejected by the API (http $C), unset it or export a valid one" >&2; exit 1; }
  else
    echo "WARN: GITHUB_TOKEN is not set, --start queries the commits API anonymously and may be rate limited" >&2
  fi

  echo "> connected to github.com as $U"
}

checkout() {
    R=`fullName $1`
    D=`basename $1`
    mkdir -p tmp
    cd tmp || exit 1
    [ -d "$D" ] && rm -rf $D
    gh config set git_protocol https
    gh repo clone $R || exit 1
    # git clone git@github.com:$R.git || exit 1
    cd $D || exit 1
    [ -z "$2" ] || git checkout $2 || exit 1
}

getHash() {
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/repos/vaadin/$1/commits?sha=$2&per_page=100" \
    | jq -r '.[] | .sha + " " + (.commit.message | split("\n")[0])' \
    | grep "chore: Update Vaadin $3" | tail -1
}

## the check runs once, recursive calls inherit the result through the environment
if [ -n "$1" -a "$1" != "--help" -a -z "$PR_MERGE_CHECKED" ]; then
  checkConnection || exit 1
  export PR_MERGE_CHECKED=1
fi

arg=`echo "$1" | cut -d= -f2`
while [ -n "$1" ]; do
    case $1 in
      --help)
        usage && exit;;
      --list*)
        [ -z "$arg" ] && usage && exit 1
        R=`fullName $arg`
        # echo "# >> $R"
        J=`gh pr list --repo $R --json baseRefName,title,number,author,createdAt` || { echo "ERROR: cannot list the PRs of $R" >&2; exit 1; }
        H=`echo "$J" | jq -r '.[] | "\(.number)ç\(.baseRefName)ç\(.title)ç\(.author.login)ç\(.createdAt)"' | tr " " "_" | perl -p -e 's/T\d+:.*//g'`
        if [ -n "$2" ]; then
          [ "$2" = "update" ] && G="Update" || G="$2"
          H=`echo "$H" | grep "$G"`
        fi
        for i in $H
        do
          [ -n "$PR_MERGE_FOUND" ] && echo 1 >> "$PR_MERGE_FOUND"
          N=`echo "$i" | cut -d "ç" -f1`
          B=`echo "$i" | cut -d "ç" -f2`
          D=`echo "$i" | cut -d "ç" -f3`
          L=`echo "$i" | cut -d "ç" -f4`
          T=`echo "$i" | cut -d "ç" -f5`
          echo "  # > https://github.com/$R/pull/$N - ($B) $D - [$L $T]" | tr "ç" "\t"
          if [ "$3" = "merge" ]; then
            $0 --merge=$arg $N
          elif [ "$3" = "close" ]; then
            $0 --close=$arg $N
          else
            echo $0 --merge=$arg $N "## ($B) $D"
          fi
        done
        ;;
      --all)
        PR_MERGE_FOUND=`mktemp -t pr-merge`
        export PR_MERGE_FOUND
        for i in $REPOS
        do
          $0 --list=$i $2 $3
        done
        [ -s "$PR_MERGE_FOUND" ] || echo "> no PRs found matching '${2:-*}' in `echo "$REPOS" | wc -l | tr -d ' '` repositories"
        rm -f "$PR_MERGE_FOUND"
        ;;
      --merge*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        echo "https://github.com/`fullName $arg`/pull/$N"

        checkout $arg

        gh pr checkout $N || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
        ;;
      --close*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        echo "https://github.com/`fullName $arg`/pull/$N"
        checkout $arg

        gh pr checkout $N || exit 1
        gh pr close $N --delete-branch || exit 1
        ;;
      --start*)
        [ -z "$arg" ] && echo usage && exit 1
        N=$2
        [ -z "$2" ] && echo usage && exit 1
        shift
        checkout start
        H1=`getHash skeleton-starter-flow-spring $arg $N | awk '{print $1}'`
        H2=`getHash skeleton-starter-hilla-react $arg $N | awk '{print $1}'`
        pwd

# src/main/java//com/vaadin/starterwizard/HillaVersions.java
# private static final String SKELETON_STARTER_HILLA_REACT_PRERELEASE = "2fd67d2da1d7b93f18bdfa0d1725bdccd9435465";

# src/main/java//com/vaadin/starterwizard/generator/RawProjectProvider.java
#           // https://github.com/vaadin/skeleton-starter-flow-spring/commits/v24.8/
#             return "502c635430346cde0ac1d2ee6a0ff556eca25633";

        echo "skeleton-starter-flow-spring $H1 src/main/java//com/vaadin/starterwizard/generator/RawProjectProvider.java"
        echo "skeleton-starter-hilla-react $H2 src/main/java//com/vaadin/starterwizard/HillaVersions.java"
        ;;
    esac
  shift
done
