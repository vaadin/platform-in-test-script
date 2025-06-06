. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh

## Run validations against one APP or DEMO by following next steps:
# 0. set variables
# 1. checks whether port is not busy
# 2. optimize certain vaadin parameters for speeeding up frontend compilation
# 3. run command for compilation
# 4. run command for starting servlet container hosting the app and wait until ready
# 5. check that server is up and running and port is listening
# 6. ask user for manually testing the app in their browser (if interactive)
# 7. if build is in prod mode, check for deprecated API usage and report it
# 8. check that no dev-bundle was created in dev mode to be sure bundle comes from the platform
# 9. if dev mode, wait until frontend is compiled
#    and check that no exception that needs re-run is not thrown (this is deprecated aftter 24.4)
# 10. check that the app is accessible via http and response is a valid servlet response
# 11. run UI test with selenium IDE (if not skipped)
# 12. kill remaining processes
# 13. check that the app is not using a default ID for statistics
# 14. remove .out file if the process was successful
runValidations() {
  [ -n "$1" ] && mode="$1" || mode=""
  [ -n "$2" ] && version="$2" || version=""
  [ -n "$3" ] && name="$3" || name=""
  [ -n "$4" ] && port="$4" || port=""
  [ -n "$5" ] && compile="$5" || compile=""
  [ -n "$6" ] && cmd="$6" || cmd=""
  [ -n "$7" ] && check="$7" || check=""
  [ -n "$8" ] && test="$PIT_SCR_FOLDER/its/$8" || test=""

  ## start takes a long to compile the frontend in dev-mode
  [ "$name" = "start" -a "$TIMEOUT" -le "300" ] && timeout=500 || timeout="$TIMEOUT"

  file="$name-$mode-$version-"`uname`".out"
  rm -f $file
  [ "$mode" = prod ] && expr "$compile" : "$MVN" >/dev/null && compile="$compile -Dmaven.compiler.showDeprecation"
  [ "$mode" = prod ] && expr "$cmd" : "$MVN" >/dev/null && cmd="$cmd -Dmaven.compiler.showDeprecation"


  echo "" >&2
  [ -z "$TEST" ] && bold "----> Running builds and tests on app $name, mode=$mode, port=$port, version=$version, mvn=$MVN"
  [ -n "$TEST" ] && cmd "### Run PiT for: app=$name mode=$mode version=$version"
  [ -n "$MAVEN_ARGS" ] && cmd "## MAVEN_ARGS='$MAVEN_ARGS'"
  [ -n "$MAVEN_OPTS" ] && cmd "## MAVEN_OPTS='$MAVEN_OPTS'"

  isUnsupported $name $mode $version && ([ -n "$TEST" ] || warn "Skipping $name $mode $version because of unsupported") && return 0

  # when offline add the offline parameter to mvn or gradle
  [ -n "$OFFLINE" ] && cmd="$cmd --offline" && compile="$compile --offline"
  # remove dev-bundle and node_modules when in dev mode
  [ "$mode" = dev ] && rm -rf node_modules src/main/dev-bundle
  # output the mvn dependency tree to the file if there is a pom.xml or build.gradle (useful for debugging)
  [ "$mode" = prod ] && H="-Pproduction,it" || H=""
  [ -z "$VERBOSE" -a -f pom.xml ] && runToFile "$MVN -ntp -B dependency:tree $H" "$file"
  [ -z "$VERBOSE" -a -f build.gradle ] && runToFile "$GRADLE dependencies" "$file"

  # check if the app has spring or hilla dependencies in certain projects that should not have them
  [ -z "$TEST" ] && case "$name" in
    skeleton-starter-flow|base-starter-flow-quarkus|skeleton-starter-flow-cdi|archetype-jetty)
      checkNoSpringDependencies "$name" || return 1 ;;
  esac

  # 1
  [ -n "$TEST" ] || checkBusyPort "$port" || return 1
  # 2
  [ -n "$TEST" ] || disableLaunchBrowser
  [ -z "$TEST" ] && [ -n "$PNPM" ] && enablePnpm
  [ -z "$TEST" ] && [ -n "$VITE" ] && enableVite

  # 3
  runToFile "$compile" "$file" "$VERBOSE"
  if [ "$?" != 0 ]; then
    H=`grep FAILURE grep FAILURE target/*-reports/*txt 2>/dev/null`
    [ -n "$H" ] && reportError "Failed Tests" "$H"
    return 1
  fi

  # 4
  runInBackgroundToFile "$cmd" "$file" "$VERBOSE"

  # 5
  waitUntilMessageInFile "$file" "$check" "$timeout" "$cmd" || return 1
  waitUntilAppReady "$name" "$port" 60 "$file" || return 1

  # 6
  [ -n "$INTERACTIVE" ] && waitForUserWithBell && waitForUserManualTesting "$port"

  # 7
  [ -z "$TEST" -a "$mode" = prod ] && H=`cat $file | grep WARNING | grep 'deprecated$' | sed -e 's/^.*\/src\//src\//g'` && reportError "Deprecated API" "$H"

  # 8
  [ -n "$TEST" ] || [ "$mode" != dev -o "$name" != default ] || checkBundleNotCreated "$file" || return 1

  # 9
  if [ "$mode" = dev ]; then
    waitUntilFrontendCompiled "http://localhost:$port/" "$file"
    _err=$?
    if [ "$_err" = 2 ]; then
      warn "File tsconfig/types.d was modified and server threw an exception !! retrying ..."
      killAll
      mv "$file" "$file.tsconfig"
      runInBackgroundToFile "$cmd" "$file" "$VERBOSE"
      waitUntilMessageInFile "$file" "$check" "$timeout" "$cmd" || return 1
      waitUntilAppReady "$name" "$port" 60 "$file" || return 1
      waitUntilFrontendCompiled "http://localhost:$port/" "$file" || return 1
    elif [ "$_err" != 0 ]; then
      return 1
    fi
  fi

  # 10
  checkHttpServlet "http://localhost:$port/" "$file" || return 1

  # 11
  if [ -z "$SKIPTESTS" -a -z "$SKIPPW" ]; then
    runPlaywrightTests "$test" "$file" "$mode" "$name" "$version" "--port=$port"  || return 1
  fi

  # 12
  [ -z "$TEST" ] && bold "----> The version $version of '$name' app was successfully built and tested in $mode mode."
  [ -n "$TEST" ] || (killAll && sleep 5)

  # 13
  if [ -n "$VERBOSE" -a -z "$TEST" ]; then
    H=`grep 12b7fc85f50e8c82cb6f4b03e12f2335 ~/.vaadin/usage-statistics.json`
    [ -n "$H" ] && reportError "Using a default ID for Statistics" "$H"
  fi

  # 14
  rm -f "$file"
  return 0
}


