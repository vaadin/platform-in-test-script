isLinux() {
  test `uname` = Linux
}
isMac() {
  test `uname` = Darwin
}
isWindows() {
  ! isLinux && ! isMac
}

## Check if a set of commands passed as arguments are installed
checkCommands() {
  type command >/dev/null 2>&1 || exit 1
  for command_name in $*; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        err "Command: '$command_name' is not installed" && return 1
    fi
  done
  return 0
}

## Remove pro-key for testing core-only apps
removeProKey() {
  if [ -f ~/.vaadin/proKey ]; then
    _cmd="mv ~/.vaadin/proKey ~/.vaadin/proKey-$$"
    runCmd "Removing proKey license" "mv ~/.vaadin/proKey ~/.vaadin/proKey-$$"
  fi
}
## Restore pro-key removed in previous function
restoreProKey() {
  [ ! -f ~/.vaadin/proKey-$$ ] && return
  H=`cat ~/.vaadin/proKey 2>/dev/null`
  _cmd="mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey"
  runCmd "Restoring proKey license" "mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey"
  [ -z "$TEST" -a -n "$H" ] && reportError "A proKey was generated while running validation" "$H" && return 1
}

## get pids for process
getPids() {
  H=`grep -a "" /proc/*/cmdline 2>/dev/null | xargs -0 | grep -v grep | perl -pe 's|/proc/(.*?)/cmdline:|$1 |g'`
  if [ -n "$H" ]
  then
    _P=`echo "$H" | grep "$1" | awk '{print $1}'`
  else
    _P=`ps -feaw | grep "$1" | grep -v grep | awk '{print $2}'`
  fi
  [ -n "$_P" ] && echo "$_P" | tr "\n" " " && return 0 || return 1
}

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
## restore system as before running the script
cleanAll() {
  restoreProKey
  unsetJavaPath
}

onExit() {
  [ -n "$exitCmds" ] && exitCmds="$exitCmds;$1" || exitCmds="$1"
}

## Exit the script after some process cleanup
doExit() {
  echo -e "►\c"
  $exitCmds
  killAll
  cleanAll
  exit
}

## print wrapper for coloring outputs
print() {
  printf "\033[0m$1\033[$2;$3m$4\033[0m" >&2
}

printnl() {
  print "$1" "$2" "$3" "$4\n"
}

## log with some nice color
isnl() {
  expr "$1" : "\-" > /dev/null && _opt=${1#-} && shift || _opt=""
  [ "$_opt" = n ] && echo "" >&2 || return 1
  true
}
log() {
  isnl $1 && shift
  [ -n "$TEST" ] && cmd "## $*" && return 0
  print '> ' 0 32 "$*"
  printnl '' 2 36 " - "`computeTime`""
}
bold() {
  isnl $1 && shift
  [ -n "$TEST" ] && cmd "## $*" && return 0
  print '> ' 1 32 "$*"
  printnl '' 2 36 " - "`computeTime`""
}
err() {
  printnl '> ' 0 31 "$*"
}
warn() {
  isnl $1 && shift
  printnl '> ' 0 33 "$*"
}
cmd() {
  isnl $1 && shift
  cmd_=`printf "$*" | tr -s " " | perl -pe 's|\n|\\\\\\\n|g'`
  printnl '  ' 1 34 " $cmd_"
}
dim() {
  printnl '' 0 36 "$*"
}

## Reports an error to the GHA step-summary section
## $1: report header
## $*: body
reportError() {
  __head=$1; shift
  [ -z "$__head" -o -z "$*" ] && return
  warn "reporting error: $__head"
  [ -z "$GITHUB_STEP_SUMMARY" ] && return
  H=`echo "$*" | awk '{print substr ($0, 0, 300)}' | tail -n 100000`
  cat << EOF >> "$GITHUB_STEP_SUMMARY"
<details>
<summary><h4>$__head</h4></summary>
<pre>
`echo "$H"`
</pre>
</details>
EOF
}

## Reports a file content to the GHA step-summary section
## $1: file
## $2: report header
reportOutErrors() {
  [ -f "$1" ] || return
  H=`cat "$1" | egrep -v ' *at |org.atmosphere.cpr.AtmosphereFramework' | tail -300`
  reportError "$2" "$H"
}

## ask user a question, response is stored in key variable
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
## Compute the maven command to use for the project and stores in MVN env variable
computeMvn() {
  MVN=mvn
  [ -x ./mvnw ] && MVN=./mvnw
  isWindows && [ -x ./mvnw.bat ] && MVN=./mvnw.bat
  isWindows && [ -x ./mvnw.cmd ] && MVN=./mvnw.cmd
}

## Compute the gradle command to use for the project and stores in GRADLE env variable
computeGradle() {
  [ -x ./gradlew ] && GRADLE=./gradlew
  isWindows && [ -x ./gradlew.bat ] && GRADLE=./gradlew.bat
  isWindows && [ -x ./gradlew.cmd ] && GRADLE=./gradlew.cmd
  GRADLE="$GRADLE -Porg.gradle.java.installations.auto-detect=false"
}

## Compute npm command used for installing playwright
computeNpm() {
  _VNODE=~/.vaadin/node
  _NPMJS=$_VNODE/lib/node_modules/npm/bin/npm-cli.js
  NPM="'"`which npm`"'"
  NPX=`which npx`
  NODE=`which node`
  [ -x "$_VNODE/bin/node" -a -f "$_NPMJS" ] && export PATH="$_VNODE/bin:$PATH" && NODE="$_VNODE/bin/node" && NPM="'$NODE' '$_NPMJS'"
}

## Run a command, and shows a message explaining it
## $1: it's optional and it could be -q (quiet sending output to dev/null) -f (force execution even when $TEST is set)
## $2: message to show
## $*: command line order and arguments
runCmd() {
  __=$-
  set +x
  expr $__ : .*x >/dev/null && __set="set -x" || __set=true
  expr "$1" : "\-" > /dev/null && _opt=${1#-} && shift || _opt=""
  expr "$_opt" : ".*q" >/dev/null && _silent=true || _silent=""
  expr "$_opt" : ".*f" >/dev/null && _force=true || _force=""
  [ -z "$1" ] && echo "bad arguments call: runCmd <true|false|-q> <message> command args" && eval "$__set" && return 1
  [ -z "$TEST" ] && log "$1" || cmd "## $1"
  shift
  _cmd="${*}"
  cmd "$_cmd"
  [ -z "$_force" -a -n "$TEST" ] && eval "$__set" && return 0
  if expr "$_cmd" : ".*&$" >/dev/null
  then
    _cmd=`echo "$_cmd" | sed -e 's/&$//'`
    eval "$_cmd" &
    _pid=$!
    _err=$?
    sleep 2
    kill -0 $_pid 2>/dev/null || return 1
  else
    if [ -n "$VERBOSE" ]; then
      eval "$_cmd" | tee -a runCmd.out
      _err=$?
    else
      eval "trap 'trap - INT; kill -INT '$$'' INT; $_cmd" > runCmd.out 2>&1
      _err=$?
    fi
    [ $_err != 0 -a -z "$VERBOSE" -a -n "$_silent" ] && cat runCmd.out >&2
    rm -f runCmd.out
  fi
  eval "$__set"
  return $_err
}

##
runCmdQuiet() {
  :
}

## Run a command and outputs its stdout/stderr to a file
## $1 command to run
## $2 file to send the output
## $3 verbose mode (it means that the output is also printed in the console)
## $4 send only stdout to file (if not set, stdout and stderr are sent to the file)
runToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  __stdout="$4"
  [ -z "$TEST" ] && log "Running and sending output to > $__file"
  expr "$1" : ".*mvn " >/dev/null && E=" $MAVEN_ARGS" || E=""
  cmd "$__cmd $E"
  [ -n "$TEST" ] && return
  if [ -z "$__verbose" ]
  then
    if [ -z "$__stdout" ]; then
      eval "$__cmd" >> "$__file" 2>&1
      err=$?
    else
      eval "$__cmd" >> "$__file"
      err=$?
    fi
  else
    eval "$__cmd" 2>&1 | tee -a "$__file"
    err=$?
  fi
  [ $err != 0 ] && reportOutErrors "$__file" "Error ($err) running $__cmd" && return 1 || return 0
}

## Run a process silently in background sending its output to a file
## $1 command to run
## $2 file to send the output
## $3 verbose mode (it means that the output is also printed in the console)
runInBackgroundToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  [ -z "$TEST" ] && log "Running in background and sending output to > $__file"
  expr "$1" : ".*mvn " >/dev/null && E=" $MAVEN_ARGS" || E=""
  cmd "$__cmd $E"
  [ -n "$TEST" ] && return
  touch "$__file"
  if [ -n "$__verbose" ]
  then
    tail -f "$__file" &
    pid_tail=$!
  fi
  $__cmd >> "$__file" 2>&1 &
  pid_run=$!
  sleep 2
  kill -0 $pid_run 2>/dev/null || return 1
}

## check whether flow modified the tsconfig.json file
tsConfigModified() {
  grep -q "'tsconfig.json' has been updated" "$1" || return 1
  H=`git diff tsconfig.json 2>/dev/null`
  H="$H"`git diff types.d.ts 2>/dev/null`
  echo ">>>> PiT: Found tsconfig.json modified" >> "$1"
  reportOutErrors "File 'tsconfig.json' was modified and servlet threw an Exception" "$H"
}

## Wait until the specified message appears in the log file
## $1 file continously check for the presence of a message
## $2 message to wait for (it could be a regular expression, valid for egrep)
## $3 timeout in seconds
## $4 command that is sending the output to the file, used for logging it in case of failure
waitUntilMessageInFile() {
  __file="$1"
  __message="$2"
  __timeout="$3"
  __cmd="$4"
  __sleep=4
  [ -n "$TEST" ] && cmd "## Wait for: '$__message'" || log "Waiting for server to start, timeout=$__timeout secs, message='$__message'"
  [ -n "$TEST" ] && return 0
  while [ $__timeout -gt 0 ]
  do
    kill -0 $pid_run 2>/dev/null
    if [ $? != 0 ]
    then
      tsConfigModified "$__file" && return 2
      reportOutErrors "$__file" "Error $__cmd failed to start" && return 1
    fi
    __lasted=`expr $3 - $__timeout`
    __perl="perl -pe 's~^.*($__message.*)~\$1~g'"
    egrep -q "$__message" "$__file"  \
      && H=`egrep "$__message" $__file | eval "$__perl" | head -1` \
      && log "Found '$H' in $__file after $__lasted secs" \
      && echo ">>>> PiT: Found '$H' after $__lasted secs" >> "$__file" \
      && sleep $__sleep && return 0
    sleep $__sleep && __timeout=`expr $__timeout - $__sleep`
  done
  reportOutErrors "$__file"  "Timeout: could not find '$__message' in $__file after $3 secs"
  return 1
}

## Infinite loop playing a bell in console
## Used in interactive moded for alerting the user that last command has finished
playBell() {
  while true
  do
    sleep 2 && printf "\a."
  done
}

## Alert user with a bell and wait until they push enter
## only for interactive mode
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
  curl -s telnet://localhost:$1 >/dev/null 2>/dev/null &
  pid_curl=$!
  isWindows && sleep 4 || sleep 2
  kill $pid_curl >/dev/null 2>/dev/null || return 1
}

## Wait until port is listening
waitUntilPort() {
  log "Waiting for port $1 to be available"
  __i=1
  while true; do
    checkPort $1 && echo ">>>> PiT: Checked that port $1 is listening" >> "$3" && return 0
    __i=`expr $__i + 1`
    [ $__i -gt $2 ] && err "Server not listening in port $1 after $2 secs" && return 1
  done
}

## App context in Karaf takes a while after the server is listening
waitUntilAppReady() {
  [ -n "$TEST" ] && return
  waitUntilPort $2 $3 $4 || return 1
  [ "$1" = vaadin-flow-karaf-example ] && warn "sleeping 30 secs for the context" && sleep 10 || true
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
## $1 url to check
## $2 file to send the output
## $3 verbose mode (it means that the output is also printed in the console)
checkHttpServlet() {
  __url="$1"
  __ofile="$2"
  __cfile="curl-"`uname`".out"
  [ -n "$TEST" ] && return 0
  rm -f $__cfile
  log "Checking whether url $__url returns HTTP 200"
  runToFile "curl -s --fail -I -L --insecure -H Accept:text/html $__url" "$__cfile" "$VERBOSE"
  [ $? != 0 ] && reportOutErrors "$__ofile" "Server Logs" && return 1 || return 0
}

## Hits an HTTP server until vaadin finishes to compile the frontend in dev-mode
## This is the equivalent to open browser and wait for the spinner to disappear when frontend is compiling
## $1 url to check
## $2 file to send the output
waitUntilFrontendCompiled() {
  __url="$1"
  __ofile="$2"
  [ -n "$TEST" ] && return 0
  log "Waiting for dev-mode to be ready at $__url"
  __time=0
  while true; do
    H=`curl --retry 4 --retry-all-errors -f -s -v $__url -L -H Accept:text/html -o /dev/null 2>&1`
    __err=$?
    if [ $__err != 0 ]; then
       if tsConfigModified $__ofile; then
         echo ">>>> PiT: config file modified, retrying ...." >> "$__ofile" && reportOutErrors "$__ofile" "File tsconfig/types.d was modified and servlet threw an Exception" "$_diff"
         return 2
       else
         echo ">>>> PiT: Found Error when compiling frontend" >> "$__ofile" && reportOutErrors "$__ofile" "Error ($__err) checking dev-mode"
         return 1
       fi
    fi
    if echo "$H" | grep -q "X-DevModePending"; then
      sleep 3
      __time=`expr $__time + 3`
    else
      echo ">>>> PiT: Checked that frontend is compiled and dev-mode is ready after $__time secs" >> "$__ofile"
      log "Found a valid response after $__time secs"
      return
    fi
  done
}

## get a property value from pom.xml, normally used for version of some dependency
## $1: property name
getMavenVersion() {
  for __vfile in `find * -name pom.xml 2>/dev/null | egrep -v 'target/|bin/'`
  do
    H=`getCurrProperty $__prop $__vfile`
    [ -n "$H" ] && echo "$H" && return 0
  done
}

## Set the value of a property in the pom file, returning error if unchanged
## $1: property name
## $2: new value
setVersion() {
  __prop=$1
  __nversion=$2
  [ "false" != "$3" ] && git checkout -q .

  [ "$__nversion" = current ] && getMavenVersion $__prop && return 1
  changeMavenProperty $__prop $__nversion && echo $__nversion
}

## Get the value of a property in the gradle.properties or build.gradle file, normally the version of a dependency
## $1: property name
getGradleVersion() {
  if [ -f "gradle.properties" ]; then
    cat gradle.properties | grep "$1" | cut -d "=" -f2
  elif [ -f "build.gradle" ]; then
    cat build.gradle  | egrep 'set.*'$1 | perl -p -e 's/^.*"(\d[^"]+).*$/$1/'
  fi
}

## Set the value of a property in the gradle.properties file, returning error if unchanged
## $1: property name
## $2: new value
setGradleVersion() {
  __gradleProperty=$1
  __nversion=$2
  [ "false" != "$3" ] && git checkout -q .
  H=`getGradleVersion "$__gradleProperty"`
  [ "$__nversion" = current ] && echo "$H" && return 1
  __current=$H
  if [ -f "gradle.properties" ]; then
    setPropertyInFile gradle.properties $__gradleProperty $__nversion
  elif [ -f "build.gradle" ]; then
    runCmd -f "Changing $__gradleProperty to $__nversion in build.gradle" "perl -pi -e 's/^(.*set.*$__gradleProperty.*?)(\\d[^\"]+)(.*)\$/\${1}${__nversion}\${3}/g' build.gradle"
    runCmd -f "Changing vaadin plugin to $__nversion in build.gradle" "perl -pi -e \"s/(id +'com\\.vaadin' +version +')[\\d\\.]+(')/\\\${1}${__nversion}\\\${2}/\" build.gradle"
  fi
}

## Set version for a specific artifact in build.gradle
## $1: groupId:artifactId (for dependencies) or plugin.id (for plugins)
## $2: new version
setVersionInGradle() {
  local identifier="$1"
  local newVersion="$2"
  local buildFile="build.gradle"

  [ ! -f "$buildFile" ] && return 0
  [ -z "$newVersion" ] && return 1

  # Check if identifier contains ':' (dependency format: groupId:artifactId)
  if echo "$identifier" | grep -q ':'; then
    local groupId=$(echo "$identifier" | cut -d':' -f1)
    local artifactId=$(echo "$identifier" | cut -d':' -f2)

    # Update dependency version: implementation 'groupId:artifactId:version'
    if grep -q "$identifier:" "$buildFile"; then
      [ -z "$TEST" ] && warn "updating dependency $identifier version to $newVersion in $buildFile" || cmd "## updating dependency $identifier version to $newVersion in $buildFile"

      _cmd="perl -pi -e \"s/(['\\\"]$identifier:)[^'\\\"]+(['\\\"])/\\\${1}$newVersion\\\${2}/g\" \"$buildFile\""
      cmd "$_cmd"
      [ -n "$TEST" ] || eval "$_cmd"
    fi
  else
    # Update plugin version: id 'plugin.name' version 'x.y.z'
    local pluginId="$identifier"

    if grep -q "id ['\"]$pluginId['\"] version" "$buildFile"; then
      [ -z "$TEST" ] && warn "updating plugin $pluginId version to $newVersion in $buildFile" || cmd "## updating plugin $pluginId version to $newVersion in $buildFile"

      _cmd="perl -pi -e \"s/(id ['\\\"]$pluginId['\\\"] version ['\\\"])[^'\\\"]+(['\\\"])/\\\${1}$newVersion\\\${2}/g\" \"$buildFile\""
      cmd "$_cmd"
      [ -n "$TEST" ] || eval "$_cmd"
    fi
  fi
}

## checks whether an express dev-bundle has been created for the project
checkBundleNotCreated() {
  log "Checking Express Bundle"
  if grep -q "A development mode bundle build is not needed" "$1" ; then
    log "Using dev-bundle, no need to compile frontend"
  else
    reportOutErrors "$1" "Default vaadin-dev-bundle is not used"
    ## TODO: reenable bunding check (broken in 24.8.1 and 15.0)
    # return 1
    return 0
  fi
}

## check that there are no spring or hilla dependencies in the project
checkNoSpringDependencies() {
  T=`mvn -ntp -B dependency:tree`
  # https://github.com/vaadin/flow-components/issues/7213
  H=`echo "$T" | egrep -i "spring|hilla" | egrep -v "spring-data-commons|hilla-dev"`
  [ -n "$H" ] && reportError "There are spring/hilla dependencies" "$H" && echo "$H" && return 1
  H=`echo "$T" | egrep "spring-data-commons|hilla-dev"`
  [ -n "$H" ] && reportError "There is spring-data-commons|hilla-dev dependency" "$H" && echo "$H" && return 0
  log "No Spring/Hilla dependencies found"
}

## check that there are no warnings during vite compilation in the logs file
checkViteCompilationWarnings() {
  log "Checking Vite Compilation Warnings"
  H=`grep "DevServerOutputTracker   : Failed" "$1"`
  [ -n "$H" ] && reportOutErrors "$1" "Vite Compilation Warnings"
}

## Get a specific version from the platform versions.json
## $1 : platform branch
## $2 : module name
getVersionFromPlatform() {
  curl -s "https://raw.githubusercontent.com/vaadin/platform/$1/versions.json" 2>/dev/null \
      | egrep -v '^[1-4]' | tr -d "\n" |tr -d " "  | sed -e 's/^.*"'$2'":{"javaVersion"://'| cut -d '"' -f2
}

## Set version of a property with the value gotten from the versions.json
## $1: version of the platform (used to compute the branch)
## $2: module name
## $3: property name to set with the version in the pom.xml
setVersionFromPlatform() {
  __nversion=$1
  [ $__nversion = current ] && return
  VERS=`getVersionFromPlatform $__nversion $2`
  [ -z "$VERS" ] && VERS=`getVersionFromPlatform master $2`
  setVersion $3 "$VERS" false
}

## Set flow.version based on the platform's version.json
## $1: version of the platform
setFlowVersion() {
  setVersionFromPlatform $1 flow flow.version
}

## Set mpr.version based on the platform's version.json
## $1: version of the platform
setMprVersion() {
  setVersionFromPlatform $1 mpr-v8 mpr.version
}

getPomFiles() {
  find * -name pom.xml 2>/dev/null | egrep -v 'target/|bin/'
}

## an utility method for changing blocks in maven, they need to have the structure
## <tag><groupId></groupId><artifactId></artifactId><version></version>(optional_line)</tag>
## we can change groupId, artifactId, version, and optional_line
## $1: tag (dependency if empty)
## $2: groupId
## $3: artifactId
## $4: version (keep the same if empty, delete if 'remove' value is provided, or do not modify if version tag is not present)
changeMavenBlock() {
  __tag=${1:-dependency}
  __grp=$2
  __id=$3
  __nvers=${4:-\$\{8\}}
  __grp2=${5:-$__grp}
  __id2=${6:-$__id}
  for __file in `getPomFiles`
  do
    cp $__file $$-1
    if [ "$4" = remove ]; then
      _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>)(\s*.*?)?(\s*</$__tag>)||msg' $__file"
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')\s*(</groupId>\s*<artifactId>)('$__id')\s*(</artifactId>)(\s*.*?)?(\s*</'$__tag'>)||msg' $__file
    elif [ -n "$4" ]; then
      __content=`cat $__file`
      __found=`perl -0777 -pe 's|.*<'$__tag'>\s*<groupId>'$__grp'</groupId>\s*<artifactId>'$__id'</artifactId>\s*<version>([^<]+)</version>\s*.*?\s*</'$__tag'>.*|${1}|msg' $__file`
      if [ "$__content" = "$__found" ]; then
        __extra=${7:-\$\{8\}}
        _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}${__extra}\${9}|msg' $__file"
        perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__extra}'${9}|msg' $__file
      else
        __extra=${7:-\$\{11\}}
        _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}${__nvers}\${9}\${10}${__extra}\${12}|msg' $__file"
        perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__nvers}'${9}${10}'${__extra}'${12}|msg' $__file
      fi
    else
      _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}${__nvers}\${9}\${10}'${__extra}'\${12}|msg' $__file"
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__nvers}'${9}${10}'${__extra}'${12}|msg' $__file
    fi
    cp $__file $$-2
    __diff=`diff -w $$-1 $$-2`
    if [ -n "$__diff" ]; then
      [ "$4" = remove ] && __msg="Remove" || __msg="Change"
      [ -z "$TEST" ] && warn "$__msg $__tag $__grp:$__id $__nvers"
      [ -n "$TEST" ] && cmd "## $__msg Maven Block $__tag $__grp:$__id -> $__grp2:$__id2:$4 $9"
      cmd "$_cmd"
    fi
    rm -f $$-1 $$-2
  done
}

## Reads a property from a pom file, it's faster than
##   mvn help:evaluate -Dexpression=property -q -DforceStdout
## $1: property name
## $2: pom.xml file to read
getCurrProperty() {
  H=`grep "<$1>" $2 | perl -pe 's|\s*<'$1'>(.+?)</'$1'>\s*|$1|'`
  [ -n "$H" ] && echo "$H" && return 0
}

## change the content of a block in any file
## $1: left regular expression
## $2: right regular expression
## $3: new content of the block, you need to provide ${1} ${2} ${3} to use the left, old content and right groups
## $4: file
changeBlock() {
  __left="$1"; __right="${2:-$1}"; __val="$3"; __bfile="$4";
  cp $__bfile $$-1
  if [ "$__val" = remove ]; then
    _cmd="perl -0777 -pi -e 's|($__left)(.*?)($__right)||gs' $__bfile"
          perl -0777 -pi -e 's|('$__left')(.*?)('$__right')||gs' $__bfile
  else
    _cmd="perl -0777 -pi -e 's|($__left)(.*?)($__right)|${__val}|gs' $__bfile"
          perl -0777 -pi -e 's|('$__left')(.*?)('$__right')|'"${__val}"'|gs' $__bfile
  fi
  __diff=`diff -w $$-1 $__bfile`
  rm -f $$-1
  [ -n "$__diff" ] && cmd "$_cmd" && __err=0 || __err=1
  [ -z "$TEST" -a -n "$__diff" -a "$__val" =  remove ] && warn "Remove $__left in $__bfile"
  [ -z "$TEST" -a -n "$__diff" -a "$__val" != remove ] && warn "Changed '($__left)($__right)' to '$__val' in $__bfile"
  return $__err
}

## change a maven property in the pom.xml, faster than
##  mvn -q versions:set-property -Dproperty=property -DnewVersion=value
## $1: property name
## $2: value (if value is 'remove' the property is removed)
changeMavenProperty() {
  __prop=$1; __val=$2; __ret=0;
  for __propfile in `getPomFiles`
  do
    __cur=`getCurrProperty $__prop $__propfile`
    if [ "$__val" != remove -a "$__val" != "$__cur" ]; then
      runCmd -f "Changing Maven property $__prop from $__cur -> $__val in $__propfile" \
        "perl -pi -e 's|(\s*<'$__prop'>)[^\s]+(</'$__prop'>)|\${1}${__val}\${2}|g' $__propfile"
      __ret=$?
    elif [ "$__val" = remove -a -n "$__cur" ]; then
      runCmd -f "Removing Maven property $__prop from $__propfile" \
        "perl -pi -e 's|(\s*<'$__prop'>)[^\s]+(</'$__prop'>)||g' $__propfile"
      __ret=$?
    else
      __ret=1
    fi
  done
  return $__ret
}

## rename a maven property in the pom.xml
## $1: property1 name
## $2: property2 name
renameMavenProperty() {
  __prop1=$1; __prop2=$2; __ret=1;
  for __file in `getPomFiles`
  do
    __cur=`getCurrProperty $__prop1 $__file`
    [ -z "$__cur" ] && continue
    runCmd -f "Rename Maven property $__prop1 -> $__prop2" \
      "perl -0777 -pi -e 's|(<$__prop1>[^\s]+)(/$__prop1>)|<$__prop2>$__cur</$__prop2>|g' $__file"
    [ $? = 0 -a $__ret = 1 ] && __ret=0
  done
  return $__ret
}

## removes a maven block from the pom.xml
## $1: tag
## $2: groupId
## $3: artifactId
removeMavenBlock() {
  changeMavenBlock "$1" "$2" "$3" remove
}

## removes a maven property
## $1: maven property
removeMavenProperty() {
  changeMavenProperty "$1" remove
}

## set a property in a properties file
## $1: property file
## $2: property name
## $3: value
setPropertyInFile() {
  __file=$1; __key=$2; __val=$3
  [ ! -f "$__file" ] && return 0
  cp $__file $$-1
  __cur=`egrep ' *'$__key $__file | tr ':' '=' | cut -d "=" -f2-`
  if [ "$__val" = remove ]; then
    _cmd="perl -pi -e 's|\s*($__key)\s*([=:]).*||g' $__file"
          perl -pi -e 's|\s*('$__key')\s*([=:]).*||g' $__file
  elif [ -n "$__cur" ]; then
    _cmd="perl -pi -e 's|\s*($__key)\s*([=:]).*|\${1}\${2}${__val}|g' $__file"
          perl -pi -e 's|\s*('$__key')\s*([=:]).*|${1}${2}'"${__val}|g" $__file
  else
    _cmd="echo '$__key=$__val' >> $__file"
          echo "$__key=$__val" >> "$__file"
  fi
  __diff=`diff -w $$-1 $__file`
  rm -f $$-1
  [ -z "$TEST" -a -n "$__diff" -a "$__val" =  remove ] && warn "Remove $__key in $__file"
  [ -z "$TEST" -a -n "$__diff" -a "$__val" != remove ] && warn "Change $__key from '$__cur' to '$__val' in $__file"
  [ -n "$__diff" ] && cmd "$_cmd"
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  for __file in `find . -name application.properties`; do
    setPropertyInFile $__file vaadin.launch-browser remove
  done
}

## pnpm is quite faster than npm
enablePnpm() {
  for __file in `find . -name application.properties`; do
    setPropertyInFile $__file vaadin.pnpm.enable true
  done
}

## vite is faster than webpack
enableVite() {
  for __file in `find . -name application.properties`; do
    setPropertyInFile com.vaadin.experimental.viteForFrontendBuild true
  done
}

## Compute whether the headless argument must be set
isHeadless() {
  IP=`hostname -i 2>/dev/null`
  test "$HEADLESS" = true -o -z "$VERBOSE" -a "$HEADLESS" != false -o -n "$IP"
}

## print used versions of node, java and maven
printVersions() {
  computeNpm
  [ -n "$TEST" ] && return
  _vers=`MAVEN_OPTS="$MAVEN_OPTS" MAVEN_ARGS="$MAVEN_ARGS" $MVN -version | tr \\\\ / 2>/dev/null | egrep -i 'maven|java'`
  [ $? != 0 ] && err "Error $? when running $MVN, $_vers" && return 1
  log "==== VERSIONS ====

MAVEN_OPTS='$MAVEN_OPTS' MAVEN_ARGS='$MAVEN_ARGS' $MVN -version
$_vers
NODE=$NODE
Java version: `java -version 2>&1`
Node version: `"$NODE" --version`
NPM=$NPM
Npm version: `eval $NPM --version`
"
}

## Add extr repo to the pom.xml
## $1: repo url
addRepoToPom() {
  U="$1"
  grep -q "$U" pom.xml && return 0
  for R in repositor pluginRepositor; do
    if ! grep -q $R'ies>' pom.xml; then
      __cmd="perl -pi -e 's|(\s*)(</project>)|\$1\$1<${R}ies><${R}y><id>v</id><url>${U}</url></${R}y></${R}ies>\n\$1\$2|' pom.xml"
    else
      __cmd="perl -pi -e 's|(\s*)(<${R}ies>)|\$1\$2\n\$1\$1<${R}y><id>v</id><url>${U}</url></${R}y>|' pom.xml"
    fi
    runCmd -f "Adding $U repository to pom.xml" "$__cmd"
  done
}

## Adds a maven dep in the block </dependencies> previous to </build>
## $1 groupId
## $2 artifactId
## $3 scope
## $4 extra content e.g. <version>nnn</version>
addMavenDep() {
  local GI=$1; local AI=$2; local SC=$3; local EX="$4"
  local t='    '
  __cmd="perl -0777 -pi -e 's|(\n[ \t]*)(</dependencies>\s+(<build>\|<repo\|<dependencyM))|\$1$t<dependency>\$1$t$t<groupId>${GI}</groupId>\$1$t$t<artifactId>${AI}</artifactId>\$1$t$t<scope>${SC}</scope>${EX}\$1$t</dependency>\$1\$2|' pom.xml"
  runCmd -f "Adding dependency $GI $AI $SC to pom.xml" "$__cmd"
}

## Add extr repo to gradle files
## $1: repo url
addRepoToGradle() {
  U="$1"
  # Check if URL contains http to determine the format
  if echo "$U" | grep -q "http"; then
    REPO_FORMAT="maven { url = \"$U\" }"
    BUILD_REPO_FORMAT="maven { url \"$U\" }"
  else
    REPO_FORMAT="$U"
    BUILD_REPO_FORMAT="$U"
  fi

  H=`[ -f settings.gradle ] && grep -E "pluginManagement|$U" settings.gradle`
  if [ -z "$H" ]; then
    runCmd -f "Adding $U repository to settings.gradle" \
      "perl -0777 -pi -e 's|^|pluginManagement {\n  repositories {\n    $REPO_FORMAT\n    gradlePluginPortal()\n  }\n}\n|' settings.gradle"
  fi
  grep -q "$U" build.gradle && return 0
  runCmd -f "Adding $U repository to build.gradle" \
    "perl -pi -e 's|(repositories\s*{)|\$1\n    $BUILD_REPO_FORMAT|' build.gradle"
}

## adds the pre-releases repositories to the pom.xml
addPrereleases() {
  [ -f pom.xml ] && addRepoToPom "https://maven.vaadin.com/vaadin-prereleases"
  [ -f build.gradle ] && addRepoToGradle "https://maven.vaadin.com/vaadin-prereleases"
}

# adds spring pre-releases repo to pom.xml
addSpringReleaseRepo() {
  [ -f pom.xml ] && addRepoToPom "https://repo.spring.io/milestone/"
  [ -f build.gradle ] && addRepoToGradle "https://repo.spring.io/milestone/"
}

## enables snapshots for the pre-releases repositories in pom.xml
enableSnapshots() {
  for __file in `getPomFiles`
  do
    changeBlock '<snapshots>\s+<enabled>' '</enabled>\s+</snapshots>' '${1}true${3}'  $__file
  done
}

## Downloads a file from the internet
## $1: the URL
download() {
  [ -z "$VERBOSE" ] && __S="-s"
  [ -n "$2" -a "$2" != '-' ] && __O="-o $2"
  runCmd -f "Downloading $1" "curl $__S -L $__O $1"
}

## Installs jet brains java runtime, used for testing the hotswap agent
## It updates JAVA_HOME and PATH variables, and sets the HOT one with the parameters to enable it.
installJBRRuntime() {
  # https://github.com/HotswapProjects/HotswapAgent/releases/
  __hvers="2.0.1"
  # https://github.com/JetBrains/JetBrainsRuntime/releases
  __jvers="21.0.5"
  __vers="b631.16"

  __hsau="https://github.com/HotswapProjects/HotswapAgent/releases/download/RELEASE-${__hvers}/hotswap-agent-${__hvers}.jar"
  __jurl="https://cache-redirector.jetbrains.com/intellij-jbr"

  [ -z "$TEST" ] && warn "Installing JBR for hotswap testing"

  isLinux   && __jurl="$__jurl/jbr-${__jvers}-linux-x64-${__vers}.tar.gz"
  isMac     && __jurl="$__jurl/jbr-${__jvers}-osx-x64-${__vers}.tar.gz"
  isWindows && __jurl="$__jurl/jbr-${__jvers}-windows-x64-${__vers}.tar.gz"
  if [ ! -f /tmp/JBR.tgz ]; then
    download "$__jurl" "/tmp/JBR.tgz" || return 1
  fi
  if [ ! -d /tmp/jbr ]; then
    mkdir -p /tmp/jbr
    runCmd -f "Extracting JBR" "tar -xf /tmp/JBR.tgz -C /tmp/jbr --strip-components 1" || return 1
  fi
  setJavaPath "/tmp/jbr" || return 1
  if [ ! -f $JAVA_HOME/lib/hotswap/hotswap-agent.jar ] ; then
    mkdir -p $JAVA_HOME/lib/hotswap
    download "$__hsau" "$H/lib/hotswap/hotswap-agent.jar" || return 1
    [ -z "$TEST" ] && log "Installed "`ls -1 $H/lib/hotswap/hotswap-agent.jar`
  fi
  export HOT="-Djetty.deployMode=FORK -Djetty.jvmArgs=-XX:HotswapAgent=fatjar"
}

## Installs a certain version of OPENJDK
# $1: version (eg: 17, 21, 23)
installJDKRuntime() {
  __version=$1
  base_url="https://download.oracle.com/java"
  isLinux && os_suffix="linux-x64" && __ext="tar.gz"
  isMac && os_suffix="macos-x64" && __ext="tar.gz"
  isWindows && os_suffix="windows-x64" && __ext="zip"
  [ -z "$__version" -o -z "$os_suffix" ] && return 1
  __nversion="$__version"
  __vpath="latest"
  [ "$__version" = "18" ] && __nversion="18.0.1" && __vpath="archive"
  [ "$__version" = "17" ] && __nversion="17.0.12" && __vpath="archive"
  tar_file="jdk-${__nversion}_${os_suffix}_bin.${__ext}"
  tmp_dir="/tmp/jdk-${__version}"
  __jurl="${base_url}/${__version}/${__vpath}/${tar_file}"
  if [ ! -f "/tmp/$tar_file" ]; then
    download "$__jurl" "/tmp/$tar_file" || return 1
  fi
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  runCmd -f "Extracting JDK-$__version" "tar -xf "/tmp/$tar_file" -C "$tmp_dir" --strip-components 1" || return 1

  setJavaPath "$tmp_dir" || return 1
}

setJavaPath() {
  H=`find "$1" -name Home -type d`
  [ -z "$H" ] && H="$1"
  [ -z "$TEST" ] && log "Setting JAVA_HOME=$H PATH=$H/bin:\$PATH"
  [ -n "$TEST" ] && cmd "## Setting JAVA_HOME=$H PATH=$H/bin:\$PATH"
  [ ! -d "$H/bin" ] && return 1
  cmd "export PATH=$H/bin:\$PATH JAVA_HOME=$H"
  __PATH=$PATH
  __HOME=$JAVA_HOME
  export PATH="$H/bin:$PATH" JAVA_HOME="$H"
}

## Unsets the jet brains java runtime used for testing the hotswap agent
unsetJavaPath() {
  [ -n "$__HOME" -a -z "$TEST" ] && warn "Un-setting PATH and JAVA_HOME ($JAVA_HOME)"
  [ -n "$__HOME" -a -n "$TEST" ] && cmd "## Un-setting PATH and JAVA_HOME ($JAVA_HOME)"
  [ -n "$__PATH" ] && export PATH=$__PATH && unset __PATH
  [ -n "$__HOME" ] && export JAVA_HOME=$__HOME && unset __HOME || unset JAVA_HOME
  [ -n "$HOT" ]    && unset HOT
  return 0
}

## enables autoreload for preparing jet brains java runtime
## it modifies jetty in pom.xml and configures the hotswap-agent.properties
enableJBRAutoreload() {
  _p=src/main/resources/hotswap-agent.properties
  mkdir -p `dirname $_p` && echo "autoHotswap=true" > "$_p"
  [ -z "$TEST" ] && warn "Disabled Jetty autoreload"
  changeMavenProperty scan -1
}

## displays secs in mins:secs
## $1: seconds
secsToString() {
  __mins=`expr $1 / 60`
  __secs=`expr $1 % 60`
  printf "%.2d':%.2d\"" $__mins $__secs
}

## computes elapsed time
## $1: the starttime in `date +%s`, otherwise the time since the script was run
computeTime() {
  __start=${1:-$START}
  __end=`date +%s`
  secsToString `expr $__end - $__start`
}

## prints elapsed time
## $1: the starttime in `date +%s`, otherwise the time since the script was run
printTime() {
  H=`computeTime $1`
  echo ""
  log "Elapsed Time: $H\""
}

## update Gradle to the version provided in $1
upgradeGradle() {
  [ -z "$1" ] && return
  V=`$GRADLE --version | grep '^Gradle' | awk '{print $2}'`
  expr "$V" : "$1" >/dev/null && return
  runCmd -f "Upgrading Gradle from $V to $1" "$GRADLE wrapper -q --gradle-version $1"
}

## list all demos that are available in the vaadin website (examples and starters)
getReposFromWebsite() {
  _demos=`curl -s https://vaadin.com/examples-and-demos  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  _starters=`curl -s https://vaadin.com/hello-world-starters  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  printf "$_demos\n$_starters" | sort -u
}

## clean vaadin artifact from local maven repository with the version provided
cleanM2() {
  [ -n "$OFFLINE" -o -z "$1" -o ! -d ""`ls -1d ~/.m2/repository/com/vaadin/*/$1 2>/dev/null | head -1` ] && return
  warn "removing ~/.m2/repository/com/vaadin/*/$1"
  rm -rf ~/.m2/repository/com/vaadin/*/$1
}

## compute the latest version of hilla depending on the platform or hilla version provided in $1
getLatestHillaVersion() {
  case "$1" in
    24.[45].*|*-SNAPSHOT) echo "$1" && return ;;
    2.*)    echo "$1" && return ;;
    24.[012].*) G="2.4.[09]*";;
    24.3[.-]*) G="2.5.*";;
  esac
  curl -s https://api.github.com/repos/vaadin/hilla/releases | jq -r '.[].tag_name' | egrep "^$G$" | head -1
}

## compute the version to be used for testing the project for the next release
## version is provided with --version argument, but still it needs some adjustments if it's a hilla project
computeVersion() {
  [ "$2" = current ] && echo "$2" && return
  case $1 in
    *hilla*) getLatestHillaVersion "$2";;
    *) echo "$2";;
  esac

}

## compute the property used for the version of the project
computeProp() {
    case $1 in
      # *hilla*gradle) echo "hillaVersion";;
      *gradle*) echo "vaadinVersion";;
      # *typescript*|*hilla*|*react*|*-lit*) echo "hilla.version";;
      *) echo "vaadin.version";;
    esac
}

computeJavaMajor() {
  JavaMajor=`java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p'`
  [ -z "$JavaMajor" ] && err "Could not determine Java version minor" && return 1
  echo $JavaMajor
}

## compute the property used for the version of the project after applying a patch for the next release
## it was important when next version was for hilla/flow fussion (24.4)
computePropAfterPatch() {
  case $1 in
    *hilla*gradle) echo "hillaVersion";;
    *gradle) echo "vaadinVersion";;
    *typescript*|*hilla*|*react*|*-lit*) echo "hilla.version";;
    *) echo "vaadin.version";;
  esac
}

## return the version of one dependency in a maven project
# $1 groupId
# $2 artifactId
# $3 extra arguments to pass to mvn
getMvnDependencyVersion() {
  [ ! -f pom.xml ] && warn "Not a maven project" && return 1
  [ -z "$MVN" ] && computeMvn
  "$MVN" dependency:tree $3 | grep "$1:$2" | grep INFO | sed -e 's|.*.INFO. ||g' | cut -d : -f4
}

## set dependency of one specific package in pom.xml
# $1 groupId
# $2 artifactId
# $3 version
# $4 extra arguments to pass to mvn
setMvnDependencyVersion() {
  # expr "$3" : ".*SNAPSHOT" >/dev/null && _newVers=$3 || _newVers=$3
  _newVers=$3
  _curVers=`getMvnDependencyVersion "$1" "$2" "$4"` || return 1
  if [ "$_curVers" != "$_newVers" ]; then
    changeBlock '<artifactId>'$2'</artifactId>' '\s+</dependency>' '${1}<version>'$_newVers'</version>${3}' pom.xml
    _curVers=`getMvnDependencyVersion "$1" "$2" "$4"` || return 1
    [ "$_curVers" != "$_newVers" ] && err "CC version mismatch $_curVers != $_newVers" && return 1
  fi
  log "App is using $1:$2:$_curVers"
  return 0
}

validateToken() {
  [ -z "$GHTK" ] && return 1
  H=`curl -s -H "Authorization: Bearer $GHTK" https://api.github.com/user | jq '.login'`
  [ -z "$H" -o "$H" = null ] && err "Invalid GHTK, $H" && return 1
  log "Using GH $H"
  H=`curl -s -H "Authorization: Bearer $GHTK" https://api.github.com/repos/$1 | jq -r '.permissions.pull'`
  [ "$H" != true ] && err "No pull access $H" && return 1
  return 0
}

## change java version in pom files
## $1 new version
setJavaVersion() {
  for i in `getPomFiles`; do
    local v=`grep '</java.version>' pom.xml  | sed -e 's|[^0-9]||g'`
    [ -z "$v" -o "$v" = "$1" ] && return
    cmd "perl -pi -e 's|<java.version>\d+</java.version>|<java.version>'$1'</java.version>|' $i"
    perl -pi -e 's|<java.version>\d+</java.version>|<java.version>'$1'</java.version>|' $i
    [ -n "$TEST" ] || warn "Changed Java version from $v to $1 in $i"
  done
}
