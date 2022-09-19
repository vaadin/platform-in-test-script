## Check whether selenium-side-runner and chromedriver executables are available in the PATH
isInstalledSelenium() {
  type selenium-side-runner >/dev/null 2>&1 || return 1
  [ -n "$USEHUB" ] || type chromedriver >/dev/null 2>&1
}

installSelenium() {
  log "installing selenium-side-runner"
  npm install -g selenium-side-runner || return 1
  [ -n "$USEHUB" ] || npm install -g chromedriver
}

## Check if selenium-side-runner is installed, otherwise ask for installing it
checkSeleniumInstallation() {
  [ -n "$UPDATE" ] && installSelenium
  isInstalledSelenium && return 0
  ask "Do you want to install selenium-side-runner ? [y] "
  [ -z "$key" -o "$key" = "y" ] || return 1
  installSelenium
}

## Run Selenium tests
runSeleniumTests() {
  # The JSON file produced by Selenium IDE
  _file=$1
  [ -f "$_file" ] && checkSeleniumInstallation || return 0
  log "Running Selenium IDE test from file: $_file"

  # workaround for chromedrive PATH in windows (when using ssh or bash terminal)
  _win_driver=/c/Users/tester/AppData/Roaming/npm/node_modules/chromedriver/lib/chromedriver
  [ -d "$_win_driver" ] && export PATH="$_win_driver:$PATH"
  
  IP=`hostname -i 2>/dev/null`
  [ -z "$IP" ] && IP="host.docker.internal"
  [ -n "$USEHUB" ] && _hub="--server http://localhost:4444 --base-url http://$IP:8080"

  # if not verbose it runs tests in headless mode
  if [ -z "$VERBOSE" ]
  then
    _out=`basename $_file`".out"
    log "selenium-side-runner $_file $_hub -c 'goog:chromeOptions.args=[--headless,--nogpu,--no-sandbox,--disable-dev-shm-usage] browserName=chrome'"
    selenium-side-runner $_file $_hub -c 'goog:chromeOptions.args=[--headless,--nogpu,--no-sandbox,--disable-dev-shm-usage] browserName=chrome' > $_out 2>&1
    [ $? != 0 ] && cat $_out && return 1 || return 0
  else
    log "selenium-side-runner $_file $_hub"
    selenium-side-runner $_file $_hub
  fi
}

