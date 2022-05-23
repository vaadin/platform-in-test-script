. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-side.sh

IT_FOLDER=`computeAbsolutePath`/its
set -o pipefail

## Run validations against one APP or DEMO by following next steps:
# 1. checks whether port is not busy
# 2. optimize certain vaadin parameters for speeeding up frontend compilation
# 3. run command for compilation
# 4. run command for starting servlet container hosting the app and wait until ready
# 5. check that server is up and running and serving a valid index page
# 6. run UI test with selenium IDE (if not skipped)
# 7. ask user for manually testing the app in their browser (if interactive)
# 8. kill remaining processes
runValidations() {
  [ -n "$1" ] && version="$1"
  [ -n "$2" ] && name="$2"
  [ -n "$3" ] && port="$3"
  [ -n "$4" ] && compile="$4"
  [ -n "$5" ] && cmd="$5"
  [ -n "$6" ] && check="$6"
  [ -n "$7" ] && test="$IT_FOLDER/$7"
  file="$name.out"

  echo ""
  log "Running builds and tests on demo $name, port $port, version $version"

  # 1
  checkBusyPort "$port" || return 1
  # 2
  disableLaunchBrowser
  enablePnpm
  enableVite

  # when offline add the offline parameter to mvn or gradle
  [ -n "$OFFLINE" ] && cmd="$cmd --offline" && compile="$compile --offline"
  log "Running $compile > $file"
  # when not verbose add the quiet parameter to maven or gradle 
  [ -z "$VERBOSE" ] && compile="$compile --quiet"

  # 3
  $compile | tee $file || return 1
  # 4
  runInBackgroundToFile "$cmd" "$file" "$VERBOSE"
  waitUntilMessageInFile "$file" "$check" "$TIMEOUT" "$cmd" && sleep 4 || return 1
  # 5
  checkHttpServlet "http://localhost:$port/" || return 1
  # 6
  if [ -z "$SKIPTESTS" ]
  then
    runSeleniumTests "$test" || return 1
  fi
  # 7
  [ -n "$INTERACTIVE" ] && waitForUserWithBell && waitForUserManualTesting "$port"
  # 8
  killAll || return 0
}


