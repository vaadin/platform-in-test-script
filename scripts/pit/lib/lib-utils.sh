## Check if the current OS is Linux
isLinux() {
  test `uname` = Linux
}
## Check if the current OS is macOS
isMac() {
  test `uname` = Darwin
}
## Check if the current OS is Windows (or not Linux/macOS)
isWindows() {
  ! isLinux && ! isMac
}

## Check if a set of commands passed as arguments are installed
## $*: command names to check
checkCommands() {
  local command_name
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
  local cmd
  if [ -f ~/.vaadin/proKey ]; then
    cmd="mv ~/.vaadin/proKey ~/.vaadin/proKey-$$"
    runCmd "Removing proKey license" "mv ~/.vaadin/proKey ~/.vaadin/proKey-$$"
  fi
}
## Restore pro-key removed in previous function
restoreProKey() {
  local H cmd
  [ ! -f ~/.vaadin/proKey-$$ ] && return
  H=`cat ~/.vaadin/proKey 2>/dev/null`
  cmd="mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey"
  runCmd "Restoring proKey license" "mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey"
  [ -z "$TEST" -a -n "$H" ] && reportError "A proKey was generated while running validation" "$H" && return 1
}

## Get PIDs for processes matching a pattern
## $1: pattern to match against process command line
getPids() {
  local H P
  H=`grep -a "" /proc/*/cmdline 2>/dev/null | xargs -0 | grep -v grep | perl -pe 's|/proc/(.*?)/cmdline:|$1 |g'`
  if [ -n "$H" ]
  then
    P=`echo "$H" | grep "$1" | awk '{print $1}'`
  else
    P=`ps -feaw | grep "$1" | grep -v grep | awk '{print $2}'`
  fi
  [ -n "$P" ] && echo "$P" | tr "\n" " " && return 0 || return 1
}

## Kills a process with its children and wait until complete
## $*: process IDs to kill
doKill() {
  local procs
  while [ -n "$1" ]; do
    procs=`type pgrep >/dev/null 2>&1 && pgrep -P $1`" $1"
    kill $procs 2>/dev/null
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

## Register a command to be executed on script exit
## $1: command to execute on exit
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

## Print wrapper for coloring outputs
## $1: prefix string
## $2: text attribute (0=normal, 1=bold, 2=dim)
## $3: color code (31=red, 32=green, 33=yellow, 34=blue, 36=cyan)
## $4: message to print
print() {
  printf "\033[0m$1\033[$2;$3m$4\033[0m" >&2
}

## Print with newline
## $1: prefix string
## $2: text attribute
## $3: color code
## $4: message to print
printnl() {
  print "$1" "$2" "$3" "$4\n"
}

## Check if first argument is -n flag (newline option)
## $1: optional -n flag
isnl() {
  local opt
  expr "$1" : "\-" > /dev/null && opt=${1#-} && shift || opt=""
  [ "$opt" = n ] && echo "" >&2 || return 1
  true
}
## Log a message with timestamp (green color)
## $*: message to log
log() {
  isnl $1 && shift
  [ -n "$TEST" ] && cmd "## $*" && return 0
  print '> ' 0 32 "$*"
  printnl '' 2 36 " - "`computeTime`""
}
## Log a bold message with timestamp (bold green color)
## $*: message to log
bold() {
  isnl $1 && shift
  [ -n "$TEST" ] && cmd "## $*" && return 0
  print '> ' 1 32 "$*"
  printnl '' 2 36 " - "`computeTime`""
}
## Print an error message (red color)
## $*: error message
err() {
  printnl '> ' 0 31 "$*"
}
## Print a warning message (yellow color)
## $*: warning message
warn() {
  isnl $1 && shift
  printnl '> ' 0 33 "$*"
}
## Print a command (blue color)
## $*: command to display
cmd() {
  local cmd_str
  isnl $1 && shift
  cmd_str=`printf "$*" | tr -s " " | perl -pe 's|\n|\\\\\\\n|g'`
  printnl '  ' 1 34 " $cmd_str"
}
## Print a dimmed message (cyan color)
## $*: message to print
dim() {
  printnl '' 0 36 "$*"
}

## Reports an error to the GHA step-summary section
## $1: report header
## $*: body
reportError() {
  local head H
  head=$1; shift
  [ -z "$head" -o -z "$*" ] && return
  warn "reporting error: $head"
  [ -z "$GITHUB_STEP_SUMMARY" ] && return
  H=`echo "$*" | awk '{print substr ($0, 0, 300)}' | tail -n 100000`
  cat << EOF >> "$GITHUB_STEP_SUMMARY"
<details>
<summary><h4>$head</h4></summary>
<pre>
`echo "$H"`
</pre>
</details>
EOF
}

## Reports a file content to the GHA step-summary section
## $1: file
## $2: report header
reportOutErrors() {
  local H
  [ -f "$1" ] || return
  H=`cat "$1" | egrep -v ' *at |org.atmosphere.cpr.AtmosphereFramework' | tail -300`
  reportError "$2" "$H"
}

## Ask user a question, response is stored in key variable
## $1: question to ask the user
ask() {
  # flush stdin
  while read -t1 ignore; do :; done
  printf "\033[0;32m$1\033[0m...">&2
  read key
}

## Compute the absolute PATH of the executed script
computeAbsolutePath() {
  local path
  path=`dirname $0 | sed -e 's,^\./,,'`
  ## Check whether the PATH is absolute
  [ `expr "$path" : '^/'` != 1 ] && path="$PWD/$path"
  echo "$path"
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
  local vnode npmjs
  vnode=~/.vaadin/node
  npmjs=$vnode/lib/node_modules/npm/bin/npm-cli.js
  NPM="'"`which npm`"'"
  NPX=`which npx`
  NODE=`which node`
  [ -x "$vnode/bin/node" -a -f "$npmjs" ] && export PATH="$vnode/bin:$PATH" && NODE="$vnode/bin/node" && NPM="'$NODE' '$npmjs'"
}

## Run a command, and shows a message explaining it
## $1: optional flags: -q (quiet, send output to dev/null) -f (force execution even when $TEST is set)
## $2: message to show
## $*: command line order and arguments
runCmd() {
  local saved_flags set_cmd opt silent force cmd pid err
  saved_flags=$-
  set +x
  expr $saved_flags : .*x >/dev/null && set_cmd="set -x" || set_cmd=true
  expr "$1" : "\-" > /dev/null && opt=${1#-} && shift || opt=""
  expr "$opt" : ".*q" >/dev/null && silent=true || silent=""
  expr "$opt" : ".*f" >/dev/null && force=true || force=""
  [ -z "$1" ] && echo "bad arguments call: runCmd <true|false|-q> <message> command args" && eval "$set_cmd" && return 1
  [ -z "$TEST" ] && log "$1" || cmd "## $1"
  shift
  cmd="${*}"
  cmd "$cmd"
  [ -z "$force" -a -n "$TEST" ] && eval "$set_cmd" && return 0
  if expr "$cmd" : ".*&$" >/dev/null
  then
    cmd=`echo "$cmd" | sed -e 's/&$//'`
    eval "$cmd" &
    pid=$!
    err=$?
    sleep 2
    kill -0 $pid 2>/dev/null || return 1
  else
    if [ -n "$VERBOSE" ]; then
      eval "$cmd" | tee -a runCmd.out
      err=$?
    else
      eval "trap 'trap - INT; kill -INT '$$'' INT; $cmd" > runCmd.out 2>&1
      err=$?
    fi
    [ $err != 0 -a -z "$VERBOSE" -a -n "$silent" ] && cat runCmd.out >&2
    rm -f runCmd.out
  fi
  eval "$set_cmd"
  return $err
}

## Run a command quietly (alias for runCmd -qf)
## $*: command to run
runCmdQuiet() {
  :
}

## Run a command and outputs its stdout/stderr to a file
## $1: command to run
## $2: file to send the output
## $3: verbose mode (if set, output is also printed to console)
## $4: send only stdout to file (if set, only stdout is redirected, stderr goes to console)
runToFile() {
  local cmd file verbose stdout E err
  cmd="$1"
  file="$2"
  verbose="$3"
  stdout="$4"
  [ -z "$TEST" ] && log "Running and sending output to > $file"
  expr "$1" : ".*mvn " >/dev/null && E=" $MAVEN_ARGS" || E=""
  cmd "$cmd $E"
  [ -n "$TEST" ] && return
  if [ -z "$verbose" ]
  then
    if [ -z "$stdout" ]; then
      eval "$cmd" >> "$file" 2>&1
      err=$?
    else
      eval "$cmd" >> "$file"
      err=$?
    fi
  else
    eval "$cmd" 2>&1 | tee -a "$file"
    err=$?
  fi
  [ $err != 0 ] && reportOutErrors "$file" "Error ($err) running $cmd" && return 1 || return 0
}

## Run a process silently in background sending its output to a file
## $1: command to run
## $2: file to send the output
## $3: verbose mode (if set, output is also tailed to console)
runInBackgroundToFile() {
  local cmd file verbose E
  cmd="$1"
  file="$2"
  verbose="$3"
  [ -z "$TEST" ] && log "Running in background and sending output to > $file"
  expr "$1" : ".*mvn " >/dev/null && E=" $MAVEN_ARGS" || E=""
  cmd "$cmd $E"
  [ -n "$TEST" ] && return
  touch "$file"
  if [ -n "$verbose" ]
  then
    tail -f "$file" &
    pid_tail=$!
  fi
  $cmd >> "$file" 2>&1 &
  pid_run=$!
  sleep 2
  kill -0 $pid_run 2>/dev/null || return 1
}

## Check whether flow modified the tsconfig.json file
## $1: log file to check and append results to
tsConfigModified() {
  local H
  grep -q "'tsconfig.json' has been updated" "$1" || return 1
  H=`git diff tsconfig.json 2>/dev/null`
  H="$H"`git diff types.d.ts 2>/dev/null`
  echo ">>>> PiT: Found tsconfig.json modified" >> "$1"
  reportOutErrors "File 'tsconfig.json' was modified and servlet threw an Exception" "$H"
}

## Wait until the specified message appears in the log file
## $1: file to continuously check for the presence of a message
## $2: message to wait for (can be a regular expression valid for egrep)
## $3: timeout in seconds
## $4: command that is sending output to the file (used for logging in case of failure)
waitUntilMessageInFile() {
  local file message timeout cmd sleep lasted perl H
  file="$1"
  message="$2"
  timeout="$3"
  cmd="$4"
  sleep=4
  [ -n "$TEST" ] && cmd "## Wait for: '$message'" || log "Waiting for server to start, timeout=$timeout secs, message='$message'"
  [ -n "$TEST" ] && return 0
  while [ $timeout -gt 0 ]
  do
    kill -0 $pid_run 2>/dev/null
    if [ $? != 0 ]
    then
      tsConfigModified "$file" && return 2
      reportOutErrors "$file" "Error $cmd failed to start" && return 1
    fi
    lasted=`expr $3 - $timeout`
    perl="perl -pe 's~^.*($message.*)~\$1~g'"
    egrep -q "$message" "$file"  \
      && H=`egrep "$message" $file | eval "$perl" | head -1` \
      && log "Found '$H' in $file after $lasted secs" \
      && echo ">>>> PiT: Found '$H' after $lasted secs" >> "$file" \
      && sleep $sleep && return 0
    sleep $sleep && timeout=`expr $timeout - $sleep`
  done
  reportOutErrors "$file"  "Timeout: could not find '$message' in $file after $3 secs"
  return 1
}

## Infinite loop playing a bell in console
## Used in interactive mode for alerting the user that last command has finished
playBell() {
  while true
  do
    sleep 2 && printf "\a."
  done
}

## Alert user with a bell and wait until they push enter
## $1: optional message to display to the user
waitForUserWithBell() {
  local message
  message=$1
  playBell &
  pid_bell=$!
  [ -n "$message" ] && log "$message"
  ask "Push ENTER to stop the bell and continue"
  doKill $pid_bell
  unset pid_bell
}

## Inform the user that app is running in localhost, then wait until the user pushes enter
## $1: port number where the app is running
waitForUserManualTesting() {
  local port
  port="$1"
  log "App is running in http://localhost:$port, open it in your browser"
  ask "When you finish, push ENTER  to continue"
}

## Check if a port is occupied
## $1: port number to check
checkPort() {
  local pid_curl
  curl -s telnet://localhost:$1 >/dev/null 2>/dev/null &
  pid_curl=$!
  isWindows && sleep 4 || sleep 2
  kill $pid_curl >/dev/null 2>/dev/null || return 1
}

## Wait until a port is listening
## $1: port number to wait for
## $2: timeout in seconds
## $3: log file to append results to
waitUntilPort() {
  local i
  log "Waiting for port $1 to be available"
  i=1
  while true; do
    checkPort $1 && echo ">>>> PiT: Checked that port $1 is listening" >> "$3" && return 0
    i=`expr $i + 1`
    [ $i -gt $2 ] && err "Server not listening in port $1 after $2 secs" && return 1
  done
}

## Wait until the app context is ready (Karaf apps need extra time)
## $1: app name
## $2: port number
## $3: timeout in seconds
## $4: log file
waitUntilAppReady() {
  [ -n "$TEST" ] && return
  waitUntilPort $2 $3 $4 || return 1
  [ "$1" = vaadin-flow-karaf-example ] && warn "sleeping 30 secs for the context" && sleep 10 || true
}

## Check whether a port is already in use on this machine
## $1: port number to check
checkBusyPort() {
  local port err
  port="$1"
  log "Checking whether port $port is busy"
  checkPort $port
  err=$?
  [ $err = 0 ] && err "Port ${port} is occupied" && return 1 || return 0
}

## Check that an HTTP servlet request responds with 200
## $1: url to check
## $2: log file from server output (used for error reporting)
checkHttpServlet() {
  local url ofile cfile
  url="$1"
  ofile="$2"
  cfile="curl-"`uname`".out"
  [ -n "$TEST" ] && return 0
  rm -f $cfile
  log "Checking whether url $url returns HTTP 200"
  runToFile "curl -s --fail -I -L --insecure -H Accept:text/html $url" "$cfile" "$VERBOSE"
  [ $? != 0 ] && reportOutErrors "$ofile" "Server Logs" && return 1 || return 0
}

## Hits an HTTP server until Vaadin finishes compiling the frontend in dev-mode
## This is equivalent to opening a browser and waiting for the spinner to disappear when frontend is compiling
## $1: url to check
## $2: log file to send output and check for errors
waitUntilFrontendCompiled() {
  local url ofile time H err
  url="$1"
  ofile="$2"
  [ -n "$TEST" ] && return 0
  log "Waiting for dev-mode to be ready at $url"
  time=0
  while true; do
    H=`curl --retry 4 --retry-all-errors -f -s -v $url -L -H Accept:text/html -o /dev/null 2>&1`
    err=$?
    if [ $err != 0 ]; then
       if tsConfigModified $ofile; then
         echo ">>>> PiT: config file modified, retrying ...." >> "$ofile"
         return 2
       else
         echo ">>>> PiT: Found Error when compiling frontend" >> "$ofile" && reportOutErrors "$ofile" "Error ($err) checking dev-mode"
         return 1
       fi
    fi
    if echo "$H" | grep -q "X-DevModePending"; then
      sleep 3
      time=`expr $time + 3`
    else
      echo ">>>> PiT: Checked that frontend is compiled and dev-mode is ready after $time secs" >> "$ofile"
      log "Found a valid response after $time secs"
      return
    fi
  done
}

## Get a property value from pom.xml, normally used for version of some dependency
## $1: property name
getMavenVersion() {
  local vfile H prop
  prop=$1
  for vfile in `find * -name pom.xml 2>/dev/null | egrep -v 'target/|bin/'`
  do
    H=`getCurrProperty $prop $vfile`
    [ -n "$H" ] && echo "$H" && return 0
  done
}

## Set the value of a property in pom.xml, returning error if unchanged
## $1: property name
## $2: new value (or 'current' to get current version without changing)
## $3: optional, if 'false' skip git checkout
setVersion() {
  local prop nversion
  prop=$1
  nversion=$2
  [ "false" != "$3" ] && git checkout -q .

  [ "$nversion" = current ] && getMavenVersion $prop && return 1
  changeMavenProperty $prop $nversion && echo $nversion
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

## Set the value of a property in gradle.properties or build.gradle, returning error if unchanged
## $1: property name
## $2: new value (or 'current' to get current version without changing)
## $3: optional, if 'false' skip git checkout
setGradleVersion() {
  local gradleProperty nversion H current
  gradleProperty=$1
  nversion=$2
  [ "false" != "$3" ] && git checkout -q .
  H=`getGradleVersion "$gradleProperty"`
  [ "$nversion" = current ] && echo "$H" && return 1
  current=$H
  if [ -f "gradle.properties" ]; then
    setPropertyInFile gradle.properties $gradleProperty $nversion
  elif [ -f "build.gradle" ]; then
    runCmd -f "Changing $gradleProperty to $nversion in build.gradle" "perl -pi -e 's/^(.*set.*$gradleProperty.*?)(\\d[^\"]+)(.*)\$/\${1}${nversion}\${3}/g' build.gradle"
    runCmd -f "Changing vaadin plugin to $nversion in build.gradle" "perl -pi -e \"s/(id +'com\\.vaadin' +version +')[\\d\\.]+(')/\\\${1}${nversion}\\\${2}/\" build.gradle"
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

## Check whether an express dev-bundle has been created for the project
## $1: log file to check
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

## Check that there are no Spring or Hilla dependencies in the project
## These dependencies should not be present in certain pure Flow projects
checkNoSpringDependencies() {
  local T H
  T=`mvn -ntp -B dependency:tree`
  # https://github.com/vaadin/flow-components/issues/7213
  H=`echo "$T" | egrep -i "spring|hilla" | egrep -v "spring-data-commons|hilla-dev"`
  [ -n "$H" ] && reportError "There are spring/hilla dependencies" "$H" && echo "$H" && return 1
  H=`echo "$T" | egrep "spring-data-commons|hilla-dev"`
  [ -n "$H" ] && reportError "There is spring-data-commons|hilla-dev dependency" "$H" && echo "$H" && return 0
  log "No Spring/Hilla dependencies found"
}

## Check that there are no warnings during Vite compilation in the log file
## $1: log file to check
checkViteCompilationWarnings() {
  local H
  log "Checking Vite Compilation Warnings"
  H=`grep "DevServerOutputTracker   : Failed" "$1"`
  [ -n "$H" ] && reportOutErrors "$1" "Vite Compilation Warnings"
}

## Get a specific version from the platform versions.json
## $1: platform branch (e.g., '24.5', 'main')
## $2: module name (e.g., 'flow', 'vaadin-core')
getVersionFromPlatform() {
  curl -s "https://raw.githubusercontent.com/vaadin/platform/$1/versions.json" 2>/dev/null \
      | egrep -v '^[1-4]' | tr -d "\n" |tr -d " "  | sed -e 's/^.*"'$2'":{"javaVersion"://'| cut -d '"' -f2
}

## Set version of a property with the value gotten from the versions.json
## $1: version of the platform (used to compute the branch)
## $2: module name
## $3: property name to set with the version in the pom.xml
setVersionFromPlatform() {
  local nversion VERS
  nversion=$1
  [ $nversion = current ] && return
  VERS=`getVersionFromPlatform $nversion $2`
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

## Find all pom.xml files in the project excluding target and bin directories
getPomFiles() {
  find * -name pom.xml 2>/dev/null | egrep -v 'target/|bin/'
}

## Utility method for changing Maven dependency/plugin blocks in pom.xml
## Blocks must have the structure: <tag><groupId></groupId><artifactId></artifactId><version></version>(optional_line)</tag>
## We can change groupId, artifactId, version, and optional_line
## $1: tag name (defaults to 'dependency' if empty)
## $2: groupId
## $3: artifactId
## $4: version (keep same if empty, delete if 'remove', or don't modify if version tag not present)
## $5: optional new groupId (defaults to $2)
## $6: optional new artifactId (defaults to $3)
## $7: optional extra content
changeMavenBlock() {
  local tag grp id nvers grp2 id2 file content found extra diff msg
  tag=${1:-dependency}
  grp=$2
  id=$3
  nvers=${4:-\$\{8\}}
  grp2=${5:-$grp}
  id2=${6:-$id}
  for file in `getPomFiles`
  do
    cp $file $$-1
    if [ "$4" = remove ]; then
      _cmd="perl -0777 -pi -e 's|(\s+)(<$tag>\s*<groupId>)($grp)(</groupId>\s*<artifactId>)($id)(</artifactId>)(\s*.*?)?(\s*</$tag>)||msg' $file"
      perl -0777 -pi -e 's|(\s+)(<'$tag'>\s*<groupId>)('$grp')\s*(</groupId>\s*<artifactId>)('$id')\s*(</artifactId>)(\s*.*?)?(\s*</'$tag'>)||msg' $file
    elif [ -n "$4" ]; then
      content=`cat $file`
      found=`perl -0777 -pe 's|.*<'$tag'>\s*<groupId>'$grp'</groupId>\s*<artifactId>'$id'</artifactId>\s*<version>([^<]+)</version>\s*.*?\s*</'$tag'>.*|${1}|msg' $file`
      if [ "$content" = "$found" ]; then
        extra=${7:-\$\{8\}}
        _cmd="perl -0777 -pi -e 's|(\s+)(<$tag>\s*<groupId>)($grp)(</groupId>\s*<artifactId>)($id)(</artifactId>\s*)(\s*)(.*?)?(\s*</$tag>)|\${1}\${2}'${grp2}'\${4}'${id2}'\${6}\${7}${extra}\${9}|msg' $file"
        perl -0777 -pi -e 's|(\s+)(<'$tag'>\s*<groupId>)('$grp')(</groupId>\s*<artifactId>)('$id')(</artifactId>\s*)(\s*)(.*?)?(\s*</'$tag'>)|${1}${2}'${grp2}'${4}'${id2}'${6}${7}'${extra}'${9}|msg' $file
      else
        extra=${7:-\$\{11\}}
        _cmd="perl -0777 -pi -e 's|(\s+)(<$tag>\s*<groupId>)($grp)(</groupId>\s*<artifactId>)($id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$tag>)|\${1}\${2}'${grp2}'\${4}'${id2}'\${6}\${7}${nvers}\${9}\${10}${extra}\${12}|msg' $file"
        perl -0777 -pi -e 's|(\s+)(<'$tag'>\s*<groupId>)('$grp')(</groupId>\s*<artifactId>)('$id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$tag'>)|${1}${2}'${grp2}'${4}'${id2}'${6}${7}'${nvers}'${9}${10}'${extra}'${12}|msg' $file
      fi
    else
      _cmd="perl -0777 -pi -e 's|(\s+)(<$tag>\s*<groupId>)($grp)(</groupId>\s*<artifactId>)($id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$tag>)|\${1}\${2}'${grp2}'\${4}'${id2}'\${6}\${7}${nvers}\${9}\${10}'${extra}'\${12}|msg' $file"
      perl -0777 -pi -e 's|(\s+)(<'$tag'>\s*<groupId>)('$grp')(</groupId>\s*<artifactId>)('$id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$tag'>)|${1}${2}'${grp2}'${4}'${id2}'${6}${7}'${nvers}'${9}${10}'${extra}'${12}|msg' $file
    fi
    cp $file $$-2
    diff=`diff -w $$-1 $$-2`
    if [ -n "$diff" ]; then
      [ "$4" = remove ] && msg="Remove" || msg="Change"
      [ -z "$TEST" ] && warn "$msg $tag $grp:$id $nvers"
      [ -n "$TEST" ] && cmd "## $msg Maven Block $tag $grp:$id -> $grp2:$id2:$4 $9"
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
  local H
  H=`grep "<$1>" $2 | perl -pe 's|\s*<'$1'>(.+?)</'$1'>\s*|$1|'`
  [ -n "$H" ] && echo "$H" && return 0
}

## change the content of a block in any file
## $1: left regular expression
## $2: right regular expression
## $3: new content of the block, you need to provide ${1} ${2} ${3} to use the left, old content and right groups
## $4: file
changeBlock() {
  local left right val bfile diff err
  left="$1"; right="${2:-$1}"; val="$3"; bfile="$4";
  cp $bfile $$-1
  if [ "$val" = remove ]; then
    _cmd="perl -0777 -pi -e 's|($left)(.*?)($right)||gs' $bfile"
          perl -0777 -pi -e 's|('$left')(.*?)('$right')||gs' $bfile
  else
    _cmd="perl -0777 -pi -e 's|($left)(.*?)($right)|${val}|gs' $bfile"
          perl -0777 -pi -e 's|('$left')(.*?)('$right')|'"${val}"'|gs' $bfile
  fi
  diff=`diff -w $$-1 $bfile`
  rm -f $$-1
  [ -n "$diff" ] && cmd "$_cmd" && err=0 || err=1
  [ -z "$TEST" -a -n "$diff" -a "$val" =  remove ] && warn "Remove $left in $bfile"
  [ -z "$TEST" -a -n "$diff" -a "$val" != remove ] && warn "Changed '($left)($right)' to '$val' in $bfile"
  return $err
}

## change a maven property in the pom.xml, faster than
##  mvn -q versions:set-property -Dproperty=property -DnewVersion=value
## $1: property name
## $2: value (if value is 'remove' the property is removed)
changeMavenProperty() {
  local prop val ret propfile cur
  prop=$1; val=$2; ret=0;
  for propfile in `getPomFiles`
  do
    cur=`getCurrProperty $prop $propfile`
    if [ "$val" != remove -a "$val" != "$cur" ]; then
      runCmd -f "Changing Maven property $prop from $cur -> $val in $propfile" \
        "perl -pi -e 's|(\s*<'$prop'>)[^\s]+(</'$prop'>)|\${1}${val}\${2}|g' $propfile"
      ret=$?
    elif [ "$val" = remove -a -n "$cur" ]; then
      runCmd -f "Removing Maven property $prop from $propfile" \
        "perl -pi -e 's|(\s*<'$prop'>)[^\s]+(</'$prop'>)||g' $propfile"
      ret=$?
    else
      ret=1
    fi
  done
  return $ret
}

## rename a maven property in the pom.xml
## $1: property1 name
## $2: property2 name
renameMavenProperty() {
  local prop1 prop2 ret file cur
  prop1=$1; prop2=$2; ret=1;
  for file in `getPomFiles`
  do
    cur=`getCurrProperty $prop1 $file`
    [ -z "$cur" ] && continue
    runCmd -f "Rename Maven property $prop1 -> $prop2" \
      "perl -0777 -pi -e 's|(<$prop1>[^\s]+)(/$prop1>)|<$prop2>$cur</$prop2>|g' $file"
    [ $? = 0 -a $ret = 1 ] && ret=0
  done
  return $ret
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
  local file key val cur diff
  file=$1; key=$2; val=$3
  [ ! -f "$file" ] && return 0
  cp $file $$-1
  cur=`egrep ' *'$key $file | tr ':' '=' | cut -d "=" -f2-`
  if [ "$val" = remove ]; then
    _cmd="perl -pi -e 's|\s*($key)\s*([=:]).*||g' $file"
          perl -pi -e 's|\s*('$key')\s*([=:]).*||g' $file
  elif [ -n "$cur" ]; then
    _cmd="perl -pi -e 's|\s*($key)\s*([=:]).*|\${1}\${2}${val}|g' $file"
          perl -pi -e 's|\s*('$key')\s*([=:]).*|${1}${2}'"${val}|g" $file
  else
    _cmd="echo '$key=$val' >> $file"
          echo "$key=$val" >> "$file"
  fi
  diff=`diff -w $$-1 $file`
  rm -f $$-1
  [ -z "$TEST" -a -n "$diff" -a "$val" =  remove ] && warn "Remove $key in $file"
  [ -z "$TEST" -a -n "$diff" -a "$val" != remove ] && warn "Change $key from '$cur' to '$val' in $file"
  [ -n "$diff" ] && cmd "$_cmd"
}

## Do not open Browser after app is started
disableLaunchBrowser() {
  for file in `find . -name application.properties`; do
    setPropertyInFile $file vaadin.launch-browser remove
  done
}

## pnpm is quite faster than npm
enablePnpm() {
  for file in `find . -name application.properties`; do
    setPropertyInFile $file vaadin.pnpm.enable true
  done
}

## vite is faster than webpack
enableVite() {
  for file in `find . -name application.properties`; do
    setPropertyInFile com.vaadin.experimental.viteForFrontendBuild true
  done
}

## Compute whether the headless argument must be set
isHeadless() {
  IP=`hostname -i 2>/dev/null`
  test "$HEADLESS" = true -o -z "$VERBOSE" -a "$HEADLESS" != false -o -n "$IP"
}

## print used versions of node, java and maven
printVersions() {
  local vers
  computeNpm
  [ -n "$TEST" ] && return
  vers=`MAVEN_OPTS="$MAVEN_OPTS" MAVEN_ARGS="$MAVEN_ARGS" $MVN -version | tr \\\\ / 2>/dev/null | egrep -i 'maven|java'`
  [ $? != 0 ] && err "Error $? when running $MVN, $vers" && return 1
  log "==== VERSIONS ====

MAVEN_OPTS='$MAVEN_OPTS' MAVEN_ARGS='$MAVEN_ARGS' $MVN -version
$vers
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
  local U R cmd
  U="$1"
  grep -q "$U" pom.xml && return 0
  for R in repositor pluginRepositor; do
    if ! grep -q $R'ies>' pom.xml; then
      cmd="perl -pi -e 's|(\s*)(</project>)|\$1\$1<${R}ies><${R}y><id>v</id><url>${U}</url></${R}y></${R}ies>\n\$1\$2|' pom.xml"
    else
      cmd="perl -pi -e 's|(\s*)(<${R}ies>)|\$1\$2\n\$1\$1<${R}y><id>v</id><url>${U}</url></${R}y>|' pom.xml"
    fi
    runCmd -f "Adding $U repository to pom.xml" "$cmd"
  done
}

## Adds a maven dep in the block </dependencies> previous to </build>
## $1 pom.xml file
## $2 groupId
## $3 artifactId
## $4 scope
## $5 extra content e.g. <version>nnn</version>
addMavenDep() {
  local POM=$1; local GI=$2; local AI=$3; local SC=$4; local EX="$5"
  local t='    '
  [ -z "$POM" ] && POM=pom.xml
  __cmd="perl -0777 -pi -e 's|(\n[ \t]*)(</dependencies>\s+(<build>\|<repo\|<dependencyM\|<!))|\$1$t<dependency>\$1$t$t<groupId>${GI}</groupId>\$1$t$t<artifactId>${AI}</artifactId>\$1$t$t<scope>${SC}</scope>${EX}\$1$t</dependency>\$1\$2|' $POM"
  runCmd -f "Adding dependency $GI $AI $SC to pom.xml" "$__cmd"
}

## Add extr repo to gradle files
## $1: repo url
addRepoToGradle() {
  local U REPO_FORMAT BUILD_REPO_FORMAT H
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
  local file
  for file in `getPomFiles`
  do
    changeBlock '<snapshots>\s+<enabled>' '</enabled>\s+</snapshots>' '${1}true${3}'  $file
  done
}

## Downloads a file from the internet
## $1: the URL
download() {
  local S O
  [ -z "$VERBOSE" ] && S="-s"
  [ -n "$2" -a "$2" != '-' ] && O="-o $2"
  runCmd -f "Downloading $1" "curl $S -L $O $1"
}

## Installs jet brains java runtime, used for testing the hotswap agent
## It updates JAVA_HOME and PATH variables, and sets the HOT one with the parameters to enable it.
installJBRRuntime() {
  local hvers jvers vers hsau jurl H
  # https://github.com/HotswapProjects/HotswapAgent/releases/
  hvers="2.0.1"
  # https://github.com/JetBrains/JetBrainsRuntime/releases
  jvers="21.0.5"
  vers="b631.16"

  hsau="https://github.com/HotswapProjects/HotswapAgent/releases/download/RELEASE-${hvers}/hotswap-agent-${hvers}.jar"
  jurl="https://cache-redirector.jetbrains.com/intellij-jbr"

  [ -z "$TEST" ] && warn "Installing JBR for hotswap testing"

  isLinux   && jurl="$jurl/jbr-${jvers}-linux-x64-${vers}.tar.gz"
  isMac     && jurl="$jurl/jbr-${jvers}-osx-x64-${vers}.tar.gz"
  isWindows && jurl="$jurl/jbr-${jvers}-windows-x64-${vers}.tar.gz"
  if [ ! -f /tmp/JBR.tgz ]; then
    download "$jurl" "/tmp/JBR.tgz" || return 1
  fi
  if [ ! -d /tmp/jbr ]; then
    mkdir -p /tmp/jbr
    runCmd -f "Extracting JBR" "tar -xf /tmp/JBR.tgz -C /tmp/jbr --strip-components 1" || return 1
  fi
  setJavaPath "/tmp/jbr" || return 1
  if [ ! -f $JAVA_HOME/lib/hotswap/hotswap-agent.jar ] ; then
    mkdir -p $JAVA_HOME/lib/hotswap
    download "$hsau" "$H/lib/hotswap/hotswap-agent.jar" || return 1
    [ -z "$TEST" ] && log "Installed "`ls -1 $H/lib/hotswap/hotswap-agent.jar`
  fi
  export HOT="-Djetty.deployMode=FORK -Djetty.jvmArgs=-XX:HotswapAgent=fatjar"
}

## Installs a certain version of OPENJDK
# $1: version (eg: 17, 21, 23)
installJDKRuntime() {
  local version base_url os_suffix ext nversion vpath tar_file tmp_dir jurl
  version=$1
  base_url="https://download.oracle.com/java"
  isLinux && os_suffix="linux-x64" && ext="tar.gz"
  isMac && os_suffix="macos-x64" && ext="tar.gz"
  isWindows && os_suffix="windows-x64" && ext="zip"
  [ -z "$version" -o -z "$os_suffix" ] && return 1
  nversion="$version"
  vpath="latest"
  [ "$version" = "18" ] && nversion="18.0.1" && vpath="archive"
  [ "$version" = "17" ] && nversion="17.0.12" && vpath="archive"
  tar_file="jdk-${nversion}_${os_suffix}_bin.${ext}"
  tmp_dir="/tmp/jdk-${version}"
  jurl="${base_url}/${version}/${vpath}/${tar_file}"
  if [ ! -f "/tmp/$tar_file" ]; then
    download "$jurl" "/tmp/$tar_file" || return 1
  fi
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  runCmd -f "Extracting JDK-$version" "tar -xf "/tmp/$tar_file" -C "$tmp_dir" --strip-components 1" || return 1

  setJavaPath "$tmp_dir" || return 1
}

setJavaPath() {
  local H
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
  local p
  p=src/main/resources/hotswap-agent.properties
  mkdir -p `dirname $p` && echo "autoHotswap=true" > "$p"
  [ -z "$TEST" ] && warn "Disabled Jetty autoreload"
  changeMavenProperty scan -1
}

## displays secs in mins:secs
## $1: seconds
secsToString() {
  local mins secs
  mins=`expr $1 / 60`
  secs=`expr $1 % 60`
  printf "%.2d':%.2d\"" $mins $secs
}

## computes elapsed time
## $1: the starttime in `date +%s`, otherwise the time since the script was run
computeTime() {
  local start end
  start=${1:-$START}
  end=`date +%s`
  secsToString `expr $end - $start`
}

## prints elapsed time
## $1: the starttime in `date +%s`, otherwise the time since the script was run
printTime() {
  local H
  H=`computeTime $1`
  echo ""
  log "Elapsed Time: $H\""
}

## update Gradle to the version provided in $1
upgradeGradle() {
  local V
  [ -z "$1" ] && return
  V=`$GRADLE --version | grep '^Gradle' | awk '{print $2}'`
  expr "$V" : "$1" >/dev/null && return
  runCmd -f "Upgrading Gradle from $V to $1" "$GRADLE wrapper -q --gradle-version $1"
}

## list all demos that are available in the vaadin website (examples and starters)
getReposFromWebsite() {
  local demos starters
  demos=`curl -s https://vaadin.com/examples-and-demos  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  starters=`curl -s https://vaadin.com/hello-world-starters  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  printf "$demos\n$starters" | sort -u
}

## clean vaadin artifact from local maven repository with the version provided
cleanM2() {
  [ -n "$OFFLINE" -o -z "$1" -o ! -d ""`ls -1d ~/.m2/repository/com/vaadin/*/$1 2>/dev/null | head -1` ] && return
  warn "removing ~/.m2/repository/com/vaadin/*/$1"
  rm -rf ~/.m2/repository/com/vaadin/*/$1
}

## compute the latest version of hilla depending on the platform or hilla version provided in $1
getLatestHillaVersion() {
  local G
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
  local JavaMajor
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
  local newVers curVers
  # expr "$3" : ".*SNAPSHOT" >/dev/null && newVers=$3 || newVers=$3
  newVers=$3
  curVers=`getMvnDependencyVersion "$1" "$2" "$4"` || return 1
  if [ "$curVers" != "$newVers" ]; then
    changeBlock '<artifactId>'$2'</artifactId>' '\s+</dependency>' '${1}<version>'$newVers'</version>${3}' pom.xml
    curVers=`getMvnDependencyVersion "$1" "$2" "$4"` || return 1
    [ "$curVers" != "$newVers" ] && err "CC version mismatch $curVers != $newVers" && return 1
  fi
  log "App is using $1:$2:$curVers"
  return 0
}

validateToken() {
  local H
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
  local i v
  for i in `getPomFiles`; do
    v=`grep '</java.version>' pom.xml  | sed -e 's|[^0-9]||g'`
    [ -z "$v" -o "$v" = "$1" ] && return
    cmd "perl -pi -e 's|<java.version>\d+</java.version>|<java.version>'$1'</java.version>|' $i"
    perl -pi -e 's|<java.version>\d+</java.version>|<java.version>'$1'</java.version>|' $i
    [ -n "$TEST" ] || warn "Changed Java version from $v to $1 in $i"
  done
}
