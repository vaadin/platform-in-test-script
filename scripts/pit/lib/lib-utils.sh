## Kills a process and all its children and wait until complete
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

## log with some color
log() {
  printf "\033[0m> \033[0;32m$1\033[0m\n" >&2
}

## ask user a question, response is stored in key
ask() {
  read -t1 ignore
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

## Run a process silently in background sending its output to a file
runInBackgroundToFile() { 
  _cmd="$1"
  _file="$2"
  _verbose="$3"
  log "Running $_cmd (logs are saved to $_file)" &
  > $_file
  if [ -n "$_verbose" ]
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
  _timeout="$3"
  log "Waiting for server to start, timeout=$_timeout secs., message='$_message'"
  while [ $_timeout -gt 0 ]
  do
    grep -q "$_message" $_file && return 0
    sleep 2 && _timeout=`expr $_timeout - 2`
  done
  [ -z "$VERBOSE" ] && tail -50 $_file
  log "Could not find '$_message' in $_file after $3 secs. (check output in $_file)"
  return 1
}

## Infinite loop playing a bell in console
playBell() {
  while true
  do
    printf "\a." && sleep 1
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
  uname -a | egrep -iq 'Linux|Darwin' && sleep 1 || sleep 4
  kill $curl_pid 2>/dev/null && log "Port ${_port} is occupied" && return 1 || return 0
}

## Check that a HTTP servlet request responds with 200
checkHttpServlet() {
  _url="$1"
  log "Checking whether url $_url returns HTTP 200"
  curl --fail -s -I -L "$_url" | grep -q 'HTTP/1.1 200'
}

## Set the value of a property in the pom file, returning error if unchanged
setVersion() {
  _mavenProperty=$1
  _version=$2
  git checkout -q .
  _current=`mvn help:evaluate -Dexpression=$_mavenProperty -q -DforceStdout`
  log "Version $_current, $_version"
  case $_version in
    current|$_current)
      return 1;;
    *)
      log "Changing $_mavenProperty from $_current to $_version"
      mvn -B -q versions:set-property -Dproperty=vaadin.version -DnewVersion=$_version
      return 0;;
  esac
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  _prop="src/main/resources/application.properties"
  log "Disabling launch-browser"
  touch $_prop
  perl -pi -e 's/vaadin.launch-browser=.*//g' "$_prop"
}

enablePnpm() {
  _prop="src/main/resources/application.properties"
  _key="vaadin.pnpm.enable"
  log "Enabling Pnpm"
  touch $_prop
  grep -q "$_key=true" "$_prop" || echo "$_key=true" >> "$_prop"
}

enableVite() {
  _prop="src/main/resources/vaadin-featureflags.properties"
  _key="com.vaadin.experimental.viteForFrontendBuild"
  log "Enabling Vite"
  touch $_prop
  grep -q "$_key=true" "$_prop" || echo "$_key=true" >> "$_prop"
}


