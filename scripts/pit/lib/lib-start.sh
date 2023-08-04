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

  cmd "cd $2"
}

generateStarter() {
  _name=$1
  log "Generating $1"
  case $_name in
    *spring)        cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    archetype*)     cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name" ;;
    vaadin-quarkus) cmd="$MVN -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:3.1.1.Final:create -Dextensions=vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=$_name" ;;
  esac
  cmd "$cmd"
  $cmd || return 1
  cd $_name || return 1
  git init -q
  git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
  git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
  git add .??* *
  git commit -q -m 'First commit' -a
}

downloadInitializer() {
  _java=17
  _boot=3.1.1
  curl -s 'https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=3.1.1&baseDir=initializer&groupId=com.vaadin.initializer&artifactId=initializer&name=initializer&description=initializer&packageName=com.vaadin.inititalizer&packaging=jar&javaVersion=17&dependencies=vaadin,h2,devtools' \
  -H 'Referer: https://start.spring.io/' --output initializer.zip
}

computeVersion() {
  case $1 in
    *hilla*) echo $2 | sed -e 's,^23,1,' | sed -e 's,^24,2,';;
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

## get the selenium IDE test file used for each starter
getStartTestFile() {
  case $1 in
   *-auth) echo "start-auth.js";;
   flow-crm-tutorial*) echo "";;
   react-tutorial) echo "react.js";;
   default*|vaadin-quarkus) echo "hello.js";;
   archetype*) [ -n "$HOT " ] && echo "click-hotswap.js" || echo "click.js";;
   *) echo "start.js";;
  esac
}

_getCompProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B clean";;
    *) echo "$MVN -ntp -B -Pproduction package $PNPM";;
  esac
}

_getRunDev() {
  case $1 in
    vaadin-quarkus) echo "$MVN -ntp -B quarkus:dev";;
    *) echo "$MVN -ntp -B $PNPM";;
  esac
}
_getRunProd() {
  case $1 in
    archetype-hotswap|archetype-jetty) echo "$MVN -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war";;
    vaadin-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
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
    [ -d "$_dir" ] && ([ -n "$TEST" ] || log "Removing project folder $_dir") && rm -rf $_dir
    # 1
    case "$_preset" in
      archetype*|vaadin-quarkus) generateStarter $_preset || return 1 ;;
      *) downloadStarter $_preset $_folder || return 1 ;;
    esac
  fi
  cd "$_dir" || return 1

  [ "$_preset" = archetype-hotswap ] && installJBRRuntime

  computeMvn
  printVersions || return 1

  _msg="Started Application|Frontend compiled|Started ServerConnector|Started Vite|Listening on:"
  _msgprod="Started Application|Started ServerConnector|Listening on:"
  _prod=`_getRunProd $_preset`
  _dev=`_getRunDev $_preset`
  _compile=`_getCompProd $_preset`

  _needsLicense "$_preset" || removeProKey

  if test -z "$NOCURRENT" && ! _isNext "$_preset"
  then
    _current=`setVersion $_versionProp current`
    applyPatches $_preset current $_current dev || return 0
    # 2
    if [ -z "$NODEV" ]; then
      MAVEN_OPTS="$HOT" runValidations dev "$_current" "$_preset" "$_port" "$MVN -ntp -B clean" "$_dev" "$_msg" "$_test" || return 1
    fi
    # 3
    if [ -z "$NOPROD" ]; then
      MAVEN_OPTS="" runValidations prod "$_current" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" "$_test" || return 1
    fi
  fi

  # 4
  if setVersion $_versionProp $_version >/dev/null || _isNext "$_preset"
  then
    applyPatches $_preset next $_version prod || return 0
    # 5
    if [ -z "$NODEV" ]; then
      MAVEN_OPTS="$HOT" runValidations dev "$_version" "$_preset" "$_port" "$MVN -ntp -B clean" "$_dev" "$_msg" "$_test" || return 1
    fi
    # 6
    if [ -z "$NOPROD" ]; then
      MAVEN_OPTS="" runValidations prod "$_version" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" || return 1
    fi
  fi

  _needsLicense "$_preset" || restoreProKey
}
