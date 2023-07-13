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
  [ -f ~/.vaadin/proKey ] && mv ~/.vaadin/proKey ~/.vaadin/proKey-$$ && warn "Removed proKey license"
}
## Restore pro-key removed in previous function
restoreProKey() {
  [ ! -f ~/.vaadin/proKey-$$ ] && return
  H=`cat ~/.vaadin/proKey 2>/dev/null`
  mv ~/.vaadin/proKey-$$ ~/.vaadin/proKey
  [ -n "$H" ] && reportError "A proKey was generated while running validation" "$H" && return 1
  warn "Restored proKey license"
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

## Exit the script after some process cleanup
doExit() {
  echo ""
  restoreProKey
  killAll
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
  cat << EOF >> $GITHUB_STEP_SUMMARY
<details>
<summary><h4>$__head</h4></summary>
<pre>
`echo "$*"`
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
  NODE=`which node`
  [ -x $_VNODE/bin/node -a -f $_NPMJS ] && export PATH=$_VNODE/bin:$PATH && NODE=$_VNODE/bin/node && NPM="$NODE $_NPMJS"
}

## Run a command and outputs its stdout/stderr to a file
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
  [ $err != 0 ] && reportOutErrors "$__file" "Error ($err) running $__cmd" && return 1 || return 0
}

## Run a process silently in background sending its output to a file
runInBackgroundToFile() {
  __cmd="$1"
  __file="$2"
  __verbose="$3"
  log "Running in background and sending output to > $__file"
  [ -n "$MAVEN_OPTS" ] && cmd "MAVEN_OPTS='$MAVEN_OPTS' $__cmd" || cmd "$__cmd"
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
      reportOutErrors "$__file" "Error $__cmd failed to start"
      return 1
    fi
    __lasted=`expr $3 - $__timeout`
    egrep -q "$__message" $__file  \
      && log "Found '$__message' in $__file after $__lasted secs" \
      && egrep "$__message" $__file \
      && echo ">>>> PiT: Found '$__message' after $__lasted secs" >> $__file \
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
  rm -f $__cfile
  log "Checking whether url $__url returns HTTP 200"
  runToFile "curl -s --fail -I -L -H Accept:text/html $__url" "$__cfile" "$VERBOSE"
  [ $? != 0 ] && reportOutErrors "$__ofile" "Server Logs" && return 1 || return 0
}

## Hits an HTTP server until vaadin finishes to compile the frontend in dev-mode
waitUntilFrontendCompiled() {
  __url="$1"
  __ofile="$2"
  log "Waiting for dev-mode to be ready at $__url"
  __time=0
  while true; do
    H=`curl --retry 4 --retry-all-errors -f -s -v $__url -L -H Accept:text/html -o /dev/null 2>&1`
    __err=$?
    if [ $__err != 0 ]; then
       if grep -q "'tsconfig.json' has been updated" $__ofile; then
         H=`git diff tsconfig.json`
         echo ">>>> PiT: tsconfig.json modified, retrying ...." >> $__ofile && reportOutErrors "File 'tsconfig.json' was modified and servlet threw an Exception" "$H" && return 2
       else
         echo ">>>> PiT: Found Error when compiling frontend" >> $__ofile && reportOutErrors "$__ofile" "Error ($__err) checking dev-mode" && return 1
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
  for __pom in `find . -name pom.xml`; do
    __current=`getCurrProperty $__prop $__pom`
    case $__nversion in
      current|$__current) echo $__current; return 1 ;;
    esac
    changeMavenProperty $__prop $__nversion
  done
}

## Set the value of a property in the gradle.properties file, returning error if unchanged
setGradleVersion() {
  __gradleProperty=$1
  __nversion=$2
  [ "false" != "$3" ] && git checkout -q .
  __current=`cat gradle.properties | grep "$__gradleProperty" | cut -d "=" -f2`
  case $__nversion in
    current|$__current)
      echo $__current;
      return 1;;
    *) setPropertyInFile gradle.properties $__gradleProperty $__nversion;;
  esac
}

## checks whether an express dev-bundle has been created for the project
checkBundleNotCreated() {
  log "Checking Express Bundle"
  if grep -q "An express mode bundle build is needed" "$1"; then
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

## an utility method for changing blocks in maven, they need to have the structure
## <tag><groupId></groupId><artifactId></artifactId><version></version>(optional_line)</tag>
## we can change groupId, artifactId, version, and optional_line
## $1: tag (dependency if empty)
## $2: groupId
## $3: artifactId
## $4: version (keep the same if empty, or delete if 'remove' value is provided)
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
  for __file in `find * -name pom.xml 2>/dev/null`
  do
    cp $__file $$-1
    if [ "$4" = remove ]; then
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>)(\s*.*?)?(\s*</'$__tag'>)||msg' $__file
    elif [ -n "$4" ]; then
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'"${__grp2}"'${4}'"${__id2}"'${6}${7}'"${__nvers}"'${9}${10}'"${__extra}"'${12}|msg' $__file
    else
      perl -0777 -pi -e 's|(\s+)(<'$__tag'>\s*<groupId>)('$__grp')(</groupId>\s*<artifactId>)('$__id')(</artifactId>\s*)(?:(<version>)([^<]+)(</version>))?(\s*)(.*?)?(\s*</'$__tag'>)|${1}${2}'"${__grp2}"'${4}'"${__id2}"'${6}${7}'"${__nvers}"'${9}${10}'"${__extra}"'${12}|msg' $__file
    fi
    cp $__file $$-2
    __diff=`diff -w $$-1 $$-2`
    [ -n "$__diff" -a "$4" =  remove ] && warn "Removed $__file $__tag $__grp:$__id"
    [ -n "$__diff" -a "$4" != remove ] && warn "Changed $__file $__tag $__grp:$__id -> $__grp2:$__id2:$4 $9"
    rm -f $$-1 $$-2
  done
}

## Reads a property from a pom file, it's faster than
##   mvn help:evaluate -Dexpression=property -q -DforceStdout
## $1: property name
## $2: pom.xml file to read
getCurrProperty() {
  grep "<$1>" $2 | perl -pe 's|\s*<'$1'>(.+?)</'$1'>\s*|$1|'
}

## change a maven property in the pom.xml, faster than
##  mvn -q versions:set-property -Dproperty=property -DnewVersion=value
## $1: property name
## $2: value
changeMavenProperty() {
  __prop=$1; __val=$2; __ret=1
  for __file in `find * -name pom.xml 2>/dev/null`
  do
    cp $__file $$-1
    if [ "$__val" = remove ]; then
      perl -pi -e 's|\s*(<'$__prop'>)([^<]+)(</'$__prop'>)\s*||g' $__file
    else
      __cur=`getCurrProperty $__prop $__file`
      [ -z "$__cur" ] && continue
      perl -pi -e 's|(<'$__prop'>)([^<]+)(</'$__prop'>)|${1}'"${__val}"'${3}|g' $__file
    fi
    __diff=`diff -w $$-1 $__file`
    rm -f $$-1
    [ -n "$__diff" ] && __ret=0
    [ -n "$__diff" -a "$__val" =  remove ] && warn "Remove $__prop in $__file"
    [ -n "$__diff" -a "$__val" != remove ] && warn "Change $__prop from $__cur to $__val in $__file"
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
    perl -pi -e 's|\s*('$__key')\s*([=:]).*||g' $__file
  elif [ -n "$__cur" ]; then
    perl -pi -e 's|\s*('$__key')\s*([=:]).*|${1}${2}'"${__val}|g" $__file
  else
    echo "$__key=$__val" >> $__file
  fi
  __diff=`diff -w $$-1 $__file`
  rm -f $$-1
  [ -n "$__diff" -a "$__val" =  remove ] && warn "Remove $__key in $__file"
  [ -n "$__diff" -a "$__val" != remove ] && warn "Change $__key from '$__cur' to '$__val' in $__file"
  [ -n "$__diff" ]
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
  _vers=`MAVEN_OPTS="$HOT" $MVN -version | tr \\\\ / 2>/dev/null | egrep -i 'maven|java|agent.HotswapAgent'`
  [ $? != 0 ] && err "Error $? when running $MVN, $_vers" && return 1
  log "==== VERSIONS ====

MAVEN_OPTS='$HOT' $MVN -version
$_vers
Node version: `$NODE --version`
Npm version: `$NPM --version`
"
}

## adds the pre-releases repositories to the pom.xml
addPrereleases() {
  [ ! -f pom.xml ] && log "Not a Maven proyect, not adding prereleases repository" && return 0
  U="https://maven.vaadin.com/vaadin-prereleases/"
  grep -q "$U" pom.xml && return 0
  log "Adding $U repository"
  for R in repositor pluginRepositor; do
    if ! grep -q $R'ies>' pom.xml; then
      perl -pi -e 's|(\s*)(</properties>)|$1$2\n$1<'$R'ies><'$R'y><id>v</id><url>'$U'</url></'$R'y></'$R'ies>|' pom.xml
    else
      perl -pi -e 's|(\s*)(<'$R'ies>)|$1$2\n$1$1<'$R'y><id>v</id><url>'$U'</url></'$R'y>|' pom.xml
    fi
  done
}

## enables snapshots for the pre-releases repositories in pom.xml
enableSnapshots() {
  [ ! -f pom.xml ] && return 0
  find . -name pom.xml | xargs perl -0777 -pi -e 's/(vaadin-prereleases<\/url>\s*<snapshots>\s*<enabled>)false/${1}true/msg'
}

## runs a command, and shows a message explaining it
## $1: message to show
## $*: command line order and arguments
runCmd() {
  log "$1"
  shift
  _cmd="${*}"
  cmd "$_cmd"
  $_cmd
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
  log "Setting JAVA_HOME=$H PATH=$H/bin:\$PATH"
  cmd "export PATH=$H/bin:\$PATH JAVA_HOME=$H"
  export PATH="$H/bin:$PATH" JAVA_HOME="$H" HOT="-XX:+AllowEnhancedClassRedefinition -XX:HotswapAgent=fatjar"

  if [ ! -f $H/lib/hotswap/hotswap-agent.jar ] ; then
    mkdir -p $H/lib/hotswap
    download "$__hsau" "$H/lib/hotswap/hotswap-agent.jar" || return 1
    log "Installed "`ls -1 $H/lib/hotswap/hotswap-agent.jar`
  fi
}

## enables autoreload for preparing jet brains java runtime
## it modifies jetty in pom.xml and configures the hotswap-agent.properties
enableJBRAutoreload() {
  _p=src/main/resources/hotswap-agent.properties
  mkdir -p `dirname $_p` && echo "autoHotswap=true" > $_p
  perl -pi -e 's|(<scan>)(\d+)(</scan>)|${1}-1${3}|g' pom.xml
  warn "Disabled Jetty autoreload: pom.xml -> "`grep '<scan>' pom.xml`", $_p -> "`cat $_p`
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
