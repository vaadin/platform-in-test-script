. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-side.sh

IT_FOLDER=`computeAbsolutePath`/its

## Generate an starter with the given preset, and unzip it in the current folder
downloadStarter() {
  _preset=$1
  _presets=""
  for _p in `echo "$_preset" | tr "_" " "`
  do
    _presets="$_presets&preset=$_p"
  done
  _url="https://start.vaadin.com/dl?${_presets}&projectName=${_preset}"
  _zip="$_preset.zip"

  log "Downloading $_url"
  curl -s -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip || return 1

  _new=`echo "$_preset" | tr "_" "-"`
  [ "$_new" != "$_preset" ] && mv "$_new" "$_preset" || return 0
}

## Run validations on an start.vaadin.com application
## Arguments: <current|next> <name of the app> <servlet port> <app running message in the logs>
testStarter() {
  [ -n "$1" ] && version="$1" || return 1
  [ -n "$2" ] && name="$2" || return 1
  [ -n "$3" ] && port="$3" || port="$PORT"
  [ -n "$4" ] && compile="$4" || compile="mvn clean"
  [ -n "$5" ] && cmd="$5" || cmd="mvn -B"
  [ -n "$6" ] && check="$6" || check=" Frontend compiled "
  [ -n "$7" ] && test="$7"
  log "Running test on starter $name, port $port, $version"

  file="starter-$name.out"
  checkBusyPort "$port" || return 1

  disableLaunchBrowser
  enablePnpm
  enableVite

  [ -n "$OFFLINE" ] && cmd="$cmd -o" && compile="$compile -o"
  log "Running $compile"
  [ -z "$VERBOSE" ] && compile="$compile -q"
  $compile -B

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

    if [ -n "$INTERACTIVE" -a current != "$version" ]
    then
      waitForUserWithBell
      waitForUserManualTesting "$port"
    fi
  fi

  killAll
  return 0
}

## get the selenium IDE test file used for each starter
getTestFile() {
  case $1 in
   latest-java|latest-java-top|latest-javahtml|latest-typescript|latest-typescript-top)
     echo "latest-java.side";;
   latest-java_partial-auth|latest-java-top_partial-auth)
     echo "latest-java-auth.side";;
   latest-typescript_partial-auth)
     echo "latest-typescript-auth.side";;
   *)
     echo "$1.side";;
  esac
}

### MAIN
runStarters() {
  _presets=`echo "$1" | tr ',' ' '`
  _port="$2"
  _version="$3"
  _offline="$4"

  pwd="$PWD"
  tmp="$pwd/starters"
  mkdir -p "$tmp"

  checkBusyPort "$_port" || exit 1

  for i in $_presets
  do
    _versionProp=vaadin.version
    if echo "$i" | grep -q typescript
    then
      _version=`echo $_version | sed -e 's,^23,1,'`
      _versionProp=hilla.version
    fi

    log "================= TESTING '$i' $_offline =================="
    cd "$tmp"
    dir="$tmp/$i"
    if [ -z "$_offline" ]
    then
      [ -d "$dir" ] && log "Removing project folder $dir" && rm -rf $dir
      downloadStarter $i || exit 1
    fi
    cd "$dir" || exit 1

    _test="$IT_FOLDER/"`getTestFile $i`

    testStarter current $i $_port "" "" "" "$_test" || exit 1

    if setVersion $_versionProp $_version
    then
      log "Testing version $_version in the '$i' app"
      testStarter $_version $i $_port "" "" "" "$_test" || exit 1
      testStarter $_version $i $_port 'mvn -Pproduction package' 'java -jar target/*.jar' "Generated demo data" "$_test" || exit 1
    fi
    log "==== Starter '$i' was Tested successfuly ====
    
    "
  done
}
