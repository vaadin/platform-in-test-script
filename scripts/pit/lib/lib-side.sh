
isInstalledSelenium() {
  type selenium-side-runner >/dev/null 2>&1 && type chromedriver >/dev/null 2>&1
}

checkSeleniumInstallation() {
  isInstalledSelenium && return 0
  ask "Do you want to install selenium-side-runner ? [y] "
  [ -z "$key" -o "$key" = "y" ] || return 1
  log "installing selenium-side-runner"
  npm install -g selenium-side-runner chromedriver
}

runSeleniumTests() {
  _file=$1
  [ -f "$_file" ] && checkSeleniumInstallation || return 0
  log "Running Selenium IDE test from file: $_file"
  if [ -z "$VERBOSE" ] 
  then
    selenium-side-runner $_file -c "goog:chromeOptions.args=[--headless,--nogpu] browserName=chrome"
  else
    selenium-side-runner $_file 
  fi
}

