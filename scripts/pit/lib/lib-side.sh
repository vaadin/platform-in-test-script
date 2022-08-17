## Check whether selenium-side-runner and chromedriver executables are available in the PATH
isInstalledSelenium() {
  type selenium-side-runner >/dev/null 2>&1 && type chromedriver >/dev/null 2>&1
}

installSelenium() {
  log "installing selenium-side-runner"
  npm install -g selenium-side-runner chromedriver
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

  # if not verbose it runs tests in headless mode
  if [ -z "$VERBOSE" ] 
  then
    _out=`basename $_file`".out"
    selenium-side-runner $_file -c "goog:chromeOptions.args=[--headless,--nogpu] browserName=chrome" > $_out 2>&1
    [ $? != 0 ] && cat $_out && return 1 || return 0
  else
    selenium-side-runner $_file 
  fi
}

