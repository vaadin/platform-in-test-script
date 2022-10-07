. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh

IT_FOLDER=`computeAbsolutePath`/its
set -o pipefail

## Run validations against one APP or DEMO by following next steps:
# 1. checks whether port is not busy
# 2. optimize certain vaadin parameters for speeeding up frontend compilation
# 3. run command for compilation
# 4. run command for starting servlet container hosting the app and wait until ready
# 5. ask user for manually testing the app in their browser (if interactive)
# 6. check that server is up and running and serving a valid index page
# 7. run UI test with selenium IDE (if not skipped)
# 8. kill remaining processes
runValidations() {
  [ -n "$1" ] && mode="$1" || mode=""
  [ -n "$2" ] && version="$2" || version=""
  [ -n "$3" ] && name="$3" || name=""
  [ -n "$4" ] && port="$4" || port=""
  [ -n "$5" ] && compile="$5" || compile=""
  [ -n "$6" ] && cmd="$6" || cmd=""
  [ -n "$7" ] && check="$7" || check=""
  [ -n "$8" ] && test="$IT_FOLDER/$8" || test=""
  file="$name-$mode-$version.out"

  echo ""
  bold "----> Running builds and tests on app $name, mode=$mode, port=$port, version=$version"

  # 1
  checkBusyPort "$port" || return 1
  # 2
  disableLaunchBrowser
  [ -n "$PNPM" ] && enablePnpm
  [ -n "$VITE" ] && enableVite

  # when offline add the offline parameter to mvn or gradle
  [ -n "$OFFLINE" ] && cmd="$cmd --offline" && compile="$compile --offline"
  # when not verbose add the quiet parameter to maven or gradle
  [ -z "$VERBOSE" ] && compile="$compile --quiet"

  echo "Running: $compile > $file"

  # 3
  $compile 2>&1 | tee -a $file || return 1
  # 4
  runInBackgroundToFile "$cmd" "$file" "$VERBOSE"
  waitUntilMessageInFile "$file" "$check" "$TIMEOUT" "$cmd" && sleep 4 || return 1
  # 5
  [ -n "$INTERACTIVE" ] && waitForUserWithBell && waitForUserManualTesting "$port"
  # 6
  sleep 5
  checkHttpServlet "http://localhost:$port/" "$file" || return 1
  # 7
  if [ -z "$SKIPTESTS" ]; then
    runPlaywrightTests "$test" "$port" || return 1
  fi
  # 8
  killAll || return 0
}


