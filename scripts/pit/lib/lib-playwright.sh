## Check whether playwright is installed in node_modules folder of the test node-script
isInstalledPlaywright() {
  (cd `dirname $1` && \
    echo -e "const { chromium } = require('playwright');\n" | node - 2>/dev/null)
}

## Install playwright in the folder of the test node-script
installPlaywright() {
  _pfile="playwright-"`uname`".out"
  (cd `dirname $1` && runToFile "npm install --no-audit playwright" "$_pfile" "$VERBOSE")
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
  _args="--port=$_port"
  isHeadless && _args="$_args --headless"
  runToFile "node $_test_file $_args" "$_pfile" "$VERBOSE"
  err=$?
  [ "$_mode" = "prod" ] && grep '> CONSOLE:' "$_pfile"
  grep '> JSERROR:' "$_pfile"

  return $err
}

