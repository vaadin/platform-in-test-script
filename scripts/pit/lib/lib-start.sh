## LIBRARY for testing Vaadin starters that can be generated:
## - from start.vaadin.com
## - from spring initializer
## - created with archetypes

. `dirname $0`/lib/lib-validate.sh

## Initialize a git repository in the current starter project if not already initialized
## Useful for manually checking PiT patches applied
initGit() {
  [ -d ".git" ] && return
  git init -q
  git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
  git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
  git config advice.addIgnoredFile false
  git add .??* * 2>/dev/null
  git commit -q -m 'First commit' -a
}

## Download and unzip an app from start.vaadin.com with the given preset
## Multiple presets can be combined by joining them with the '_' character
## $1: preset name (or presets separated by '_')
## $2: directory to extract into
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

## Generate a starter using Maven archetype or Hilla CLI
## $1: starter name (e.g., 'archetype-spring', 'vaadin-quarkus', 'hilla-react-cli')
## TODO: add support for Vaadin CLI
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


## Generate a starter using Spring Initializr website
## $1: project name
## $2: project type ('maven-project' or 'gradle-project')
## $3: dependencies (comma-separated, e.g., 'vaadin,devtools')
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

## Get the Playwright test file to use for a specific starter
## Test files are located in the scripts/pit/its folder
## $1: starter name
## Returns: test filename or empty string if no test
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
## $1: starter name
## Returns: Maven or Gradle clean command
_getClean() {
  case $1 in
    initializer-*-gradle*) echo "$GRADLE clean" ;;
    *) echo "$MVN -ntp -B clean";;
  esac
}

## Get the command to compile the project in production mode
## $1: starter name
## Returns: Maven or Gradle production build command
_getCompProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B clean";;
    initializer-*-gradle*) echo "$GRADLE clean build -Dhilla.productionMode -Dvaadin.productionMode && rm -f ./build/libs/*-plain.jar";;
    *) echo "$MVN -ntp -B -Pproduction clean package $PNPM";;
  esac
}

## Get the command to run the project in development mode
## $1: starter name
## $2: port number
## Returns: Maven or Gradle dev run command
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
## $1: starter name
## $2: port number
## Returns: Java command to run the built JAR
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

## Check whether the starter requires a Vaadin Pro license
## If not, the pro key will be removed to verify no pro features are used
## $1: starter name
## Returns: 0 if license needed, 1 if not
_needsLicense() {
  case $1 in
    default*|archetype*) return 1;;
    *) return 0;;
  esac
}

## Check whether this is a next pre-release run (version needs to be increased)
## $1: starter name
## Returns: 0 if next pre-release, 1 otherwise
_isNext() {
  expr "$1" : .*partial-nextprerelease$ >/dev/null
}

## Set the version of the project (works for both Maven and Gradle projects)
## $1: property name (e.g., 'vaadin.version', 'vaadinVersion')
## $2: new version value (or 'current' to get current version)
setStartVersion() {
    if [ -f "build.gradle" ]
    then
      setGradleVersion $1 $2
    else
      setVersion $1 $2
    fi
}

## Run a starter app downloaded from start.vaadin.com by following these steps:
## 0. Compute properties and make preparations
## 1. Generate project using archetypes or download from start.vaadin.com, Initializr, etc
##    In offline mode, reuse existing project and clean it
##    Install JBR runtime if project supports it
##    Remove pro key if project doesn't need a pro license
## 2. Run validations in current version to check it's not broken (dev mode)
## 3. Run validations for current version in production mode
## 4. Increase version to the one specified for PiT (if version given)
## 5. Run validations for the new version in dev mode
## 6. Run validations for the new version in production mode
## $1: starter name/preset
## $2: temporary directory path
## $3: port number
## $4: version to test
## $5: offline mode flag
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
