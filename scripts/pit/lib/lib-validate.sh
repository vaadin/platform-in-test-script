. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-side.sh

IT_FOLDER=`computeAbsolutePath`/its


## Run validations against one APP or DEMO
runValidations() {
  [ -n "$1" ] && version="$1" || return 1
  [ -n "$2" ] && name="$2" || return 1
  [ -n "$3" ] && port="$3" || port="$PORT"
  [ -n "$4" ] && compile="$4" || compile="mvn clean"
  [ -n "$5" ] && cmd="$5" || cmd="mvn -B"
  [ -n "$6" ] && check="$6" || check=" Frontend compiled "
  [ -n "$7" ] && test="$IT_FOLDER/$7"

  echo ""
  log "Running builds and tests on demo $name, port $port, version $version"

  file="starter-$name.out"
  checkBusyPort "$port" || return 1

  disableLaunchBrowser
  enablePnpm
  enableVite

  [ -n "$OFFLINE" ] && cmd="$cmd -o" && compile="$compile -o"
  log "Running $compile"
  [ -z "$VERBOSE" ] && compile="$compile -q"
  $compile || return 1

  runInBackgroundToFile "$cmd" "$file" "$VERBOSE"
  waitUntilMessageInFile "$file" "$check" "$TIMEOUT"

  if [ $? != 0 ]
  then
    log "App $name failed to Start ($cmd)" && return 1
  else
    sleep 4
    checkHttpServlet "http://localhost:$port/"
    if [ $? != 0 ]
    then
      log "App $name failed to Check at port $port" && return 1
    fi

    [ -n "$SKIPTESTS" ] || runSeleniumTests "$test" || return 1

    [ -n "$INTERACTIVE" ] && waitForUserWithBell && waitForUserManualTesting "$port"
  fi

  killAll
  return 0
}


