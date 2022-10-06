. `dirname $0`/lib/lib-validate.sh
. `dirname $0`/lib/lib-patch.sh

## Checkout a bramch of a vaadin repository in github
checkoutDemo() {
  _repo=$1
  _branch=""
  _gitUrl="https://github.com/vaadin/$_repo.git"
  log "Checking out (git clone $_gitUrl && cd $_repo)"
  [ -z "$VERBOSE" ] && _quiet="-q"
  git clone $_quiet "$_gitUrl" || return 1
  [ -z "$_branch" ] || git checkout "$_branch"
}


## Get install command for dev-mode
getInstallCmdDev() {
  case $1 in
    skeleton-starter-flow-cdi|base-starter-flow-quarkus) echo "mvn -ntp -B clean";;
    base-starter-spring-gradle) echo "./gradlew clean" ;;
    *) echo "mvn -ntp clean install $PNPM";;
  esac
}
## Get install command for prod-mode
getInstallCmdPrd() {
  H="-Dcom.vaadin.testbench.Parameters.testsInParallel=2 -Dmaven.test.redirectTestOutputToFile=true"
  isHeadless && H="$H -Dheadless"
  [ -n "$SKIPTESTS" ] && H="$H -DskipTests"
  case $1 in
    bakery-app-starter-flow-spring|skeleton-starter-flow-spring|base-starter-flow-quarkus) echo "mvn -B install -Pproduction,it $H";;
    base-starter-spring-gradle) echo "./gradlew clean build -Pvaadin.productionMode";;
    *) getInstallCmdDev $1;;
  esac
}
## Get command for running the project dev-mode after install was run
getRunCmdDev() {
  case $1 in
    vaadin-flow-karaf-example) echo "mvn -ntp -B -pl main-ui install -Prun";;
    base-starter-flow-osgi) echo "java -jar app/target/app.jar";;
    skeleton-starter-flow-cdi) echo "mvn -ntp -B wildfly:run $PNPM";;
    base-starter-spring-gradle) echo "./gradlew bootRun";;
    skeleton-starter-flow-spring|base-starter-flow-quarkus|bakery-app-starter-flow-spring) echo "mvn $PNPM";;
  esac
}
## Get command for running the project prod-mode after install was run
getRunCmdPrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "java -jar target/*.jar";;
    base-starter-flow-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    base-starter-spring-gradle) echo "java -jar ./build/libs/base-starter-spring-gradle-0.0.1-SNAPSHOT.jar";;
    *) getRunCmdDev $1;;
  esac
}
## Get ready message when running the project in dev-mode
getReadyMessageDev() {
  case $1 in
    base-starter-flow-osgi) echo "HTTP:8080";;
    skeleton-starter-flow-cdi) echo "Registered web context";;
    base-starter-flow-quarkus) echo "TaskCopyFrontendFiles";;
    vaadin-flow-karaf-example) echo "Artifact deployed";;
    *) echo "Frontend compiled successfully";;
  esac
}
## Get ready message when running the project in prod-mode
getReadyMessagePrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "Vaadin is running in production mode";;
    base-starter-flow-quarkus) echo "Listening on: http://0.0.0.0:8080";;
    base-starter-spring-gradle) echo "Tomcat started on port";;
    *) getReadyMessageDev $1;;
  esac
}
## Check whether a demo can be run in prod-mode
hasProduction() {
  [ -n "$NOPROD" ] && return 1
  case $1 in
    base-starter-flow-osgi|skeleton-starter-flow-cdi|vaadin-flow-karaf-example) return 1;;
    *) return 0;
  esac
}
hasDev() {
  test -z "$NODEV"
}
## Get the default port used in each demo
getPort() {
  case $1 in
    vaadin-flow-karaf-example) echo "8181";;
    *) echo "8080";;
  esac
}
## Get SIDE test file
getTest() {
  case $1 in
    bakery-app-starter-flow-spring);;
    *) echo "hello.js"
  esac
}

## Change version in build files
setDemoVersion() {
  case "$1" in
    base-starter-spring-gradle) setGradleVersion vaadinVersion "$2";;
    *) setVersion vaadin.version "$2";;
  esac
}

## Run a Demo project by following the next steps
# 1. checkout the project from github (if not in offline)
# 2. run validations in the current version to check that it's not broken
# 3. run validations for the current version in prod-mode (if project can be run in prod and dev)
# 4. increase version to the version used for PiT (if version given)
# 5. run validations for the new version in dev-mode
# 6. run validations for the new version in prod-mode (if project can be run in prod and dev)
runDemo() {
  _demo="$1"
  _tmp="$2"
  _port="$3"
  _version="$4"
  _offline="$5"

  cd "$_tmp" || return 1
  _dir="$_tmp/$_demo"
  if [ -z "$_offline" ]
  then
    [ -d "$_dir" ] && log "Removing project folder $_dir" && rm -rf $_dir
    # 1
    checkoutDemo $_demo || return 1
  fi
  cd "$_dir" || return 1

  _installCmdDev=`getInstallCmdDev $_demo`
  _installCmdPrd=`getInstallCmdPrd $_demo`
  _runCmdDev=`getRunCmdDev $_demo`
  _runCmdPrd=`getRunCmdPrd $_demo`
  _readyDev=`getReadyMessageDev $_demo`
  _readyPrd=`getReadyMessagePrd $_demo`
  _port=`getPort $_demo`
  _test=`getTest $_demo`

  if [ -z "$NOCURRENT" ]
  then
    _current=`setDemoVersion $_demo current`
    patchKarafLicenseOsgi
    if hasDev $_demo; then
      # 2
      runValidations dev $_current $_demo $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 3
      runValidations prod $_current $_demo $_port "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
  # 4
  if setDemoVersion $_demo $_version >/dev/null
  then
    patchKarafLicenseOsgi
    if hasDev $_demo; then
      # 5
      runValidations dev $_version $_demo $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 6
      runValidations prod $_version $_demo $_port "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
}
