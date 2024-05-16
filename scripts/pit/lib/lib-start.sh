. `dirname $0`/lib/lib-validate.sh

## Generate an app from start.vaadin.com with the given preset, and unzip it in the current folder
## multiple presets can be used by joining them with the `_` character
downloadStarter() {
  _preset=$1
  _presets=""
  _dir=$2
  for _p in `echo "$_preset" | tr "_" " "`
  do
    _presets="$_presets&preset=$_p"
  done
  _url="https://start.vaadin.com/dl?${_presets}&projectName=${_preset}"
  _zip="$_preset.zip"

  [ -z "$TEST" ] && log "Downloading $1"
  cmd "curl -s -f '$_url' -o $_zip"
  cmd "unzip $_zip"
  [ -z "$VERBOSE" ] && _silent="-s"

  curl $_silent -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip || return 1

  cmd "cd $_dir"
  cd $_dir
}

generateStarter() {
  _name=$1
  [ -z "$TEST" ] && log "Generating $1"
  case $_name in
    *spring)        cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    archetype*)     cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    vaadin-quarkus) cmd="$MVN -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:3.1.1.Final:create -Dextensions=vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=$_name" ;;
    hilla-*-cli)      cmd="npx @hilla/cli init --react $_name" ;;
  esac
  cmd "$cmd"
  $cmd || return 1
  cmd "cd $_name"
  cd $_name || return 1
  ## if git configuration already exists, skip
  if [ ! -d ".git" ]; then
    git init -q
    git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
    git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
    git add .??* *
    git commit -q -m 'First commit' -a
  fi
}

downloadInitializer() {
  _name=$1
  _java=17
  _boot=3.1.2
  _group=com.vaadin.initializer
  _type=$2
  _deps=$3
  _url="https://start.spring.io/starter.zip?type=$_type&language=java&bootVersion=$_boot&baseDir=$_name&groupId=$_group&artifactId=$_name&name=$_name&description=$_name&packageName=$_group&packaging=jar&javaVersion=$_java&dependencies=$_deps"
  cmd "curl -s '$_url' --output $_name.zip"
  curl -s $_url --output $_name.zip || return 1
  unzip -q $_name.zip
  cmd "unzip -q $_name.zip"
  cmd "cd $_name"
  cd $_name || return 1
  git init -q
  git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
  git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
  git add -f .??* *
  git commit -q -m 'First commit' -a
}

## get the selenium IDE test file used for each starter
getStartTestFile() {
  case $1 in
   *-auth*) echo "start-auth.js";;
   flow-crm-tutorial*) echo "";;
   react-tutorial) echo "react.js";;
   default*|vaadin-quarkus|*_prerelease) echo "hello.js";;
   initializer*) echo "noop.js";; # disabled until we use vaadin initializer for flow and hilla
   archetype*) echo "click-hotswap.js";;
   hilla-react-cli) echo "hilla-react-cli.js";;
   react|react-crm-tutorial|test-hybrid*) echo "noop.js";;
   *) echo "start.js";;
  esac
}

_getClean() {
  case $1 in
    initializer-hilla-gradle) echo "$GRADLE clean" ;;
    *) echo "$MVN -ntp -B clean";;
  esac
}

_getCompProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B clean";;
    initializer-hilla-gradle) echo "$GRADLE build -Dhilla.productionMode -Dvaadin.productionMode && rm -f ./build/libs/*-plain.jar";;
    *) echo "$MVN -ntp -B -Pproduction package $PNPM";;
  esac
}

_getRunDev() {
  case $1 in
    vaadin-quarkus) echo "$MVN -ntp -B quarkus:dev";;
    initializer-hilla-maven) echo "$MVN -ntp -B spring-boot:run";;
    initializer-hilla-gradle) echo "$GRADLE bootRun";;
    *) echo "$MVN -ntp -B $PNPM";;
  esac
}
_getRunProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war";;
    vaadin-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    *gradle) echo "java -jar ./build/libs/*.jar";;
    *) echo "java -jar -Dvaadin.productionMode target/*.jar";;
  esac
}


_needsLicense() {
  case $1 in
    default*|archetype*) return 1;;
    *) return 0;;
  esac
}

_isNext() {
  expr "$1" : .*partial-nextprerelease$ >/dev/null
}

setStartVersion() {
    if [ -f "build.gradle" ]
    then
      setGradleVersion $1 $2
    else
      setVersion $1 $2
    fi
}

## Run an App downloaded from start.vaadin.com by following the next steps
# 1. generate the project and download from start.vaadin.com (if not in offline)
# 2. run validations in the current version to check that it's not broken
# 3. run validations for the current version in prod-mode
# 4. increase version to the version used for PiT (if version given)
# 5. run validations for the new version in dev-mode
# 6. run validations for the new version in prod-mode
runStarter() {
  MVN=mvn
  _preset="$1"
  _tmp="$2"
  _port="$3"
  _versionProp=`computeProp $_preset`
  _version=`computeVersion $_versionProp $4`
  _offline="$5"

  _test=`getStartTestFile $_preset`

  cd "$_tmp"
  _folder=`echo "$_preset" | tr "_" "-"`
  _dir="$_tmp/$_folder"
  if [ -z "$_offline" -o ! -d "$_dir" ]
  then
     if [ -d "$_dir" ]; then
       [ -n "$TEST" ] && log "Removing project folder $_dir"
       (cmd "rm -rf $_dir" && rm -rf $_dir) || return 1
     fi
    # 1
    case "$_preset" in
      archetype*|vaadin-quarkus|hilla-*-cli) generateStarter $_preset || return 1 ;;
      initializer-hilla-maven)   downloadInitializer $_preset maven-project  hilla,devtools || return 1 ;;
      initializer-hilla-gradle)  downloadInitializer $_preset gradle-project hilla,devtools || return 1 ;;
      # downloadInitializer initializer-vaadin-maven maven-project vaadin,devtools
      # downloadInitializer initializer-vaadin-gradle gradle-project vaadin,devtools
      *) downloadStarter $_preset $_folder || return 1 ;;
    esac
  fi

  [ "$_preset" = archetype-hotswap ] && installJBRRuntime

  computeMvn
  computeGradle
  printVersions || return 1

  _msg="Started .*Application|Frontend compiled|Started ServerConnector|Started Vite|Listening on:"
  _msgprod="Started .*Application|Started ServerConnector|Listening on:"
  _prod=`_getRunProd $_preset`
  _dev=`_getRunDev $_preset`
  _compile=`_getCompProd $_preset`
  _clean=`_getClean $_preset`

  _needsLicense "$_preset" || removeProKey

  if test -z "$NOCURRENT" && ! _isNext "$_preset"
  then
    _current=`setStartVersion $_versionProp current`
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
  if _isNext "$_preset" || setStartVersion $_versionProp $_version >/dev/null
  then
    [ -d ~/.vaadin/node ] && cmd "rm -rf ~/.vaadin/node" && rm -rf ~/.vaadin/node
    applyPatches $_preset next $_version prod || return 0
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
