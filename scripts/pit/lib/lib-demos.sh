. `dirname $0`/lib/lib-validate.sh
. `dirname $0`/lib/lib-patch.sh

## Checkout a bramch of a vaadin repository in github
checkoutDemo() {
  _branch=`getGitBranch $1`
  _repo=`getGitRepo $1`
  _tk=${GITHUB_TOKEN:-${GHTK}}
  [ -n "$_tk" ] && _tk=${_tk}@
  _gitUrl="https://${_tk}${_repo}.git"
  log "Checking out $1"
  cmd "git clone https://$_repo.git"
  cmd "cd $1"
  [ -z "$VERBOSE" ] && _quiet="-q"
  git clone $_quiet "$_gitUrl" || return 1
  [ -z "$_branch" ] || (cd $1 && cmd "git checkout $_branch" && git checkout $_quiet "$_branch")
}
getGitRepo() {
  case $1 in
    mpr-demo) echo "github.com/TatuLund/$1";;
    *) echo "github.com/vaadin/$1";;
  esac
}
getGitBranch() {
  case $1 in
    mpr-demo) echo "mpr-6";;
  esac
}

## Get install command for dev-mode
getInstallCmdDev() {
  case $1 in
    base-starter-flow-quarkus|skeleton-starter-flow-cdi|mpr-demo) echo "mvn -ntp -B clean";;
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
    skeleton-starter-flow-cdi|k8s-demo-app) echo "mvn -ntp -B verify -Pproduction $H";;
    mpr-demo) echo "mvn -ntp -B clean";;
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
    mpr-demo) echo "mvn -ntp -B -Dvaadin.spreadsheet.developer.license=447a9e11-c69c-402c-87ec-720e6c4cf9ea jetty:run";;
    *) echo "mvn -ntp -B $PNPM";;
  esac
}
## Get command for running the project prod-mode after install was run
getRunCmdPrd() {
  case $1 in
    k8s-demo-app|skeleton-starter-flow-spring|bakery-app-starter-flow-spring) echo "java -jar target/*.jar";;
    base-starter-flow-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    skeleton-starter-flow-cdi) echo "mvn -ntp -B wildfly:run -Pproduction $PNPM";;
    base-starter-spring-gradle) echo "java -jar ./build/libs/base-starter-spring-gradle-0.0.1-SNAPSHOT.jar";;
    mpr-demo) echo "mvn -ntp -B -Dvaadin.spreadsheet.developer.license=447a9e11-c69c-402c-87ec-720e6c4cf9ea jetty:run-war -Pproduction";;
    *) getRunCmdDev $1;;
  esac
}
## Get ready message when running the project in dev-mode
getReadyMessageDev() {
  case $1 in
    base-starter-flow-osgi) echo "HTTP:8080";;
    skeleton-starter-flow-cdi) echo "Started Vite";;
    base-starter-flow-quarkus) echo "TaskCopyFrontendFiles";;
    vaadin-flow-karaf-example) echo "Artifact deployed";;
    *) echo "Frontend compiled successfully";;
  esac
}
## Get ready message when running the project in prod-mode
getReadyMessagePrd() {
  case $1 in
    skeleton-starter-flow-spring|k8s-demo-app) echo "Vaadin is running in production mode";;
    base-starter-flow-quarkus) echo "Listening on: http://0.0.0.0:8080";;
    base-starter-spring-gradle|bakery-app-starter-flow-spring) echo "Tomcat started on port";;
    skeleton-starter-flow-cdi) echo "Registered web contex";;
    mpr-demo) echo "Started ServerConnector";;
    *) getReadyMessageDev $1;;
  esac
}
## Check whether a demo can be run in prod-mode
hasProduction() {
  [ -n "$NOPROD" ] && return 1
  case $1 in
    base-starter-flow-osgi|vaadin-flow-karaf-example) return 1;;
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
    mpr-demo) echo "mpr-demo.js";;
    k8s-demo-app) echo "k8s-demo.js";;
    *) echo "hello.js"
  esac
}

## Change version in build files
setDemoVersion() {
  case "$1" in
    base-starter-spring-gradle) setGradleVersion vaadinVersion "$2";;
    mpr-demo)
       if [ "$2" != current ]; then
         B=`echo $2 | cut -d . -f1,2`
         FLOWVERSION=`getFlowVersionFromPlatform $B`
         [ -z "$FLOWVERSION" ] && FLOWVERSION=`getFlowVersionFromPlatform master`
         setVersion flow.version "$FLOWVERSION"
       fi
       setVersion vaadin.version "$2";;
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
    applyPatches $_demo current
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
    applyPatches $_demo next
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
