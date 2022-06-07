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
latest-typescript
latest-typescript-top
latest-java_partial-auth
latest-typescript_partial-auth"
DEMOS="
skeleton-starter-flow-cdi
base-starter-spring-gradle
base-starter-flow-quarkus
skeleton-starter-flow-spring
vaadin-flow-karaf-example
base-starter-flow-osgi"
DEFAULT_STARTERS=`echo "$PRESETS$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`

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
  tmp="$pwd/starters"
  mkdir -p "$tmp"

  ## Run presets (star.vaadin.com downloaded apps)
  for i in $presets
  do
    runStarter "$i" "$tmp" "$PORT" "$VERSION" "$OFFLINE" && success="$success $i" || failed="$failed $i"
    killAll
  done
  ## Run demos (proper starters in github)
  for i in $demos
  do
    runDemo "$i" "$tmp" "$PORT" "$VERSION" "$OFFLINE" && success="$success $i" || failed="$failed $i"
    killAll
  done

  cd $pwd

  ## Report success and failed projects
  for i in $success
  do
    log "Starter $i built successfully"
  done
  for i in $failed
  do
    files=`echo starters/$i/*.out`
    log "!!! ERROR in $i !!! check log files: $files"
  done

  printTime $_start
}

checkArgs ${@}
main
