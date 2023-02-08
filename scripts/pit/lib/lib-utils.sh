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
  printf "\033[0m$1 \033[$2;$3m$4\033[0m\n" >&2
}

## log with some nice color
log() {
  print '>' 0 32 "$*"
}
bold() {
  print '>' 1 32 "$*"
}
err() {
  print '>' 0 31 "$*"
}
warn() {
  print '>' 0 33 "$*"
}
cmd() {
  cmd_=`echo "$*" | sed -e 's/ -D.*license=[a-z0-9-]*//'`
  print ' ' 1 34 " $cmd_"
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
  __path=`dirname $0 | sed -e 's,^\./,,'`
  ## Check whether the PATH is absolute
  [ `expr "$__path" : '^/'` != 1 ] && __path="$PWD/$__path"
  echo "$__path"
}

runToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  log "Running and sending output to > $__file"
  cmd "$__cmd"
  if [ -z "$__verbose" ]
  then
    $__cmd >> $__file 2>&1
    err=$?
  else
    $__cmd 2>&1 | tee -a $__file
    err=$?
  fi
  [ $err != 0 ] && err "!!! ERROR running $__cmd !!!" && tail -100 $__file && return 1 || return 0
}

## Run a process silently in background sending its output to a file
runInBackgroundToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  log "Running in background and sending output to > $__file"
  cmd "$__cmd"
  touch $__file
  if [ -n "$__verbose" ]
  then
    tail -f "$__file" &
    pid_tail=$!
  fi
  $__cmd >> $__file 2>&1 &
  pid_run=$!
}

## Wait until the specified message appears in the log file
waitUntilMessageInFile() {
  __file="$1"
  __message="$2"
  __timeout="$3"
  __cmd="$4"
  log "Waiting for server to start, timeout=$__timeout secs, message='$__message'"
  while [ $__timeout -gt 0 ]
  do
    kill -0 $pid_run 2>/dev/null
    if [ $? != 0 ]
    then
      log "ERROR: $__cmd failed to start (check full output in $__file)"
      [ -n "$VERBOSE" ] && tail -80 $__file
      return 1
    fi
    grep -q "$__message" $__file && log "Found '$__message' in $__file after "`expr $3 - $__timeout`" secs" && sleep 3 && return 0
    sleep 2 && __timeout=`expr $__timeout - 2`
  done
  log "ERROR: Could not find '$__message' in $__file after $3 secs (check output in $__file)"
  [ -n "$VERBOSE" ] && tail -80 $__file
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
  __message=$1
  playBell &
  pid_bell=$!
  [ -n "$__message" ] && log "$__message"
  ask "Push ENTER to stop the bell and continue"
  doKill $pid_bell
  unset pid_bell
}

## Inform the user that app is running in localhost, then wait until the user push enter
waitForUserManualTesting() {
  __port="$1"
  log "App is running in http://localhost:$__port, open it in your browser"
  ask "When you finish, push ENTER  to continue"
}

## Check the port is occupied
checkPort() {
  curl -s telnet://localhost:$1 >/dev/null &
  pid_curl=$!
  uname -a | egrep -iq 'Linux|Darwin' && sleep 2 || sleep 4
  kill $pid_curl 2>/dev/null || return 1
}

## Wait until port is listening
waitUntilPort() {
  log "Waiting for port $1 to be available"
  __i=1
  while true; do
    checkPort $1 && return 0
    __i=`expr $__i + 1`
    [ $__i -gt $2 ] && err "Server not listening in port $1 after $2 secs" && return 1
  done
}

## App context in Karaf takes a while after the server is listening
waitUntilAppReady() {
  waitUntilPort $2 $3 || return 1
  [ "$1" = vaadin-flow-karaf-example ] && warn "sleeping 30 secs for the context" && sleep 30 || true
}

## Check whether the port is already in use in this machine
checkBusyPort() {
  __port="$1"
  log "Checking whether port $__port is busy"
  checkPort $__port
  __err=$?
  [ $__err = 0 ] && err "Port ${__port} is occupied" && return 1 || return 0
}

## Check that a HTTP servlet request responds with 200
checkHttpServlet() {
  __url="$1"
  __file="$2"
  __cfile="curl-"`uname`".out"
  rm -f $__cfile
  log "Checking whether url $__url returns HTTP 200"
  runToFile "curl --fail -I -L $__url" "$__cfile" "$VERBOSE"
  [ $? != 0 ] && log "Got an invalid response from $__url" && return 1 || return 0
}

## Set the value of a property in the pom file, returning error if unchanged
setVersion() {
  __mavenProperty=$1
  __version=$2
  [ "$3" != false ] && git checkout -q .
  __current=`mvn help:evaluate -Dexpression=$__mavenProperty -q -DforceStdout`
  case $__version in
    current|$__current)
      echo $__current
      return 1;;
    *)
      __cmd="mvn -B -q versions:set-property -Dproperty=$__mavenProperty -DnewVersion=$__version"
      bold "==> Changing $__mavenProperty from $__current to $__version"
      cmd "$__cmd"
      $__cmd && return 0 || return 1;;
  esac
}

getVersionFromPlatform() {
  curl -s "https://raw.githubusercontent.com/vaadin/platform/$1/versions.json" 2>/dev/null \
      | egrep -v '^[1-4]' | tr -d "\n" |tr -d " "  | sed -e 's/^.*"'$2'":{"javaVersion"://'| cut -d '"' -f2
}

setVersionFromPlatform() {
  __version=$1
  [ $__version = current ] && return
  B=`echo $__version | cut -d . -f1,2`
  VERS=`getVersionFromPlatform $B $2`
  [ -z "$VERS" ] && VERS=`getVersionFromPlatform master $2`
  setVersion $3 "$VERS" false
}

setFlowVersion() {
  setVersionFromPlatform $1 flow flow.version
}

setMprVersion() {
  setVersionFromPlatform $1 mpr-v8 mpr.version
}

## Set the value of a property in the gradle.properties file, returning error if unchanged
setGradleVersion() {
  __gradleProperty=$1
  __version=$2
  git checkout -q .
  __current=`cat gradle.properties | grep "$_gradleProperty" | cut -d "=" -f2`
  echo ""
  case $__version in
    current|$__current)
      echo $__current;
      return 1;;
    *)
      __cmd="perl -pi -e 's,$_gradleProperty=.*,$_gradleProperty=$__version,' gradle.properties"
      log "Changing $_gradleProperty from $__current to $__version"
      cmd "$__cmd"
      $__cmd && return 0 || return 1;;
  esac
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  [ ! -d src/main/resources ] && return
  __prop="src/main/resources/application.properties"
  __key="vaadin.launch-browser"
  log "Disabling $__key in $__prop"
  touch $__prop
  perl -pi -e "s/$__key=.*//g" "$__prop"
}

## pnpm is quite faster than npm
enablePnpm() {
  [ ! -d src/main/resources ] && return
  __prop="src/main/resources/application.properties"
  __key="vaadin.pnpm.enable"
  log "Enabling $__key in $__prop"
  touch $__prop
  grep -q "$__key=true" "$__prop" || echo "$__key=true" >> "$__prop"
}

## vite is faster than webpack
enableVite() {
  [ ! -d src/main/resources ] && return
  __prop="src/main/resources/vaadin-featureflags.properties"
  __key="com.vaadin.experimental.viteForFrontendBuild"
  log "Enabling $__key in $__prop"
  touch $__prop
  grep -q "$__key=true" "$__prop" || echo "$__key=true" >> "$__prop"
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
  __end=`date +%s`
  __time=`expr $__end - $_start`
  __mins=`expr $__time / 60`
  __secs=`expr $__time % 60`
  echo ""
  log "Total time: $__mins' $__secs\""
}
