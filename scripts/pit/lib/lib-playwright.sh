## Check whether playwright is installed in node_modules folder of the test node-script
isInstalledPlaywright() {
  (cd `dirname $1` && \
    echo -e "const { chromium } = require('playwright');\n" | node - 2>/dev/null)
}

## Install playwright in the folder of the test node-script
installPlaywright() {
  log "Installing playwright ..."
  (cd `dirname $1` && npm install --no-audit playwright)
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
  [ -f "$_test_file" ] && checkPlaywrightInstallation $_test_file || return 0
  log "Running Playwright test from file: $_test_file"

  _args="--port=$_port"

  isHeadless && _args="$_args --headless"

  log "Running: node $_test_file $_args"
  node $_test_file $_args
}

