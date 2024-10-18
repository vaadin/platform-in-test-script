#!/bin/bash

. `dirname $0`/../repos.sh

REPOS=`echo "$REPOS$DEMOS" | cut -d ":" -f1 | sort -u | egrep -v 'spring-guides|spring-petclinic-vaadin-flow'`

usage() {
  cat <<EOF

Usage $0 [--help] | [--list=repo_name [update|grep-expr] merge] | [--all [update|grep-expr] merge] | [--merge=repo_name pr_number] | [--close=repo_name pr_number]

The list for all repositories is:
$REPOS

EOF
}

V=vaadin

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
        mkdir -p tmp
        cd tmp || exit 1
        rm -rf $arg
        git clone git@github.com:$V/$arg.git || exit 1
        cd $arg || exit 1
        gh pr checkout $N || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
        ;;
      --close*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        echo "https://github.com/$V/$arg/pull/$N"
        mkdir -p tmp
        cd tmp || exit 1
        rm -rf $arg
        git clone git@github.com:$V/$arg.git || exit 1
        cd $arg || exit 1
        gh pr checkout $N || exit 1
        gh pr close $N --delete-branch || exit 1
        ;;
    esac
  shift
done
