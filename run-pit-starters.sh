#!/bin/sh

DEFAULT_PORT=8080
## List of the preset in start.vaadin.com
#  pre-java
#  pre-java-top
#  pre-javahtml
#  latest-java
#  latest-java-top
#  latest-javahtml
DEFAULT_PRESETS="latest-java,latest-java-top,latest-javahtml"

## Exit the script after killing background processes
doExit() {
  doKill ${pid_run} ${pid_tail} ${pid_bell}
  exit
}

## Kills a process and all its children and wait until complete
doKill() {
  while [ -n "$1" ]; do
    _procs=`pgrep -P $1`" $1"
    kill $_procs 2>/dev/null
    shift
  done
}

## log with some color
log() {
  printf "\033[0m> \033[0;32m$1\033[0m\n" >&2
}

## ask user a question, response is stored in key
ask() {
  printf "\033[0;32m$1\033[0m...">&2
  read key
}

## Generate and starter with the given preset, and unzip it in the current folder
downloadStarter() {
  _preset=$1
  _url="https://start.vaadin.com/dl?preset=${_preset}&projectName=${_preset}"
  _zip="$_preset.zip"
  log "Downloading $_url"
  curl -s -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  _prop="src/main/resources/application.properties"
  [ -f "$_prop" ] &&
    log "Disabling launch-browser" &&
    perl -pi -e 's/vaadin.launch-browser=.*//g' "$_prop"
}

## Run a process silently in background sending its output to a file
runInBackgroundToFile() {
  _cmd="$1"
  _file="$2"
  log "Running $_cmd (logs are saved to $_file)" &
  > $_file
  if [ -n "$VERBOSE" ]
  then
    tail -f "$_file" &
    pid_tail=$!
  fi
  $_cmd > $_file 2>&1 &
  pid_run=$!
}

## Wait until the specified message appears in the log file
waitUntilMessageInFile() {
  _file="$1"
  _message="$2"
  [ -n "$3" ] && _timeout="$3" || _timeout=120
  log "Waiting for server to start, timeout=$_timeout secs., message='$_message'"
  while [ $_timeout -gt 0 ]
  do
    grep -q "$_message" $_file && return 0
    sleep 2 && _timeout=`expr $_timeout - 2`
  done
  [ -z "$VERBOSE" ] && tail -50 $_file
  log "Could not find '$_message' in $_file after $_timeout secs. (check output in $_file)"
  return 1
}

## Infinite loop playing a bell in console
playBell() {
  while true
  do
    printf "\a" && sleep 1
  done
}

## Alert user with a bell and wait until they push enter
waitForUserWithBell() {
  _message=$1
  playBell &
  pid_bell=$!
  [ -n "$_message" ] && log "$_message"
  ask "\n\nPush ENTER to stop the bell and continue"
  doKill $pid_bell
  unset pid_bell
}

## Inform the user that app is running in localhost, then wait until the user push enter
waitForUserManualTesting() {
  _port="$1"
  log "App is running in http://localhost:$_port, open it in your browser"
  ask "\nWhen you finish, push ENTER  to continue"
}

## Check whether the port is already in use in this machine
checkBusyPort() {
  _port="$1"
  log "Checking whether port $_port is busy"
  curl -s telnet://localhost:$_port >/dev/null &
  curl_pid=$!
  sleep 1
  kill $curl_pid 2>/dev/null && log "Port ${_port} is occupied" && return 1 || return 0
  exit
}

checkHttpServlet() {
  _url="$1"
  log "Checking whether url $_url is reachable"
  curl --fail -s -I "$_url" | grep -q 'HTTP/1.1 200'
}

setVersion() {
  _version=$1
  git checkout -q .
  _current=`mvn help:evaluate -Dexpression=vaadin.version -q -DforceStdout`
  log "Version $_current, $_version"
  case $_version in
    current|$_current)
      return 1;;
    *)
      log "Changing vaadin.version from $_current to $_version"
      mvn -B -q versions:set-property -Dproperty=vaadin.version -DnewVersion=$_version
      return 0;;
  esac
}

## Run validations on an start.vaadin.com application
## Arguments: <current|next> <name of the app> <servlet port> <app running message in the logs>
testStarter() {
  [ -n "$1" ] && version="$1" || return 1
  [ -n "$2" ] && name="$2" || return 1
  [ -n "$3" ] && port="$3" || port="$PORT"
  [ -n "$4" ] && check="$4" || check=" Frontend compiled "
  log "Running test on starter $name, port $port, $version"

  file="starter-$name.out"
  checkBusyPort "$port" || return 1

  disableLaunchBrowser

  cmd="mvn -B"
  [ -n "$OFFLINE" ] && cmd="$cmd -o"
  runInBackgroundToFile "$cmd" "$file"
  waitUntilMessageInFile "$file" " Frontend compiled " || exit 1

  if [ $? != 0 ]
  then
    log "App $name failed to Start ($cmd)"
  else
    sleep 4
    checkHttpServlet "http://localhost:$port/"
    if [ current != "$version" ]
    then
      waitForUserWithBell
      waitForUserManualTesting "$port"
    fi
  fi

  doKill $pid_run $pid_tail $pid_bell
  unset pid_run pid_tail pid_bell
}


usage() {
  cat <<EOF
Use: $0 [version=] [presets=] [port=] [verbose] [offline]"

  version    Version to test, by default current, otherwise current first and then provided version
  presets    List of start presets separated by comman (default: $DEFAULT_PRESETS)
  port       HTTP Port for thee servlet container (default: $DEFAULT_PORT)
  verbose    Show server output (default silent)
  offline    Do not remove previous folders, and do not use network for mvn (default online)

EOF
  exit 1
}

checkArgs() {
  VERSION=current; PORT=$DEFAULT_PORT; PRESETS=$DEFAULT_PRESETS
  while [ -n "$1" ]
  do
    arg=`echo "$1" | cut -d= -f2`
    case "$1" in
      port=*) PORT="$arg";;
      presets=*|starters=*) PRESETS="$arg";;
      version=*) VERSION="$arg";;
      verbose|debug) VERBOSE=true;;
      offline) OFFLINE=OFFLINE;;
      help|--help|-h) usage;;
      *) echo "Unknown option: $1" && usage && exit 1;;
    esac
    shift
  done
}

### MAIN
main() {
  trap "doExit" INT TERM EXIT
  pwd="$PWD"
  tmp="$pwd/starters"
  mkdir -p "$tmp"

  checkBusyPort "$PORT" || exit 1

  for i in `echo $PRESETS | tr ',' ' '`
  do
    log "<<<< TESTING '$i' $OFFLINE >>>>"
    cd "$tmp"
    dir="$tmp/$i"
    if [ -z "$OFFLINE" ]
    then
      [ -d "$dir" ] && log "Removing project folder $dir" && rm -rf $dir
      downloadStarter $i || exit 1
    fi
    cd "$dir" || exit 1
    testStarter current $i $PORT
    setVersion $VERSION && testStarter $VERSION $i $PORT
    log "==== Starter '$name' was Tested successfuly ===="
  done
}

checkArgs ${@}
main
