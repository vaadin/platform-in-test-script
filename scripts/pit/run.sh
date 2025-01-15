## MAIN script to be run for PiT tests
## for a list of arguments run the script with --help option

#!/bin/bash
. `dirname $0`/../repos.sh
. `dirname $0`/lib/lib-args.sh
. `dirname $0`/lib/lib-start.sh
. `dirname $0`/lib/lib-demos.sh
. `dirname $0`/lib/lib-cc.sh

## Default configuration
DEFAULT_PORT=8080
DEFAULT_TIMEOUT=300

## starters and demos list is maintained in the repos.sh file
DEFAULT_STARTERS=`echo "$PRESETS$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`

## run an specific starter or demo
## $1: function to run (runStarter, runDemo)
## $2: starter or demo name
## $3: folder where the demo will be downloaded
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

## compute what starters to run based on the command line arguments
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

  _start=`date +%s`

  [ -z "$TEST" ] && log "===================== Running PiT Tests ============================================" \

  ## Exit soon if the port is busy
  [ -n "$TEST" ] || checkBusyPort "$PORT" || exit 1

  ## Install playwright in the background (not used since there were some issues)
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

  ## Remove local copy of cached artifacts if not --no-clean option is provided
  [ -z "NO_CLEAN" ] && cleanM2 "$VERSION"

  ## Run presets (star.vaadin.com) or archetypes
  for i in $presets; do
    if expr "$i" : '.*-hotswap' >/dev/null; then
      installJBRRuntime || continue
    elif [ -n "$JDK" ]; then
      installJDKRuntime "$JDK" || continue
    fi
    run runStarter "$i" "$tmp"
  done


  ## Run demos (proper starters in github)
  for i in $demos; do
    if [ $i = control-center ]; then
      run runControlCenter start
      continue
    elif expr "$i" : '.*_jdk' >/dev/null; then
      _jdk=`echo "$i" | sed -e 's|.*_jdk||'`
      i=`echo "$i" | sed -e 's|_jdk.*||'`
      installJDKRuntime "$_jdk" || continue
    elif [ -n "$JDK" ]; then
      installJDKRuntime "$JDK" || continue
    fi
    run runDemo "$i" "$tmp"
  done
  

  cd "$pwd"

  [ -n "$TEST" ] && return

  ## Report success and failed projects
  for i in $success
  do
    bold "🟢 Starter $i built successfully"
  done
  _error=0
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
checkCommands jq curl || exit 1
checkArgs ${@}

## run a function of the libs in current folder and exit (just for testing a function in the lib)
if [ -n "$RUN_FUCTION" ]; then
  log "Running function: $RUN_FUCTION"
  eval $RUN_FUCTION
  error=$?
  [ "$error" = 0 ] && log "OK" || err "Error"
  exit 0
fi

## Clean background processes on exit
trap "doExit" INT TERM EXIT

## run starters/demos

main
