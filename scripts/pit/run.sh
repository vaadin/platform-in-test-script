#!/bin/bash
. `dirname $0`/../repos.sh
. `dirname $0`/lib/lib-args.sh
. `dirname $0`/lib/lib-start.sh
. `dirname $0`/lib/lib-demos.sh

## Clean background processes on exit
trap "doExit" INT TERM EXIT

## Default configuration
DEFAULT_PORT=8080
DEFAULT_TIMEOUT=300

# hilla-basics-tutorial

DEFAULT_STARTERS=`echo "$PRESETS$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`

run() {
  [ -n "$TEST" ] && W=Testing || W=Executing
  log "================= $W $1 '$2' $OFFLINE =================="
  $1 "$2" "$3" "$PORT" "$VERSION" "$OFFLINE"
  _err=$?
  [ -n "$TEST" ] && echo "" && return 0
  if [ $_err = 0 ]; then
    log "==== '$2' was build and tested successfuly ===="
    success="$success $2"
  else
    failed="$failed $2"
    err "==== Error testing '$2' ===="
  fi
  killAll
  cleanAll
}

computeStarters() {
  ## Exclude starters beginning with the negated chart \!
  for i in `echo "$STARTERS" | tr ',' ' '`; do
    if expr "$i" : '!' >/dev/null; then
      STARTERS=`echo "$STARTERS" | sed -e 's|'"$i"'||g'`
      i="${i:1}"
      PRESETS=`echo "$PRESETS" | egrep -v "^$i$"`
      DEMOS=`echo "$DEMOS" | egrep -v "^$i$"`
    fi
  done
  ## If there are not any provided starter run all
  [ -z "$STARTERS" ] && STARTERS="$DEFAULT_STARTERS"
}

### MAIN
main() {
  # cd tmp
  # initializers
  # exit
  # echo ""

  _start=`date +%s`

  [ -z "$TEST" ] && log "===================== Running PiT Tests ============================================" \

  ## Exit soon if the port is busy
  [ -n "$TEST" ] || checkBusyPort "$PORT" || exit 1

  ## Install playwright in the background
  # checkPlaywrightInstallation `computeAbsolutePath`/its/foo &

  ## Calculate which starters should be run based on the command line
  computeStarters

  ## Check which arguments are valid names of presets or demos
  for i in `echo "$STARTERS" | tr ',' ' '`
  do
    if echo "$PRESETS" | grep -q "^$i$"; then
      presets="$presets $i"
    elif echo "$DEMOS" | grep -q "^$i$"; then
      demos="$demos $i"
    else
      err "Unknown starter: $i" && exit 1
    fi
  done

  ## Create temporary folder for downloading and running starters
  pwd="$PWD"
  tmp="$pwd/tmp"
  mkdir -p "$tmp"

  ## Remove local copy of cached artifacts
  cleanM2 "$VERSION"

  ## Run presets (star.vaadin.com) or archetypes
  for i in $presets; do
    run runStarter "$i" "$tmp"
  done
  ## Run demos (proper starters in github)
  for i in $demos; do
    run runDemo "$i" "$tmp"
  done

  cd $pwd

  [ -n "$TEST" ] && return

  _error=0
  ## Report success and failed projects
  for i in $success
  do
    bold "🟢 Starter $i built successfully"
  done
  for i in $failed
  do
    files=`echo $tmp/$i/*.out`
    err "🔴 ERROR in $i, check log files: $files"
    _error=1
  done

  printTime $_start

  return $_error
}

## Use $0 --path to see available SW installed in the container
if expr "$*" : '.*--path' >/dev/null; then
  for i in `ls -1d /opt/hostedtoolcache/*/*/x64 2>/dev/null`; do
    [ -d "$i/bin" ] && P="$i/bin:$P" || P="$i:$P"
  done
  echo "export PATH=$P\$PATH"
  exit 0
fi

## compute and check arguments
checkArgs ${@}

## run starters/demos
main
