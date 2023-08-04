## Check whether playwright is installed in node_modules folder of the test node-script
isInstalledPlaywright() {
  (cd `dirname $1` && \
    echo -e "const { chromium } = require('playwright');\n" | $NODE - 2>/dev/null)
}

## Install playwright in the folder of the test node-script
installPlaywright() {
  _pfile="playwright-"`uname`".out"
  _dir=`dirname $1`
  (cd $_dir && runToFile "${NPM}install --no-audit playwright" "$_pfile" "$VERBOSE") || return 1
  isLinux && (cd $_dir && runToFile "${NODE}./node_modules/.bin/playwright install-deps" "$_pfile" "$VERBOSE") || true
}

## Check if playwright is installed, otherwise install it
checkPlaywrightInstallation() {
  [ -n "$UPDATE" ] && installPlaywright $1
  isInstalledPlaywright $1 && return 0
  installPlaywright $1
}

## Run playwright tests
runPlaywrightTests() {
  _test_file=$1
  _port=$2
  _mode=$3
  _pfile="playwright-$_mode-"`uname`".out"
  [ -f "$_test_file" ] && checkPlaywrightInstallation $_test_file || return 0
  _args="--port=$_port --name=$5 --mode=$_mode"
  isHeadless && _args="$_args --headless"
  PATH=$PATH runToFile "$NODE $_test_file $_args" "$_pfile" "$VERBOSE"
  err=$?
  [ -n "$TEST" ] && return 0
  H=`grep '> CONSOLE:' "$_pfile" | perl -pe 's/(> CONSOLE: Received xhr.*?feat":).*/$1 .../g'`
  H=`echo "$H" | egrep -v 'Atmosphere|Vaadin push loaded|Websocket successfully opened|Websocket closed'`
  [ -n "$H" ] && [ "$_mode" = "prod" ] && reportError "Console Warnings in $mode mode" "$H" && echo "$H"
  H=`grep '> JSERROR:' "$_pfile"`
  [ -n "$H" ] && reportError "Console Errors in $_mode mode" "$H" && echo "$H" && return 1
  H=`tail -15 $_pfile`
  [ $err != 0 ] && reportOutErrors "$4" "Error ($err) running Visual-Test ("`basename $_pfile`")" || echo ">>>> PiT: playwright $_test_file done" >> $__file
  return $err
}

