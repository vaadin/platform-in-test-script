#!/bin/bash

REPOS="
skeleton-starter-flow-spring/pulls
skeleton-starter-flow
component-starter-flow
skeleton-starter-flow-cdi
business-app-starter-flow
addon-starter-flow
bookstore-example
vaadin-form-example
flow-crm-tutorial
flow-crm-tutorial
vaadin-rest-example
vaadin-localization-example
vaadin-database-example
layout-examples
flow-quickstart-tutorial
flow-spring-examples
vaadin-oauth-example
base-starter-flow-osgi
base-starter-flow-karaf
base-starter-gradle
base-starter-spring-gradle
hilla-crm-tutorial
hilla-quickstart-tutorial
hilla-basics-tutorial
bakery-app-starter-flow-spring
starter-wizard
vaadin-leaflet-example
"

REPOS=`echo "$REPOS" | sort -u`

usage() {
  cat <<EOF

Usage $0 [--list=repo_name] [--all] [--merge=repo_name:pr_number]

The list for all repositories is:
$REPOS

EOF
}

arg=`echo "$1" | cut -d= -f2 | cut -d "/" -f1`
extra=`echo "$1" | cut -d= -f2 | cut -d "/" -f2`
while [ -n "$1" ]; do
    case $1 in
      --help) 
        usage && exit;;
      --list*)
        [ -z "$arg" ] && usage && exit 1
        H=`gh pr list --repo vaadin/$arg | tr "\t" "ç" | tr " " "_"`
        [ "$2" = "update" ] && H=`echo "$H" | grep Update`
        for i in $H
        do
          D=`echo "$i" | cut -d "ç" -f2`
          N=`echo "$i" | cut -d "ç" -f1`
          echo "  > https://github.com/vaadin/$arg/pull/$N   -  $D" | tr "ç" "\t"
          echo $0 --merge=$arg/$N
        done
        ;;
      --all)
        for i in $REPOS
        do
          $0 --list=$i $2
        done
        ;;
      --merge*)
        [ -z "$extra" ] && echo usage && exit 1
        echo "https://github.com/vaadin/$arg/pull/$extra"
        mkdir -p tmp
        cd tmp || exit 1
        rm -rf $arg
        git clone git@github.com:vaadin/$arg.git || exit 1
        cd $arg || exit 1
        gh pr checkout $extra || exit 1
        gh pr review --approve || exit 1
        gh pr merge --squash || exit 1
    esac
  shift
done