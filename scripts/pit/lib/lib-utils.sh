isLinux() {
  test `uname` = Linux
}
isMac() {
  test `uname` = Darwin
}
isWindows() {
  ! isLinux && ! isMac
}

## Remove pro-key for testing core-only apps
removeProKey() {
  if [ -f ~/.vaadin/proKey ]; then
    _cmd="mv ~/.vaadin/proKey ~/.vaadin/proKey-$$"
    [ -z "$TEST" ] && warn "Removing proKey license"
    cmd "$_cmd"
    [ -n "$TEST" ] && return 0
    eval $_cmd
  fi
}
## Restore pro-key removed in previous function
restoreProKey() {
  [ ! -f ~/.vaadin/proKey-$$ ] && return
  H=`cat ~/.vaadin/proKey 2>/dev/null`
  _cmd="mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey"
  [ -z "$TEST" ] && warn "Restoring proKey license"
  cmd "$_cmd"
  eval $_cmd
  [ -n "$TEST" ] && return 0
  [ -n "$H" ] && reportError "A proKey was generated while running validation" "$H" && return 1
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
cleanAll() {
  restoreProKey
  unsetJBR
}

## Exit the script after some process cleanup
doExit() {
  echo ""
  killAll
  cleanAll
  exit
}

## print wrapper for coloring outputs
print() {
  printf "\033[0m$1\033[$2;$3m$4\033[0m\n" >&2
}

## log with some nice color
log() {
  print '> ' 0 32 "$*"
}
bold() {
  print '> ' 1 32 "$*"
}
err() {
  print '> ' 0 31 "$*"
}
warn() {
  print '> ' 0 33 "$*"
}
cmd() {
  cmd_=`echo "$*"`
  print '  ' 1 34 " $cmd_"
}
dim() {
  print '' 0 36 "$*"
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
  cat << EOF >> $GITHUB_STEP_SUMMARY
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
  H=`cat "$1" | egrep -v ' *at |org.atmosphere.cpr.AtmosphereFramework' | tail -300`
  reportError "$2" "$H"
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
## Compute the maven command to use for the project and stores in MVN env variable
computeMvn() {
  [ -f ./mvnw ] && MVN=./mvnw
  isWindows && [ -f ./mvnw.cmd ] && MVN=./mvnw.cmd
}

## Compute the gradle command to use for the project and stores in GRADLE env variable
computeGradle() {
  [ -f ./gradlew ] && GRADLE=./gradlew
  isWindows && [ -f ./gradlew.cmd ] && GRADLE=./gradlew.cmd
}

## Compute npm command used for installing playwright
computeNpm() {
  _VNODE=~/.vaadin/node
  _NPMJS=$_VNODE/lib/node_modules/npm/bin/npm-cli.js
  NPM=`which npm`
  NPX=`which npx`
  NODE=`which node`
  [ -x $_VNODE/bin/node -a -f $_NPMJS ] && export PATH=$_VNODE/bin:$PATH && NODE=$_VNODE/bin/node && NPM="$NODE $_NPMJS"
}

## Run a command and outputs its stdout/stderr to a file
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
      eval "$__cmd" >> $__file 2>&1
      err=$?
    else
      eval "$__cmd" >> $__file
      err=$?
    fi
  else
    eval "$__cmd" 2>&1 | tee -a $__file
    err=$?
  fi
  [ $err != 0 ] && reportOutErrors "$__file" "Error ($err) running $__cmd" && return 1 || return 0
}

## Run a process silently in background sending its output to a file
runInBackgroundToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  [ -z "$TEST" ] && log "Running in background and sending output to > $__file"
  expr "$1" : ".*mvn " >/dev/null && E=" $MAVEN_ARGS" || E=""
  cmd "$__cmd $E"
  [ -n "$TEST" ] && return
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
  [ -n "$TEST" ] && cmd "## Wait for: '$__message'" || log "Waiting for server to start, timeout=$__timeout secs, message='$__message'"
  [ -n "$TEST" ] && return 0
  while [ $__timeout -gt 0 ]
  do
    kill -0 $pid_run 2>/dev/null
    if [ $? != 0 ]
    then
      if grep -q "'tsconfig.json' has been updated" $__ofile; then
        H=`git diff tsconfig.json`
        echo ">>>> PiT: tsconfig.json modified, retrying ...." >> $__ofile && reportOutErrors "File 'tsconfig.json' was modified and servlet threw an Exception" "$H" && return 2
      else
        reportOutErrors "$__file" "Error $__cmd failed to start" && return 1
      fi
    fi
    __lasted=`expr $3 - $__timeout`
    __perl="perl -pe 's~^.*($__message.*)~\$1~g'"
    egrep -q "$__message" $__file  \
      && H=`egrep "$__message" $__file | eval "$__perl" | head -1` \
      && log "Found '$H' in $__file after $__lasted secs" \
      && echo ">>>> PiT: Found '$H' after $__lasted secs" >> $__file \
      && sleep 3 && return 0
    sleep 10 && __timeout=`expr $__timeout - 2`
  done
  reportOutErrors "$__file"  "Error could not find '$__message' in $__file after $__timeout secs"
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
  isWindows && sleep 4 || sleep 2
  kill $pid_curl 2>/dev/null || return 1
}

## Wait until port is listening
waitUntilPort() {
  log "Waiting for port $1 to be available"
  __i=1
  while true; do
    checkPort $1 && echo ">>>> PiT: Checked that port $1 is listening" >> $3 && return 0
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
checkHttpServlet() {
  __url="$1"
  __ofile="$2"
  __cfile="curl-"`uname`".out"
  [ -n "$TEST" ] && return 0
  rm -f $__cfile
  log "Checking whether url $__url returns HTTP 200"
  runToFile "curl -s --fail -I -L -H Accept:text/html $__url" "$__cfile" "$VERBOSE"
  [ $? != 0 ] && reportOutErrors "$__ofile" "Server Logs" && return 1 || return 0
}

## Hits an HTTP server until vaadin finishes to compile the frontend in dev-mode
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
       if egrep -q 'The TypeScript type declaration file .* has been updated' $__ofile; then
         [ -f tsconfig.json ] && _diff=`git diff tsconfig.json`
         [ -f types.d.ts ] && _diff="$_diff"`git diff types.d.ts`
         echo ">>>> PiT: config file modified, retrying ...." >> $__ofile && reportOutErrors "$__ofile" "File config was modified and servlet threw an Exception" "$_diff"
         return 2
       else
         echo ">>>> PiT: Found Error when compiling frontend" >> $__ofile && reportOutErrors "$__ofile" "Error ($__err) checking dev-mode"
         return 1
       fi
    fi
    if echo "$H" | grep -q "X-DevModePending"; then
      sleep 3
      __time=`expr $__time + 3`
    else
      echo ">>>> PiT: Checked that frontend is compiled and dev-mode is ready after $__time secs" >> $__ofile
      log "Found a valid response after $__time secs"
      return
    fi
  done
}

## Set the value of a property in the pom file, returning error if unchanged
setVersion() {
  __prop=$1
  __nversion=$2
  [ "false" != "$3" ] && git checkout -q .
  [ "$__nversion" = current ] && getCurrProperty $__prop pom.xml && return 1
  changeMavenProperty $__prop $__nversion && echo $__nversion
}

getGradleVersion() {
  if [ -f "gradle.properties" ]; then
    cat gradle.properties | grep "$1" | cut -d "=" -f2
  elif [ -f "build.gradle" ]; then
    cat build.gradle  | egrep 'set.*'$1 | perl -p -e 's/^.*"(\d[^"]+).*$/$1/'
  fi
}

## Set the value of a property in the gradle.properties file, returning error if unchanged
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
    perl -pi -e 's/^(.*set.*'$__gradleProperty'.*?)(\d[^"]+)(.*)$/${1}'$__nversion'${3}/g' build.gradle
  fi
}

## checks whether an express dev-bundle has been created for the project
checkBundleNotCreated() {
  log "Checking Express Bundle"
  if grep -q "mode bundle build is needed" "$1"; then
    reportOutErrors "$1" "Default vaadin-dev-bundle is not used"
    return 1
  fi
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
  B=`echo $__nversion | cut -d . -f1,2`
  VERS=`getVersionFromPlatform $B $2`
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
## $5: new groupId (keep the same if empty)
## $6: new artifactId (keep the same if empty)
## $7: extra block after version tag until the end of the tag block (keep the same if empty)
changeMavenBlock() {
  __tag=${1:-dependency}
  __grp=$2
  __id=$3
  __nvers=${4:-\$8}
  __grp2=${5:-$__grp}
  __id2=${6:-$__id}
  __extra=${7:-\$11}
  for __file in `getPomFiles`
  do
    cp $__file $$-1
    if [ "$4" = remove ]; then
      [ -n "$TEST" ] && cmd "## Remove $__file $__tag $__grp:$__id"
      _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>)(\s*.*?)?(\s*</$__tag>)||msg' $__file"
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>)(\s*.*?)?(\s*</'$__tag'>)||msg' $__file
    elif [ -n "$4" ]; then
      __content=`cat $__file`
      __found=`perl -0777 -pe 's|.*<'$__tag'>\s*<groupId>'$__grp'</groupId>\s*<artifactId>'$__id'</artifactId>\s*<version>([^<]+)</version>\s*.*?\s*</'$__tag'>.*|${1}|msg' $__file`
      if [ "$__content" = "$__found" ]; then
        __extra=${7:-\$8}
        _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}'${__extra}'\${9}|msg' $__file"
        perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__extra}'${9}|msg' $__file
      else
        _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}'${__nvers}'\${9}\${10}'${__extra}'\${12}|msg' $__file"
        perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__nvers}'${9}${10}'${__extra}'${12}|msg' $__file
      fi
    else
      _cmd="perl -0777 -pi -e 's|(\s+)(<$__tag>\s*<groupId>)($__grp)(</groupId>\s*<artifactId>)($__id)(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</$__tag>)|\${1}\${2}'${__grp2}'\${4}'${__id2}'\${6}\${7}'${__nvers}'\${9}\${10}'${__extra}'\${12}|msg' $__file"
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'${__grp2}'${4}'${__id2}'${6}${7}'${__nvers}'${9}${10}'${__extra}'${12}|msg' $__file
    fi
    cp $__file $$-2
    __diff=`diff -w $$-1 $$-2`
    [ -z "$TEST" -a -n "$__diff" -a "$4" =  remove ] && warn "Removed $__file $__tag $__grp:$__id"
    [ -z "$TEST" -a -n "$__diff" -a "$4" != remove ] && warn "Changed $__file $__tag $__grp:$__id -> $__grp2:$__id2:$4 $9"
    [ -n "$TEST" -a -n "$__diff" ] && cmd "## Changed Maven Block $__tag $__grp:$__id -> $__grp2:$__id2:$4 $9"
    [ -n "$__diff" ] && cmd "$_cmd"
    rm -f $$-1 $$-2
  done
}

## Reads a property from a pom file, it's faster than
##   mvn help:evaluate -Dexpression=property -q -DforceStdout
## $1: property name
## $2: pom.xml file to read
getCurrProperty() {
  for __file in `find * -name $2 2>/dev/null | egrep -v 'target/|bin/'`
  do
    H=`grep "<$1>" $__file | perl -pe 's|\s*<'$1'>(.+?)</'$1'>\s*|$1|'`
    [ -n "$H" ] && echo "$H" && return 0
  done
}

## change the content of a block in any file
## $1: left regular expression
## $2: right regular expression
## $3: new content of the block
## $4: file
changeBlock() {
  __left="$1"; __right="${2:-$1}"; __val="$3"; __file="$4";
  cp $__file $$-1
  if [ "$__val" = remove ]; then
    _cmd="perl -0777 -pi -e 's|\s*($__left)([^\s]+)($__right>)\s*||g' $__file"
          perl -0777 -pi -e 's|\s*('$__left')([^\s]+)('$__right')\s*||g' $__file
  else
    _cmd="perl -0777 -pi -e 's|($__left)([^\s]+)($__right)|\${1}${__val}\${3}|g' $__file"
          perl -0777 -pi -e 's|('$__left')([^\s]+)('$__right')|${1}'"${__val}"'${3}|g' $__file
  fi
  __diff=`diff -w $$-1 $__file`
  rm -f $$-1
  [ -n "$__diff" ] && cmd "$_cmd" && __err=0 || __err=1
  [ -z "$TEST" -a -n "$__diff" -a "$__val" =  remove ] && warn "Remove $__left in $__file"
  [ -z "$TEST" -a -n "$__diff" -a "$__val" != remove ] && warn "Changed '$__left' to '$__val' in $__file"
  return $__err
}

## change a maven property in the pom.xml, faster than
##  mvn -q versions:set-property -Dproperty=property -DnewVersion=value
## $1: property name
## $2: value (if value is 'remove' the property is removed)
changeMavenProperty() {
  __prop=$1; __val=$2; __ret=1;
  for __file in `getPomFiles`
  do
    if [ "$__val" != remove ]; then
      __cur=`getCurrProperty $__prop $__file`
      [ -z "$__cur" ] && continue
    fi
    [ -n "$TEST" ] && cmd "## Change Maven property $__prop from $__cur -> $__val"
    changeBlock "<$__prop>" "</$__prop>" "$__val" $__file
    [ $? = 0 -a $__ret = 1 ] && __ret=0
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
    __cur=`getCurrProperty $__prop $__file`
    [ -z "$__cur" ] && continue
    [ -n "$TEST" ] && cmd "## Rename Maven property $__prop1 -> $__prop2"
    cmd "perl -0777 -pi -e 's|(<$__prop1>[^\s]+)(/$__prop1>)|<$__prop2>$__cur</$__prop2>|g' $__file"
         perl -0777 -pi -e 's|(<'$__prop1'>[^\s]+)(/'$__prop1'>)|<'$__prop2'>'$__cur'</'$__prop2'>|g' $__file
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

setPropertyInFile() {
  __file=$1; __key=$2; __val=$3
  [ ! -f "$__file" ] && return 0
  cp $__file $$-1
  __cur=`egrep ' *'$__key $__file | tr ':' '=' | cut -d "=" -f2`
  if [ "$__val" = remove ]; then
    _cmd="perl -pi -e 's|\s*($__key)\s*([=:]).*||g' $__file"
          perl -pi -e 's|\s*('$__key')\s*([=:]).*||g' $__file
  elif [ -n "$__cur" ]; then
    _cmd="perl -pi -e 's|\s*($__key)\s*([=:]).*|\${1}\${2}${__val}|g' $__file"
          perl -pi -e 's|\s*('$__key')\s*([=:]).*|${1}${2}'"${__val}|g" $__file
  else
    _cmd="echo '$__key=$__val' >> $__file"
          echo "$__key=$__val" >> $__file
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
  test -z "$VERBOSE" -o -n "$IP"
}

## print used versions of node, java and maven
printVersions() {
  computeNpm
  [ -n "$TEST" ] && return
  _vers=`MAVEN_OPTS="$HOT" MAVEN_ARGS="$MAVEN_ARGS" $MVN -version | tr \\\\ / 2>/dev/null | egrep -i 'maven|java|agent.HotswapAgent'`
  [ $? != 0 ] && err "Error $? when running $MVN, $_vers" && return 1
  log "==== VERSIONS ====

MAVEN_OPTS='$MAVEN_OPTS' MAVEN_ARGS='$MAVEN_ARGS' $MVN -version
$_vers
Node version: `$NODE --version`
Npm version: `$NPM --version`
"
}

## adds extr repo to the pom.xml
addRepoToPom() {
  [ ! -f pom.xml ] && ([ -n "$TEST" ] || log "Not a Maven proyect, not adding prereleases repository") && return 0
  U="$1"
  grep -q "$U" pom.xml && return 0
  [ -z "$TEST" ] && log "Adding $U repository"
  for R in repositor pluginRepositor; do
    if ! grep -q $R'ies>' pom.xml; then
      cmd "perl -pi -e 's|(\s*)(</properties>)|\$1\$2\\\n\$1<${R}ies><${R}y><id>v</id><url>${U}</url></${R}y></${R}ies>|' pom.xml"
           perl -pi -e 's|(\s*)(</properties>)|$1$2\n$1<'$R'ies><'$R'y><id>v</id><url>'$U'</url></'$R'y></'$R'ies>|' pom.xml
    else
      cmd "perl -pi -e 's|(\s*)(<${R}ies>)|\$1\$2\\\n\$1\$1<${R}y><id>v</id><url>${U}</url></${R}y>|' pom.xml"
      perl -pi -e 's|(\s*)(<'$R'ies>)|$1$2\n$1$1<'$R'y><id>v</id><url>'$U'</url></'$R'y>|' pom.xml
    fi
  done
}

## adds the pre-releases repositories to the pom.xml
addPrereleases() {
  addRepoToPom "https://maven.vaadin.com/vaadin-prereleases"
}

# adds spring pre-releases repo to pom.xml
addSpringReleaseRepo() {
  addRepoToPom "https://repo.spring.io/milestone/"
}

## enables snapshots for the pre-releases repositories in pom.xml
enableSnapshots() {
  for __file in `getPomFiles`
  do
    changeBlock '<snapshots>\s+<enabled>' '</enabled>\s+</snapshots>' 'true' $__file
  done
}

## runs a command, and shows a message explaining it
## $1: message to show
## $*: command line order and arguments
runCmd() {
  [ -z "$2" ] && echo "bad arguments to runCmd" && return 1
  [ -n "$1" ] && log "$1"
  shift
  _cmd="${*}"
  cmd "$_cmd"
  eval $_cmd
}

## Downloads a file from the internet
## $1: the URL
download() {
  [ -z "$VERBOSE" ] && __S="-s"
  [ -n "$2" ] && __O="-o $2"
  runCmd "Downloading $1" "curl $__S -L $__O $1"
}

## Installs jet brains java runtime, used for testing the hotswap agent
## It updates JAVA_HOME and PATH variables, and sets the HOT one with the parameters to enable it.
installJBRRuntime() {
  __hsau="https://github.com/HotswapProjects/HotswapAgent/releases/download/1.4.2-SNAPSHOT/hotswap-agent-1.4.2-SNAPSHOT.jar"
  __jurl="https://cache-redirector.jetbrains.com/intellij-jbr"
  __vers="b653.32"
  warn "Installing JBR for hotswap testing"

  isLinux   && __jurl="$__jurl/jbr-17.0.6-linux-x64-${__vers}.tar.gz"
  isMac     && __jurl="$__jurl/jbr-17.0.6-osx-x64-${__vers}.tar.gz"
  isWindows && __jurl="$__jurl/jbr-17.0.6-windows-x64-${__vers}.tar.gz"
  if [ ! -f /tmp/JBR.tgz ]; then
    download "$__jurl" "/tmp/JBR.tgz" || return 1
  fi
  if [ ! -d /tmp/jbr ]; then
    mkdir -p /tmp/jbr
    runCmd "Extracting JBR" "tar -xf /tmp/JBR.tgz -C /tmp/jbr --strip-components 1" || return 1
  fi

  [ -d /tmp/jbr/Contents/Home/ ] && H=/tmp/jbr/Contents/Home || H=/tmp/jbr
  [ -z "$TEST" ] && log "Setting JAVA_HOME=$H PATH=$H/bin:\$PATH"
  cmd "export PATH=$H/bin:\$PATH JAVA_HOME=$H"
  __PATH=$PATH
  __HOME=$JAVA_HOME
  export PATH="$H/bin:$PATH" JAVA_HOME="$H" HOT="-XX:+AllowEnhancedClassRedefinition -XX:HotswapAgent=fatjar"


  if [ ! -f $H/lib/hotswap/hotswap-agent.jar ] ; then
    mkdir -p $H/lib/hotswap
    download "$__hsau" "$H/lib/hotswap/hotswap-agent.jar" || return 1
    log "Installed "`ls -1 $H/lib/hotswap/hotswap-agent.jar`
  fi
}

unsetJBR() {
  [ -z "$HOT" ] && return 0 || unset HOT
  warn "Un-setting PATH and JAVA_HOME ($JAVA_HOME)"
  [ -n "$__PATH" ] && export PATH=$__PATH && unset __PATH
  [ -n "$__HOME" ] && export JAVA_HOME=$__HOME && unset __HOME || unset JAVA_HOME
}

## enables autoreload for preparing jet brains java runtime
## it modifies jetty in pom.xml and configures the hotswap-agent.properties
enableJBRAutoreload() {
  _p=src/main/resources/hotswap-agent.properties
  mkdir -p `dirname $_p` && echo "autoHotswap=true" > $_p
  [ -z "$TEST" ] && warn "Disabled Jetty autoreload"
  changeMavenProperty scan -1
}

## prints ellapsed time
## $1: if not empty it stablishes the start time and returns, if empty it logs the ellapsed time
printTime() {
  [ -n "$1" ] && _start=$1 || return
  __end=`date +%s`
  __time=`expr $__end - $_start`
  __mins=`expr $__time / 60`
  __secs=`expr $__time % 60`
  echo ""
  log "Total time: $__mins' $__secs\""
}

upgradeGradle() {
  V=`$GRADLE --version | grep '^Gradle' | awk '{print $2}'`
  expr "$V" : "$1" >/dev/null && return
  warn "Upgrading Gradle Wrapper from $V to $1"
  cmd "$GRADLE wrapper -q --gradle-version $1"
  $GRADLE wrapper -q --gradle-version $1
}

getReposFromWebsite() {
  _demos=`curl -s https://vaadin.com/examples-and-demos  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  _starters=`curl -s https://vaadin.com/hello-world-starters  | grep div | grep github.com/vaadin | perl -pe 's|(^.*)/github.com/vaadin/([\w\-]+).*|$2|g' | sort -u`
  printf "$_demos\n$_starters" | sort -u
}

cleanM2() {
  [ -n "$OFFLINE" -o -z "$1" -o ! -d ""`ls -1d ~/.m2/repository/com/vaadin/*/24.2.0.alpha6 2>/dev/null | head -1` ] && return
  warn "removing ~/.m2/repository/com/vaadin/*/$1"
  rm -rf ~/.m2/repository/com/vaadin/*/$1
}

getLatestHillaVersion() {
  case "$1" in
    2.*)    echo "$1" && return ;;
    24.[012].*) G="2.4.[09]*";;
    24.3[.-]*) G="2.5.*";;
    24.4[.-]*) G="24.4.*";;
    # When hilla 3.0 starts to be released, we can use this
    # 24.4-SNAPSHOT) echo "3.0-SNAPSHOT";;
    # 24.4.*) G="3.0.*";;
  esac
  curl -s https://api.github.com/repos/vaadin/hilla/releases | jq -r '.[].tag_name' | egrep "^$G$" | head -1
}

computeVersion() {
  [ "$2" = current ] && echo "$2" && return
  case $1 in
    *hilla*) getLatestHillaVersion "$2";;
    *) echo "$2";;
  esac
}
computeProp() {
  case $1 in
    *hilla*gradle) echo "hillaVersion";;
    *gradle) echo "vaadinVersion";;
    *typescript*|*hilla*|*react*|*-lit*) echo "hilla.version";;
    *) echo "vaadin.version";;
  esac
}
