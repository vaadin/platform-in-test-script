. `dirname $0`/lib/lib-validate.sh

## Generate an starter with the given preset, and unzip it in the current folder
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

  log "Downloading $_url"
  curl -s -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip || return 1

  _new=`echo "$_preset" | tr "_" "-"`
  [ "$_new" != "$_preset" ] && mv "$_new" "$_preset" || return 0
}

## get the selenium IDE test file used for each starter
getStartTestFile() {
  case $1 in
   latest-java|latest-java-top|latest-javahtml|latest-typescript|latest-typescript-top)
     echo "latest-java.side";;
   latest-java_partial-auth|latest-java-top_partial-auth)
     echo "latest-java-auth.side";;
   latest-typescript_partial-auth)
     echo "latest-typescript-auth.side";;
   *)
     echo "$1.side";;
  esac
}

runStarters() {
  _presets="$1"
  _port="$2"
  _version="$3"
  _offline="$4"

  pwd="$PWD"
  tmp="$pwd/starters"
  mkdir -p "$tmp"

  for i in $_presets
  do
    _versionProp=vaadin.version
    if echo "$i" | grep -q typescript
    then
      _version=`echo $_version | sed -e 's,^23,1,'`
      _versionProp=hilla.version
    fi

    echo ""
    log "================= TESTING Start Preset '$i' $_offline =================="
    cd "$tmp"
    dir="$tmp/$i"
    if [ -z "$_offline" ]
    then
      [ -d "$dir" ] && log "Removing project folder $dir" && rm -rf $dir
      downloadStarter $i || exit 1
    fi
    cd "$dir" || exit 1

    _test=`getStartTestFile $i`

    runValidations current $i $_port "" "" "" "$_test" || exit 1

    if setVersion $_versionProp $_version
    then
      runValidations $_version $i $_port "" "" "" "$_test" || exit 1
      runValidations $_version $i $_port 'mvn -Pproduction package' 'java -jar target/*.jar' "Generated demo data" "$_test" || exit 1
    fi
    log "==== Start Preset '$i' was Tested Successfuly ===="
  done
}
