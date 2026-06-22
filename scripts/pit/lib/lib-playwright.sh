## LIBRARY for installing and running playwright tests

## Check whether playwright is installed in node_modules folder of the test node-script
isInstalledPlaywright() {
  local dir
  dir=`dirname "$1"`
  (cd "$dir" && \
    echo -e "const { chromium } = require('@playwright/test');\n" | "$NODE" - 2>/dev/null)
}

## Install playwright in the folder of the test node-script
installPlaywright() {
  local pfile dir
  pfile="playwright-"`uname`".out"
  dir=`dirname "$1"`
  (cd "$dir" && runToFile "$NPM install --no-audit @playwright/test" "$pfile" "$VERBOSE") || return 1
  (cd "$dir" && runToFile "npx playwright install chromium" "$pfile" "$VERBOSE") || return 1
  isLinux && (cd "$dir" && runToFile "'${NODE}' ./node_modules/.bin/playwright install-deps chromium" "$pfile" "$VERBOSE") || true
}

## Check if playwright is installed, otherwise install it
checkPlaywrightInstallation() {
  [ -z "$UPDATE" ] || installPlaywright "$1" || return 1
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
  local test_file base_name ofile mode name version pfile args err H
  test_file="$1"
  base_name=`basename "$1"`
  ofile="$2"
  mode="$3"
  name="$4"
  version="$5"
  shift 5

  pfile="playwright-$version-$mode-"`uname`".out"
  [ -f "$test_file" ] && checkPlaywrightInstallation "$test_file" || return 0

  args="$* --name=$name --version=$version --mode=$mode"
  [ -n "$SCREENSHOTS" ] && args="$args --screenshots"

  isHeadless && args="$args --headless"
  log "Running visual test: $base_name"
  PATH=$PATH START=$START runToFile "'$NODE' '$test_file' $args" "$pfile" "$VERBOSE" true
  err=$?
  [ -n "$TEST" ] && return 0
  H=`grep ' > CONSOLE:' "$pfile" | perl -pe 's/(> CONSOLE: Received xhr.*?feat":).*/$1 .../g'`
  H=`echo "$H" | egrep -v 'Atmosphere|Vaadin push loaded|Websocket successfully opened|Websocket closed|404.*favicon.ico'`
  [ -n "$H" ] && [ "$mode" = "prod" ] && reportError "Console Warnings in $mode mode $5" "$H" && echo "$H"
  H=`egrep ' > (JSERROR|PAGEERROR):' "$pfile"`
  [ -n "$H" ] && reportError "Console Errors in $msg" "$H" && echo "$H" && return 1
  H=`tail -15 $pfile`
  [ $err != 0 ] && reportOutErrors "$ofile" "Error ($err) running Visual-Test ("`basename $pfile`")" || echo ">>>> PiT: playwright '$test_file' done" >> "$ofile"
  [ $err = 0 ] && rm -f "$pfile"
  return $err
}


