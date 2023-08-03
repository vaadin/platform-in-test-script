#!/bin/bash

. `dirname $0`/../repos.sh

REPOS=`echo "$REPOS$DEMOS" | cut -d ":" -f1 | sort -u`

usage() {
  cat <<EOF

Usage $0 [--help] [--list=repo_name [update]] [--all [update]] [--merge=repo_name pr_number]

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
        [ "$arg" = mpr-demo ] && V=TatuLund
        H=`gh pr list --repo $V/$arg --json baseRefName,title,number | jq -r '.[] | "\(.number)ç\(.baseRefName)ç\(.title)"' | tr " " "_"`
        [ "$2" = "update" ] && shift && H=`echo "$H" | grep Update`
        for i in $H
        do
          D=`echo "$i" | cut -d "ç" -f3`
          N=`echo "$i" | cut -d "ç" -f1`
          B=`echo "$i" | cut -d "ç" -f2`
          echo "  > https://github.com/$V/$arg/pull/$N - ($B) $D" | tr "ç" "\t"
          echo $0 --merge=$arg $N "## ($B) $D"
        done
        ;;
      --all)
        for i in $REPOS
        do
          $0 --list=$i $2
        done
        ;;
      --merge*)
        N="$2"
        [ -z "$N" ] && echo usage && exit 1
        shift
        [ "$arg" = mpr-demo ] && V=TatuLund
        echo "https://github.com/$V/$arg/pull/$N"
        mkdir -p tmp
        cd tmp || exit 1
        rm -rf $arg
        git clone git@github.com:$V/$arg.git || exit 1
        cd $arg || exit 1
        gh pr checkout $N || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
    esac
  shift
done
