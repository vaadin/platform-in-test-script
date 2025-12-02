## LIBRARY for installing and running playwright tests

## Check whether playwright is installed in node_modules folder of the test node-script
isInstalledPlaywright() {
  _dir=`dirname "$1"`
  (cd "$_dir" && \
    echo -e "const { chromium } = require('@playwright/test');\n" | "$NODE" - 2>/dev/null)
}

## Install playwright in the folder of the test node-script
installPlaywright() {
  _pfile="playwright-"`uname`".out"
  _dir=`dirname "$1"`
  (cd "$_dir" && runToFile "$NPM install --no-audit @playwright/test" "$_pfile" "$VERBOSE") || return 1
  (cd "$_dir" && runToFile "npx playwright install chromium" "$_pfile" "$VERBOSE") || return 1
  isLinux && (cd "$_dir" && runToFile "'${NODE}' ./node_modules/.bin/playwright install-deps chromium" "$_pfile" "$VERBOSE") || true
}

## Check if playwright is installed, otherwise install it
checkPlaywrightInstallation() {
  [ -n "$UPDATE" ] && installPlaywright "$1"
  isInstalledPlaywright "$1" && return 0
  installPlaywright "$1"
}

## Run playwright tests
# $1 test file to run
# $2 output file of the running server-side running in background to save
# $3 mode (dev, prod)
# $4 name of the app being tested
# $5 platform version in test
runPlaywrightTests() {
  local _test_file="$1"
  local _base_name=`basename "$1"`
  local _ofile="$2"
  local _mode="$3"
  local _name="$4"
  local _version="$5"
  shift 5

  _pfile="playwright-$_version-$_mode-"`uname`".out"
  [ -f "$_test_file" ] && checkPlaywrightInstallation "$_test_file" || return 0

  _args="$* --name=$_name --version=$_version --mode=$_mode"
  [ -n "$SCREENSHOTS" ] && _args="$_args --screenshots"

  isHeadless && _args="$_args --headless"
  log "Running visual test: $_base_name"
  PATH=$PATH START=$START runToFile "'$NODE' '$_test_file' $_args" "$_pfile" "$VERBOSE" true
  err=$?
  [ -n "$TEST" ] && return 0
  H=`grep ' > CONSOLE:' "$_pfile" | perl -pe 's/(> CONSOLE: Received xhr.*?feat":).*/$1 .../g'`
  H=`echo "$H" | egrep -v 'Atmosphere|Vaadin push loaded|Websocket successfully opened|Websocket closed|404.*favicon.ico'`
  [ -n "$H" ] && [ "$_mode" = "prod" ] && reportError "Console Warnings in $_mode mode $5" "$H" && echo "$H"
  H=`egrep ' > (JSERROR|PAGEERROR):' "$_pfile"`
  [ -n "$H" ] && reportError "Console Errors in $_msg" "$H" && echo "$H" && return 1
  H=`tail -15 $_pfile`
  [ $err != 0 ] && reportOutErrors "$_ofile" "Error ($err) running Visual-Test ("`basename $_pfile`")" || echo ">>>> PiT: playwright '$_test_file' done" >> $__file
  [ $err != 0 ] && rm -f "$_pfile"
  return $err
}


