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

checkout() {
    mkdir -p tmp
    cd tmp || exit 1
    rm -rf $1
    git clone git@github.com:$V/$1.git || exit 1
    cd $1 || exit 1
    [ -z "$2" ] || git checkout $2 || exit 1
}

getHash() {
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/repos/vaadin/$1/commits?sha=$2&per_page=100" \
    | jq -r '.[] | .sha + " " + (.commit.message | split("\n")[0])' \
    | grep "chore: Update Vaadin $3" | tail -1
}

arg=`echo "$1" | cut -d= -f2`
while [ -n "$1" ]; do
    case $1 in
      --help)
        usage && exit;;
      --list*)
        [ -z "$arg" ] && usage && exit 1
        # echo "# >> $V/$arg"
        H=`gh pr list --repo $V/$arg --json baseRefName,title,number,author,createdAt | jq -r '.[] | "\(.number)ç\(.baseRefName)ç\(.title)ç\(.author.login)ç\(.createdAt)"' | tr " " "_" | perl -p -e 's/T\d+:.*//g'`
        if [ -n "$2" ]; then
          [ "$2" = "update" ] && G="Update" || G="$2"
          H=`echo "$H" | grep "$G"`
        fi
        for i in $H
        do
          N=`echo "$i" | cut -d "ç" -f1`
          B=`echo "$i" | cut -d "ç" -f2`
          D=`echo "$i" | cut -d "ç" -f3`
          L=`echo "$i" | cut -d "ç" -f4`
          T=`echo "$i" | cut -d "ç" -f5`
          echo "  # > https://github.com/$V/$arg/pull/$N - ($B) $D - [$L $T]" | tr "ç" "\t"
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
        for i in $REPOS
        do
          $0 --list=$i $2 $3
        done
        ;;
      --merge*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        echo "https://github.com/$V/$arg/pull/$N"
        checkout $arg

        gh pr checkout $N || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
        ;;
      --close*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        echo "https://github.com/$V/$arg/pull/$N"
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
