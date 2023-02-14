#!/bin/bash
. `dirname $0`/lib/lib-args.sh
. `dirname $0`/lib/lib-start.sh
. `dirname $0`/lib/lib-demos.sh

## Clean background processes on exit
trap "doExit" INT TERM EXIT

## Default configuration
DEFAULT_PORT=8080
DEFAULT_TIMEOUT=300
PRESETS="
latest-java
latest-java-top
latest-javahtml
latest-lit
latest-lit-top
latest-java_partial-auth
latest-lit_partial-auth
flow-crm-tutorial_partial-latest
react-tutorial
default
archetype-java"
DEMOS="
skeleton-starter-flow-spring
bakery-app-starter-flow-spring
base-starter-spring-gradle
base-starter-flow-quarkus
spreadsheet-demo
mpr-demo
k8s-demo-app
skeleton-starter-flow-cdi"
# vaadin-flow-karaf-example
# base-starter-flow-osgi
DEFAULT_STARTERS=`echo "$PRESETS$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`

run() {
  echo ""
  log "================= Executing $1 '$2' $OFFLINE =================="
  $1 "$2" "$3" "$PORT" "$VERSION" "$OFFLINE"
  if [ $? = 0 ]; then
    log "==== '$2' was build and tested successfuly ===="
    success="$success $2"
  else
    failed="$failed $2"
    err "==== Error testing '$2' ===="
  fi
  killAll
}

### MAIN
main() {
  _start=`date +%s`
  printVersions

  ## Exit soon if the port is busy
  checkBusyPort "$PORT" || exit 1

  ## Check which arguments are valid names of presets or demos
  for i in `echo "$STARTERS" | tr ',' ' '`
  do
    if echo "$PRESETS" | grep -q "^$i$"; then
      presets="$presets $i"
    elif echo "$DEMOS" | grep -q "^$i$"; then
      demos="$demos $i"
    else
      log "Unknown starter: $i"
    fi
  done

  ## Create temporary folder for downloading and running starters
  pwd="$PWD"
  tmp="$pwd/tmp"
  mkdir -p "$tmp"

  ## Run presets (star.vaadin.com downloaded apps)
  for i in $presets; do
    run runStarter "$i" "$tmp"
  done
  ## Run demos (proper starters in github)
  for i in $demos; do
    run runDemo "$i" "$tmp"
  done

  cd $pwd

  _error=0
  ## Report success and failed projects
  for i in $success
  do
    log "Starter $i built successfully"
  done
  for i in $failed
  do
    files=`echo $tmp/$i/*.out`
    err "!!! ERROR in $i !!! check log files: $files"
    _error=1
  done

  printTime $_start
  return $_error
}

checkArgs ${@}
main
