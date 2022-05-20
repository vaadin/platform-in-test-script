. `dirname $0`/lib/lib-validate.sh

## Checkout a
## multiple presets can be used by joining them with the `_` character
checkoutDemo() {
  _repo=$1
  _branch=""
  _gitUrl="https://github.com/vaadin/$_repo.git"
  log "Checking out $_gitUrl"
  git clone -q "$_gitUrl" || return 1
  [ -z "$_branch" ] || git checkout "$_branch"
}


## get the selenium IDE test file used for each demo
getDemoTestFile() {
  case $1 in
   *) echo "hello.side";;
  esac
}

getInstallCmdDev() {
  case $1 in
    skeleton-starter-flow-cdi|base-starter-flow-quarkus) echo "mvn -B clean";;
    base-starter-spring-gradle) echo "./gradlew clean" ;;
    *) echo "mvn clean install -Dpnpm.enable=true";;
  esac
}

getInstallCmdPrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "mvn -B package -Pproduction";;
    base-starter-flow-quarkus) echo "mvn -B package -Pproduction";;
    base-starter-spring-gradle) echo "./gradlew clean build -Pvaadin.productionMode";;
    *) getInstallCmdDev $1;;
  esac
}

getRunCmdDev() {
  case $1 in
    vaadin-flow-karaf-example) echo "mvn -B -pl main-ui install -Prun";;
    base-starter-flow-osgi) echo "java -jar app/target/app.jar";;
    skeleton-starter-flow-cdi) echo "mvn -B wildfly:run -Dpnpm.enable=true";;
    base-starter-spring-gradle) echo "./gradlew bootRun";;
    skeleton-starter-flow-spring|base-starter-flow-quarkus) echo "mvn -Dpnpm.enable=true";;
  esac
}

getRunCmdPrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "java -jar target/*.jar";;
    base-starter-flow-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    base-starter-spring-gradle) echo "java -jar ./build/libs/base-starter-spring-gradle-0.0.1-SNAPSHOT.jar";;
    *) getRunCmdDev $1;;
  esac
}

getPort() {
  case $1 in
    vaadin-flow-karaf-example) echo "8181";;
    *) echo "8080";;
  esac
}

getReadyMessageDev() {
  case $1 in
    base-starter-flow-osgi) echo "HTTP:8080";;
    *) echo "Frontend compiled successfully";;
  esac
}

getReadyMessagePrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "Started Application";;
    base-starter-flow-quarkus) echo "Listening on: http://0.0.0.0:8080";;
    base-starter-spring-gradle) echo "Tomcat started on port";;
    *) getReadyMessageDev $1;;
  esac
}

hasProduction() {
  case $1 in
    base-starter-flow-osgi|skeleton-starter-flow-cdi) return 1;;
    *) return 0;
  esac
}

setDemoVersion() {
  if [ "$1" = "base-starter-spring-gradle" ]
  then
    setGradleVersion vaadinVersion "$2"
  else
    setVersion vaadin.version "$2"
  fi
}

runDemo() {
  _demo="$1"
  _tmp="$2"
  _port="$3"
  _version="$4"
  _offline="$5"

  echo ""
  log "================= TESTING demo '$_demo' $_offline =================="

  cd "$_tmp" || return 1
  _dir="$_tmp/$_demo"
  if [ -z "$_offline" ]
  then
    [ -d "$_dir" ] && log "Removing project folder $_dir" && rm -rf $_dir
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
  _test=`getDemoTestFile $_demo`

  runValidations current $_demo $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1

  if setDemoVersion $_demo $_version
  then
    runValidations $_version $_demo $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    if hasProduction $_demo
    then
      runValidations $_version $_demo $_port "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
  log "==== demo '$_demo' was build and tested successfuly ====
  "
}
