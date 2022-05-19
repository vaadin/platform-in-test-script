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
    skeleton-starter-flow-cdi|base-starter-flow-quarkus) echo "mvn clean";;
    base-starter-spring-gradle) echo "./gradlew clean" ;;
    *) echo "mvn clean install -Dpnpm.enable=true";;
  esac
}

getInstallCmdPrd() {
  case $1 in
    skeleton-starter-flow-spring) echo "mvn package -Pproduction";;
    base-starter-flow-quarkus) echo "mvn package -Pproduction";;
    base-starter-spring-gradle) echo "./gradlew clean build -Pvaadin.productionMode";;
    *) getInstallCmdDev $1;;
  esac
}

getRunCmdDev() {
  case $1 in
    vaadin-flow-karaf-example) echo "mvn -pl main-ui install -Prun";;
    base-starter-flow-osgi) echo "java -jar app/target/app.jar";;
    skeleton-starter-flow-cdi) echo "mvn wildfly:run -Dpnpm.enable=true";;
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

runDemos() {
  _demos="$1"
  _port="$2"
  _version="$3"
  _offline="$4"

  pwd="$PWD"
  tmp="$pwd/starters"
  mkdir -p "$tmp"

  for i in $_demos
  do
    echo ""
    log "================= TESTING Demo '$i' $_offline =================="
    cd "$tmp"
    dir="$tmp/$i"
    if [ -z "$_offline" ]
    then
      [ -d "$dir" ] && log "Removing project folder $dir" && rm -rf $dir
      checkoutDemo $i || exit 1
    fi
    cd "$dir" || exit 1

    _installCmdDev=`getInstallCmdDev $i`
    _installCmdPrd=`getInstallCmdPrd $i`
    _runCmdDev=`getRunCmdDev $i`
    _runCmdPrd=`getRunCmdPrd $i`
    _readyDev=`getReadyMessageDev $i`
    _readyPrd=`getReadyMessagePrd $i`
    _port=`getPort $i`
    _test=`getDemoTestFile $i`

    runValidations current $i $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || exit 1

    if setDemoVersion $i $_version
    then
      runValidations $_version $i $_port "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || exit 1
      if hasProduction $i
      then
        runValidations $_version $i $_port "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || exit 1
      fi
    fi
    log "==== Demo '$i' was Tested successfuly ====
    "
  done
}
