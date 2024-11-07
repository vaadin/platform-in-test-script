## LIBRARY for testing Vaadin starters that can be generated:
## - from start.vaadin.com
## - from spring initializer
## - created with archetypes

. `dirname $0`/lib/lib-validate.sh

## Initialize a git repository in the current starter project if not already
## It's useful in the case we want to manually check PiT patches applied
initGit() {
  [ -d ".git" ] && return
  git init -q
  git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
  git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
  git config advice.addIgnoredFile false
  git add .??* * 2>/dev/null
  git commit -q -m 'First commit' -a
}

## Generate an app from start.vaadin.com with the given preset, and unzip it in the current folder
## multiple presets can be used by joining them with the `_` character
downloadStarter() {
  _preset=$1
  _presets=""
  _dir="$2"
  for _p in `echo "$_preset" | tr "_" " "`
  do
    _presets="$_presets&preset=$_p"
  done
  _url="https://start.vaadin.com/dl?${_presets}&projectName=${_preset}"
  _zip="$_preset.zip"

  [ -z "$VERBOSE" ] && _silent="-s"
  runCmd false "Downloading $1" "curl $_silent -f '$_url' -o '$_zip'" || return 1
  runCmd false "Unzipping $_name" "unzip -q '$_zip'" && rm -f "$_zip" || return 1
  runCmd false "Changing to $_dir dir" "cd '$_dir'" || return 1
}

## Generates a starter by using archetype, or hilla/cli
## TODO: add support for vaadi cli
generateStarter() {
  _name=$1
  [ -z "$TEST" ] && log "Generating $1"
  case $_name in
    *spring)        cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    archetype*)     cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    vaadin-quarkus) cmd="$MVN -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:3.1.1.Final:create -Dextensions=vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=$_name" ;;
    hilla-*-cli)    cmd="npx @hilla/cli init --react $_name" ;;
  esac
  runCmd false "Generating $1" "$cmd" || return 1
  runCmd false "Changing to $_name dir" "cd '$_name'" || return 1
  initGit
}


## Gemerate a starter using spring initializer website
## TODO: Check versions
downloadInitializer() {
  _name=$1
  _java=17
  _boot=3.3.4
  _group=com.vaadin.initializer
  _type=$2
  _deps=$3
  _url="https://start.spring.io/starter.zip?type=$_type&language=java&bootVersion=$_boot&baseDir=$_name&groupId=$_group&artifactId=$_name&name=$_name&description=$_name&packageName=$_group&packaging=jar&javaVersion=$_java&dependencies=$_deps"
  runCmd false "Downloading $_name" "curl -s '$_url' --output $_name.zip" || return 1
  runCmd false "Unzipping $_name" "unzip -q '$_name.zip'" && rm -f "$_name.zip" || return 1
  runCmd false "Changing to $_name dir" "cd '$_name'" || return 1
  initGit
}

## get the Playwright IDE test file used for each starter
## thwey are located in the pit/its folder
## TODO: check those returning noop.js
getStartTestFile() {
  case $1 in
   *-auth*) echo "start-auth.js";;
   flow-crm-tutorial*) echo "";;
   react-tutorial) echo "react.js";;
   default*|vaadin-quarkus|*_prerelease) echo "hello.js";;
   initializer*) echo "initializer.js";;
   archetype*) echo "click-hotswap.js";;
   hilla-react-cli) echo "hilla-react-cli.js";;
   react) echo "react-starter.js";;
   test-hybrid-react*) echo "hybrid-react.js";;
   test-hybrid*) echo "hybrid.js";;
   react-crm-tutorial) echo "noop.js";;
   collaboration) echo "collaboration.js";;
   *) echo "start.js";;
  esac
}

## Get the clean command for the given starter
_getClean() {
  case $1 in
    initializer-*-gradle*) echo "$GRADLE clean" ;;
    *) echo "$MVN -ntp -B clean";;
  esac
}

## Get the command to compile the project in production mode
_getCompProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B clean";;
    initializer-*-gradle*) echo "$GRADLE clean build -Dhilla.productionMode -Dvaadin.productionMode && rm -f ./build/libs/*-plain.jar";;
    *) echo "$MVN -ntp -B -Pproduction clean package $PNPM";;
  esac
}

## Get the command to run the project in dev mode
_getRunDev() {
  case $1 in
    vaadin-quarkus) echo "$MVN -ntp -B quarkus:dev";;
    initializer-*-maven*) echo "$MVN -ntp -B spring-boot:run";;
    initializer-*-gradle*) echo "$GRADLE bootRun";;
    *) echo "$MVN -ntp -B $PNPM";;
  esac
}

## Get the command to run the project in production mode
_getRunProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war";;
    vaadin-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    *gradle*) echo "java -jar ./build/libs/*.jar";;
    *) echo "java -jar -Dvaadin.productionMode target/*.jar";;
  esac
}

## Check whether the starter needs a pro license, if not, remove the pro key
## so as we can check that there are no pro features in the starter
_needsLicense() {
  case $1 in
    default*|archetype*) return 1;;
    *) return 0;;
  esac
}

## Check whether the run is a next prerelease (we have to increase the version with the --version provided)
_isNext() {
  expr "$1" : .*partial-nextprerelease$ >/dev/null
}

## Set the version of the project to the given version
setStartVersion() {
    if [ -f "build.gradle" ]
    then
      setGradleVersion $1 $2
    else
      setVersion $1 $2
    fi
}

## Run an App downloaded from start.vaadin.com by following the next steps
# 0. compute properties and make preparations
# 1. generate the project using archetypes or download from start.vaadin.com, initializer, etc
#    if we are in offline mode we skip this step if the project already exists, and clean it instead
#    it installs the JBR runtime if the project can be run with it
#    it removes the pro key if the project does not need a pro license
# 2. run validations in the current version to check that it's not broken
# 3. run validations for the current version in prod-mode
# 4. increase version to the version used for PiT (if version given)
# 5. run validations for the new version in dev-mode
# 6. run validations for the new version in prod-mode
runStarter() {
  # 0
  MVN=mvn
  _preset="$1"
  _tmp="$2"
  _port="$3"
  _versionProp=`computeProp "$_preset"`
  _version=`computeVersion "$_versionProp" "$4"`
  _offline="$5"

  _test=`getStartTestFile "$_preset"`

  cd "$_tmp"
  _folder=`echo "$_preset" | tr "_" "-"`
  _dir="$_tmp/$_folder"

  #  1
  if [ -z "$_offline" -o ! -d "$_dir" ]
  then
     if [ -d "$_dir" ]; then
       runCmd false "Cleaning project folder $_dir" "rm -rf '$_dir'" || return 1
     fi
    case "$_preset" in
      archetype*|vaadin-quarkus|hilla-*-cli) generateStarter "$_preset" || return 1 ;;
      initializer-*-maven*)  downloadInitializer "$_preset" maven-project vaadin,devtools || return 1 ;;
      initializer-*-gradle*) downloadInitializer "$_preset" gradle-project vaadin,devtools || return 1 ;;
      *) downloadStarter "$_preset" "$_folder" || return 1 ;;
    esac
  fi

  [ "$_preset" = archetype-hotswap ] && installJBRRuntime

  computeMvn
  computeGradle
  printVersions || return 1

  _msg="Started .*Application|Frontend compiled|Started ServerConnector|Started Vite|Listening on:"
  _msgprod="Started .*Application|Started ServerConnector|Listening on:"
  _prod=`_getRunProd "$_preset"`
  _dev=`_getRunDev "$_preset"`
  _compile=`_getCompProd "$_preset"`
  _clean=`_getClean "$_preset"`

  _needsLicense "$_preset" || removeProKey

  if test -z "$NOCURRENT" && ! _isNext "$_preset"
  then
    _current=`setStartVersion "$_versionProp" current`
    applyPatches $_preset current $_current dev || return 0
    # 2
    if [ -z "$NODEV" ]; then
      MAVEN_OPTS="$HOT" runValidations dev "$_current" "$_preset" "$_port" "$_clean" "$_dev" "$_msg" "$_test" || return 1
    fi
    # 3
    if [ -z "$NOPROD" ]; then
      runValidations prod "$_current" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" "$_test" || return 1
    fi
  fi

  # 4
  if _isNext "$_preset" || setStartVersion "$_versionProp" "$_version" >/dev/null
  then
    [ -d ~/.vaadin/node ] && cmd "rm -rf ~/.vaadin/node" && rm -rf ~/.vaadin/node
    applyPatches "$_preset" next "$_version" prod || return 0
    # 5
    if [ -z "$NODEV" ]; then
      MAVEN_ARGS="$MAVEN_ARGS" MAVEN_OPTS="$HOT" runValidations dev "$_version" "$_preset" "$_port" "$_clean" "$_dev" "$_msg" "$_test" || return 1
    fi
    # 6
    if [ -z "$NOPROD" ]; then
      runValidations prod "$_version" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" "$_test" || return 1
    fi
  fi
}
