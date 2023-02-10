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
   *) echo "start.js";;
  esac
}

_getStartReadyMessageDev() {
  case $1 in
    latest-lit*|react*) echo "Started Vite";;
    *) echo "Started Application";;
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
  _preset="$1"
  _tmp="$2"
  _port="$3"
  _versionProp=`computeProp $_preset`
  _version=`computeVersion $_preset $4`
  _offline="$5"

  _test=`getStartTestFile $_preset`

  [ "$_preset" = default ] && removeProKey

  cd "$_tmp"
  _dir="$_tmp/$_preset"
  if [ -z "$_offline" ]
  then
    [ -d "$_dir" ] && log "Removing project folder $_dir" && rm -rf $_dir
    # 1
    downloadStarter $_preset || return 1
  fi
  cd "$_dir" || return 1

  _msg=`_getStartReadyMessageDev $_preset`

  if [ -z "$NOCURRENT" ]
  then
    applyPatches $_preset current
    _=`setVersion $_versionProp current`
    # 2
    if [ -z "$NODEV" ]; then
      runValidations dev "$_current" "$_preset" "$_port" "mvn -ntp -B clean" "mvn -ntp -B $PNPM" "$_msg" "$_test" || return 1
    fi
    # 3
    if [ -z "$NOPROD" ]; then
      runValidations prod "$_current" "$_preset" "$_port" "mvn -ntp -B -Pproduction package $PNPM" 'java -jar target/*.jar' "Started Application" "$_test" || return 1
    fi
  fi

  # 4
  if setVersion $_versionProp $_version >/dev/null
  then
    applyPatches $_preset next
    # 5
    if [ -z "$NODEV" ]; then
      runValidations dev "$_version" "$_preset" "$_port" "mvn -ntp -B clean" "mvn -ntp -B $PNPM" "$_msg" "$_test" || return 1
    fi
    # 6
    if [ -z "$NOPROD" ]; then
      runValidations prod "$_version" "$_preset" "$_port" "mvn -ntp -B -Pproduction package $PNPM" 'java -jar target/*.jar' "Started Application" "$_test" || return 1
    fi
  fi
}
