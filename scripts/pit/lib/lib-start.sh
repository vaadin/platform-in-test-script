. `dirname $0`/lib/lib-validate.sh

## Generate an app from start.vaadin.com with the given preset, and unzip it in the current folder
## multiple presets can be used by joining them with the `_` character
downloadStarter() {
  _preset=$1
  _presets=""
  for _p in `echo "$_preset" | tr "_" " "`
  do
    _presets="$_presets&preset=$_p"
  done
  _url="https://start.vaadin.com/dl?${_presets}&projectName=${_preset}"
  _zip="$_preset.zip"

  log "Downloading $1"
  cmd "curl -s -f '$_url' -o $_zip"
  cmd "unzip $_zip"
  [ -z "$VERBOSE" ] && _silent="-s"

  curl $_silent -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip || return 1

  _new=`echo "$_preset" | tr "_" "-"`
  cmd "cd $_new"
  [ "$_new" != "$_preset" ] && mv "$_new" "$_preset" || return 0
}

generateStarter() {
  _name=$1
  log "Generating $1"
  cmd="$MVN -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=$_name"
  cmd "$cmd"
  $cmd || return 1
  cd $_name || return 1
  git init -q
  git config user.email | grep -q ... || git config user.email "vaadin-bot@vaadin.com"
  git config user.name  | grep -q ... || git config user.name "Vaadin Bot"
  git add .??* *
  git commit -q -m 'First commit' -a
}

computeVersion() {
  case $1 in
    *typescript*|*hilla*|*react*|*-lit*) echo $2 | sed -e 's,^23,1,' | sed -e 's,^24,2,';;
    *) echo "$2";;
  esac
}
computeProp() {
  case $1 in
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
   default) echo "hello.js";;
   archetype*) [ -n "$HOT " ] && echo "click-hotswap.js" || echo "click.js";;
   *) echo "start.js";;
  esac
}

_getCompProd() {
  case $1 in
    archetype-java) echo "$MVN -ntp -B clean";;
    *) echo "$MVN -ntp -B -Pproduction package $PNPM";;
  esac
}

_getRunProd() {
  case $1 in
    archetype-java) echo "$MVN -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war";;
    *) echo "java -jar -Dvaadin.productionMode target/*.jar";;
  esac
}

_getStartReadyMessageDev() {
  case $1 in
    latest-lit*|react*) echo "Started Vite|Frontend compiled";;
    *) echo "Started Application|Frontend compiled|Started ServerConnector";;
  esac
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
  _version=`computeVersion $_preset $4`
  _offline="$5"

  _test=`getStartTestFile $_preset`

  cd "$_tmp"

  _dir="$_tmp/$_preset"
  if [ -z "$_offline" ]
  then
    [ -d "$_dir" ] && log "Removing project folder $_dir" && rm -rf $_dir
    # 1
    case "$_preset" in
      archetype*) generateStarter $_preset || return 1 ;;
      *) downloadStarter $_preset || return 1 ;;
    esac
  fi
  cd "$_dir" || return 1

  expr $_preset : archetype >/dev/null && installJBRRuntime

  computeMvn
  printVersions

  _msg=`_getStartReadyMessageDev $_preset`
  _prod=`_getRunProd $_preset`
  _compile=`_getCompProd $_preset`
  _msgprod="Started Application|Started ServerConnector"

  [ "$_preset" = default ] && removeProKey

  if [ -z "$NOCURRENT" ]
  then
    _current=`setVersion $_versionProp current`
    applyPatches $_preset current
    # 2
    if [ -z "$NODEV" ]; then
      MAVEN_OPTS="$HOT" runValidations dev "$_current" "$_preset" "$_port" "$MVN -ntp -B clean" "$MVN -ntp -B $PNPM" "$_msg" "$_test" || return 1
    fi
    # 3
    if [ -z "$NOPROD" ]; then
      MAVEN_OPTS="" runValidations prod "$_current" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" || return 1
    fi
  fi

  # 4
  if setVersion $_versionProp $_version >/dev/null
  then
    applyPatches $_preset next
    # 5
    if [ -z "$NODEV" ]; then
      MAVEN_OPTS="$HOT" runValidations dev "$_version" "$_preset" "$_port" "$MVN -ntp -B clean" "$MVN -ntp -B $PNPM" "$_msg" "$_test" || return 1
    fi
    # 6
    if [ -z "$NOPROD" ]; then
      MAVEN_OPTS="" runValidations prod "$_version" "$_preset" "$_port" "$_compile" "$_prod" "$_msgprod" || return 1
    fi
  fi

  [ "$_preset" = default ] && restoreProKey || true
}
