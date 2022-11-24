## Kills a process with its children and wait until complete
doKill() {
  while [ -n "$1" ]; do
    _procs=`type pgrep >/dev/null 2>&1 && pgrep -P $1`" $1"
    kill $_procs 2>/dev/null
    shift
  done
}

## killing background processes used in this utils
killAll() {
  doKill ${pid_run} ${pid_tail} ${pid_bell}
  unset pid_run pid_tail pid_bell
}

## Exit the script after some process cleanup
doExit() {
  killAll
  exit
}

print() {
  printf "\033[0m> \033[$1;$2m$3\033[0m\n" >&2
}

## log with some nice color
log() {
  print 0 32 "$*"
}
bold() {
  print 1 32 "$*"
}
err() {
  print 0 31 "$*"
}
warn() {
  print 0 33 "$*"
}
cmd() {
  cmd_=`echo "$*" | sed -e 's/ -D.*license=[a-z0-9-]*//'`
  print 1 34 " $cmd_"
}

## ask user a question, response is stored in key
ask() {
  # flush stdin
  while read -t1 ignore; do :; done
  printf "\033[0;32m$1\033[0m...">&2
  read key
}

## Compute the absolute PATH of the executed script
computeAbsolutePath() {
  _path=`dirname $0 | sed -e 's,^\./,,'`
  ## Check whether the PATH is absolute
  [ `expr "$_path" : '^/'` != 1 ] && _path="$PWD/$_path"
  echo "$_path"
}

runToFile() {
  _cmd="$1"
  _file="$2"
  _verbose="$3"
  log "Running and sending output to > $_file"
  cmd "$_cmd"
  if [ -z "$_verbose" ]
  then
    $_cmd >> $_file 2>&1
    err=$?
  else
    $_cmd 2>&1 | tee -a $_file
    err=$?
  fi
  [ $err != 0 ] && err "!!! ERROR running $_cmd !!!" && tail -100 $_file && return 1 || return 0
}

## Run a process silently in background sending its output to a file
runInBackgroundToFile() {
  _cmd="$1"
  _file="$2"
  _verbose="$3"
  log "Running in background and sending output to > $_file"
  cmd "$_cmd"
  touch $_file
  if [ -n "$_verbose" ]
  then
    tail -f "$_file" &
    pid_tail=$!
  fi
  $_cmd >> $_file 2>&1 &
  pid_run=$!
}

## Wait until the specified message appears in the log file
waitUntilMessageInFile() {
  _file="$1"
  _message="$2"
  _timeout="$3"
  _cmd="$4"
  log "Waiting for server to start, timeout=$_timeout secs, message='$_message'"
  while [ $_timeout -gt 0 ]
  do
    kill -0 $pid_run 2>/dev/null
    if [ $? != 0 ]
    then
      log "ERROR: $_cmd failed to start (check full output in $_file)"
      [ -n "$VERBOSE" ] && tail -80 $_file
      return 1
    fi
    grep -q "$_message" $_file && log "Found '$_message' in $_file after "`expr $3 - $_timeout`" secs" && sleep 3 && return 0
    sleep 2 && _timeout=`expr $_timeout - 2`
  done
  log "ERROR: Could not find '$_message' in $_file after $3 secs (check output in $_file)"
  [ -n "$VERBOSE" ] && tail -80 $_file
  return 1
}

## Infinite loop playing a bell in console
playBell() {
  while true
  do
    sleep 2 && printf "\a."
  done
}

## Alert user with a bell and wait until they push enter
waitForUserWithBell() {
  _message=$1
  playBell &
  pid_bell=$!
  [ -n "$_message" ] && log "$_message"
  ask "Push ENTER to stop the bell and continue"
  doKill $pid_bell
  unset pid_bell
}

## Inform the user that app is running in localhost, then wait until the user push enter
waitForUserManualTesting() {
  _port="$1"
  log "App is running in http://localhost:$_port, open it in your browser"
  ask "When you finish, push ENTER  to continue"
}

## Check whether the port is already in use in this machine
checkBusyPort() {
  _port="$1"
  log "Checking whether port $_port is busy"
  curl -s telnet://localhost:$_port >/dev/null &
  curl_pid=$!
  uname -a | egrep -iq 'Linux|Darwin' && sleep 1 || sleep 4
  kill $curl_pid 2>/dev/null && log "Port ${_port} is occupied" && return 1 || return 0
}

## Check that a HTTP servlet request responds with 200
checkHttpServlet() {
  _url="$1"
  _file="$2"
  _cfile="curl-"`uname`".out"
  log "Checking whether url $_url returns HTTP 200"
  runToFile "curl --fail -I -L $_url" "$_cfile" "$VERBOSE"
  grep -q 'HTTP/1.1 200' "$_cfile"
  [ $? != 0 ] && log "Got an invalid response from $_url" && return 1 || return 0
}

## Set the value of a property in the pom file, returning error if unchanged
setVersion() {
  _mavenProperty=$1
  _version=$2
  git checkout -q .
  _current=`mvn help:evaluate -Dexpression=$_mavenProperty -q -DforceStdout`
  echo ""
  case $_version in
    current|$_current)
      echo $_current;
      return 1;;
    *)
      _cmd="mvn -B -q versions:set-property -Dproperty=$_mavenProperty -DnewVersion=$_version"
      echo "" >&2
      bold "==> Changing $_mavenProperty from $_current to $_version"
      cmd "$_cmd"
      $_cmd && return 0 || return 1;;
  esac
}

getFlowVersionFromPlatform() {
  curl -s "https://raw.githubusercontent.com/vaadin/platform/$1/versions.json" 2>/dev/null \
      | tr -d "\n" |tr -d " "  | sed -e 's/^.*"flow":{"javaVersion"://'| cut -d '"' -f2
      set +x
}

## Set the value of a property in the gradle.properties file, returning error if unchanged
setGradleVersion() {
  _gradleProperty=$1
  _version=$2
  git checkout -q .
  _current=`cat gradle.properties | grep "$_gradleProperty" | cut -d "=" -f2`
  echo ""
  case $_version in
    current|$_current)
      echo $_current;
      return 1;;
    *)
      _cmd="perl -pi -e 's,$_gradleProperty=.*,$_gradleProperty=$_version,' gradle.properties"
      log "Changing $_gradleProperty from $_current to $_version"
      cmd "$_cmd"
      $_cmd && return 0 || return 1;;
  esac
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  [ ! -d src/main/resources ] && return
  _prop="src/main/resources/application.properties"
  _key="vaadin.launch-browser"
  log "Disabling $_key in $_prop"
  touch $_prop
  perl -pi -e "s/$_key=.*//g" "$_prop"
}

## pnpm is quite faster than npm
enablePnpm() {
  [ ! -d src/main/resources ] && return
  _prop="src/main/resources/application.properties"
  _key="vaadin.pnpm.enable"
  log "Enabling $_key in $_prop"
  touch $_prop
  grep -q "$_key=true" "$_prop" || echo "$_key=true" >> "$_prop"
}

## vite is faster than webpack
enableVite() {
  [ ! -d src/main/resources ] && return
  _prop="src/main/resources/vaadin-featureflags.properties"
  _key="com.vaadin.experimental.viteForFrontendBuild"
  log "Enabling $_key in $_prop"
  touch $_prop
  grep -q "$_key=true" "$_prop" || echo "$_key=true" >> "$_prop"
}

isHeadless() {
  IP=`hostname -i 2>/dev/null`
  test -z "$VERBOSE" -o -n "$IP"
}

printVersions() {
  log "===================== Running PiT Tests ============================================
`mvn -version | tr '\\\' '/'`
Node version: `node --version`
Npm version: `npm --version`"
}

printTime() {
  [ -n "$1" ] && _start=$1 || return
  _end=`date +%s`
  _time=`expr $_end - $_start`
  _mins=`expr $_time / 60`
  _secs=`expr $_time % 60`
  echo ""
  log "Total time: $_mins' $_secs\""
}
