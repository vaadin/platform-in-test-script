#!/bin/bash

. `dirname $0`/../repos.sh

REPOS=`echo "$REPOS$DEMOS" | sort -u`

usage() {
  cat <<EOF

Usage $0 [--help] [--list=repo_name [update]] [--all [update]] [--merge=repo_name pr_number]

The list for all repositories is:
$REPOS

EOF
}

arg=`echo "$1" | cut -d= -f2`
while [ -n "$1" ]; do
    case $1 in
      --help) 
        usage && exit;;
      --list*)
        [ -z "$arg" ] && usage && exit 1
        H=`gh pr list --repo vaadin/$arg | tr "\t" "ç" | tr " " "_"`
        [ "$2" = "update" ] && shift && H=`echo "$H" | grep Update`
        for i in $H
        do
          D=`echo "$i" | cut -d "ç" -f2`
          N=`echo "$i" | cut -d "ç" -f1`
          echo "  > https://github.com/vaadin/$arg/pull/$N   -  $D" | tr "ç" "\t"
          echo $0 --merge=$arg $N "## $D"
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
        echo "https://github.com/vaadin/$arg/pull/$N"
        mkdir -p tmp
        cd tmp || exit 1
        rm -rf $arg
        git clone git@github.com:vaadin/$arg.git || exit 1
        cd $arg || exit 1
        gh pr checkout $N || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
    esac
  shift
done