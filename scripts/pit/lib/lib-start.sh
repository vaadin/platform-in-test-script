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
  local preset presets dir p url zip silent name
  preset=$1
  presets=""
  dir="$2"
  for p in `echo "$preset" | tr "_" " "`
  do
    presets="$presets&preset=$p"
  done
  url="https://start.vaadin.com/dl?${presets}&projectName=${preset}"
  zip="$preset.zip"

  [ -z "$VERBOSE" ] && silent="-s"
  runCmd -f "Downloading $1" "curl $silent -f '$url' -o '$zip'" || return 1
  runCmd -f "Unzipping $name" "unzip -q '$zip'" && rm -f "$zip" || return 1
  cmd "cd '$dir'" && cd "$dir" || return 1
}

## Generates a starter by using archetype, or hilla/cli
## TODO: add support for vaadi cli
generateStarter() {
  local name cmd
  name=$1
  case $name in
    *spring)        cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$name" ;;
    archetype*)     cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$name" ;;
    ## workaround in current quarkus-maven-plugin 3.28.3 : -Dextensions=rest,vaadin
    ## https://github.com/quarkusio/quarkus/issues/50528
    vaadin-quarkus) cmd="$MVN -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:create -Dextensions=rest,vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=$name" ;;
    hilla-*-cli)    cmd="npx -y @hilla/cli init --react $name" ;;
  esac
  runCmd -f "Generating $1" "$cmd" || return 1
  cmd "cd '$name'" && cd "$name" || return 1
  initGit
}


## Gemerate a starter using spring initializer website
## TODO: Check versions
downloadInitializer() {
  local name java boot group type deps url
  name=$1
  java=`computeJavaMajor`
  boot=4.0.5
  group=com.vaadin.initializer
  type=$2
  deps=$3
  url="https://start.spring.io/starter.zip?type=$type&language=java&bootVersion=$boot&baseDir=$name&groupId=$group&artifactId=$name&name=$name&description=$name&packageName=$group&packaging=jar&javaVersion=$java&dependencies=$deps"
  runCmd -f "Downloading $name" "curl -s '$url' --output $name.zip" || return 1
  runCmd -f "Unzipping $name" "unzip -q '$name.zip'" && rm -f "$name.zip" || return 1
  cmd "cd '$name'" && cd "$name" || return 1
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
## $1: starter name, $2: port
_getRunDev() {
  local _P
  _P="-Dserver.port=$2"
  case $1 in
    vaadin-quarkus) echo "$MVN -ntp -B -Dquarkus.enforceBuildGoal=false -Dquarkus.http.port=$2 quarkus:dev";;
    initializer-*-maven*) echo "$MVN -ntp -B spring-boot:run -Dspring-boot.run.arguments=--server.port=$2";;
    initializer-*-gradle*) echo "$GRADLE bootRun --args='--server.port=$2'";;
    *) echo "$MVN -ntp -B $PNPM $_P";;
  esac
}

## Get the command to run the project in production mode
## $1: starter name, $2: port
_getRunProd() {
  local _P
  _P="-Dserver.port=$2"
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B -Pproduction -Dvaadin.productionMode -Djetty.http.port=$2 jetty:run-war";;
    vaadin-quarkus) echo "java -Dquarkus.http.port=$2 -jar target/quarkus-app/quarkus-run.jar";;
    *gradle*) echo "java $_P -jar ./build/libs/*.jar";;
    *) echo "java $_P -Dvaadin.productionMode -jar target/*.jar";;
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
  local GHTK GITHUB_TOKEN MVN preset tmp port versionProp version offline
  local test folder dir msg msgprod prod dev compile clean current
  GHTK= GITHUB_TOKEN=
  # 0
  MVN=mvn
  preset="$1"
  tmp="$2"
  port="$3"
  versionProp=`computeProp "$preset"`
  version=`computeVersion "$versionProp" "$4"`
  offline="$5"

  test=`getStartTestFile "$preset"`

  cd "$tmp"
  folder=`echo "$preset" | tr "_" "-"`
  dir="$tmp/$folder"

  #  1
  if [ -z "$offline" -o ! -d "$dir" ]
  then
     if [ -d "$dir" ]; then
       runCmd -f "Cleaning project folder $dir" "rm -rf '$dir'" || return 1
     fi
    case "$preset" in
      archetype*|vaadin-quarkus|hilla-*-cli) generateStarter "$preset" || return 1 ;;
      initializer-*-maven*)  downloadInitializer "$preset" maven-project vaadin,devtools || return 1 ;;
      initializer-*-gradle*) downloadInitializer "$preset" gradle-project vaadin,devtools || return 1 ;;
      *) downloadStarter "$preset" "$folder" || return 1 ;;
    esac
  else
    cd "$folder"
  fi
  computeMvn
  computeGradle

  printVersions || return 1

  msg="Started .*Application|Frontend compiled|Started ServerConnector|Started Vite|Listening on:|Vaadin is running"
  msgprod="Started .*Application|Started ServerConnector|Listening on:|Started oejs.Server"
  prod=`_getRunProd "$preset" "$port"`
  dev=`_getRunDev "$preset" "$port"`
  compile=`_getCompProd "$preset"`
  clean=`_getClean "$preset"`

  _needsLicense "$preset" || removeProKey

  if test -z "$NOCURRENT" && ! _isNext "$preset"
  then
    current=`setStartVersion "$versionProp" current`
    applyPatches $preset current $current dev || return 0
    # 2
    if [ -z "$NODEV" ]; then
      runValidations dev "$current" "$preset" "$port" "$clean" "$dev $HOT" "$msg" "$test" || return 1
    fi
    # 3
    if [ -z "$NOPROD" ]; then
      runValidations prod "$current" "$preset" "$port" "$compile" "$prod" "$msgprod" "$test" || return 1
    fi
  fi

  # 4
  if _isNext "$preset" || setStartVersion "$versionProp" "$version" >/dev/null
  then
    [ -d ~/.vaadin/node ] && cmd "rm -rf ~/.vaadin/node" && rm -rf ~/.vaadin/node
    applyPatches "$preset" next "$version" prod || return 0
    # 5
    if [ -z "$NODEV" ]; then
      runValidations dev "$version" "$preset" "$port" "$clean" "$dev $HOT" "$msg" "$test" || return 1
    fi
    # 6
    if [ -z "$NOPROD" ]; then
      runValidations prod "$version" "$preset" "$port" "$compile" "$prod" "$msgprod" "$test" || return 1
    fi
  fi
}
