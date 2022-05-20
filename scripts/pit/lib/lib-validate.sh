. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-side.sh

IT_FOLDER=`computeAbsolutePath`/its
set -o pipefail

## Run validations against one APP or DEMO
runValidations() {
  [ -n "$1" ] && version="$1"
  [ -n "$2" ] && name="$2"
  [ -n "$3" ] && port="$3"
  [ -n "$4" ] && compile="$4"
  [ -n "$5" ] && cmd="$5"
  [ -n "$6" ] && check="$6"
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
  $compile | tee $file || return 1

  runInBackgroundToFile "$cmd" "$file" "$VERBOSE"
  waitUntilMessageInFile "$file" "$check" "$TIMEOUT" "$cmd" || return 1

  sleep 4
  checkHttpServlet "http://localhost:$port/" || return 1

  if [ -z "$SKIPTESTS" ]
  then
    runSeleniumTests "$test" || return 1
  fi

  [ -n "$INTERACTIVE" ] && waitForUserWithBell && waitForUserManualTesting "$port"

  killAll
  return 0
}


