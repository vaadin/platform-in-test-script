. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-demos.sh

CC_APP_REPO=bakery-app-starter-flow-spring:cc-24.7
CC_BAKERY_APP=bakery
CC_STARTER_APP=cc-starter

## Compile bakery application, with and without CC support
compileBakery() {
  APP=$CC_BAKERY_APP
  log -n "* Building $APP & $APP-cc apps *"
  computeMvn
  checkoutDemo $CC_APP_REPO || return 1
  setDemoVersion $CC_APP_REPO $VERSION >/dev/null || return 1
  applyPatches $APP next "$VERSION" prod || return 1
  setMvnDependencyVersion com.vaadin control-center-starter "$CCVERSION" "-Pcontrol-center" || return 1
  runToFile "'$MVN' -ntp -B clean install -Pproduction -DskipTests" "compile-$APP.out" "$VERBOSE" || return 1
  runCmd "Building Docker image for $APP" docker build -t $REGISTRY/$APP:local .  || return 1
  runToFile "'$MVN' -ntp -B clean install -Pproduction,control-center -DskipTests" "compile-$APP-cc.out" "$VERBOSE" || return 1
  runCmd "Building Docker image for $APP-CC" docker build -t $REGISTRY/$APP-cc:local .  || return 1
}

## Compile a starter downloaded from start wizard with most interesting presets selected
compileCCStarter() {
  APP=$CC_STARTER_APP
  log -n "* Building $APP app *"
  computeMvn
  PRESETS=""
  APPS="latest-java partial-auth partial-controlcenter partial-kubernetes partial-prerelease partial-hilla-example-views partial-flow-example-auth-views partial-hilla-example-auth-views"
  APPS="latest-java partial-auth partial-controlcenter partial-kubernetes partial-prerelease partial-hilla-example-views"
  for i in $APPS
  do
    PRESETS="$PRESETS&preset=$i"
  done
  _url="https://start.vaadin.com/dl?$PRESETS&projectName=$APP"
  _zip="$APP.zip"
  _dir="$APP"
  [ -z "$VERBOSE" ] && _silent="-s"
  if [ -n "$OFFLINE" -a -d "$APP" ]; then
    runCmd -f "Reseting local changes in $APP" "git --git-dir=$APP/.git --work-tree=$APP reset --hard HEAD" || return 1
  else
    [ -d "$APP" ] && runCmd -f "Removing folder $APP" rm -rf $APP
    runCmd -f "Downloading $1" "curl $_silent -f '$_url' -o '$_zip'" || return 1
    runCmd -f "Unzipping $_name" "unzip -q '$_zip'" && rm -f "$_zip" || return 1
  fi

  cmd "cd '$_dir'" && cd "$_dir" || return 1
  setVersion vaadin.version "$VERSION" >/dev/null || return 1
  applyPatches $APP "" $VERSION "" || return 1
  setMvnDependencyVersion com.vaadin control-center-starter "$CCVERSION" || return 1
  runToFile "'$MVN' -ntp clean package -Pproduction" "compile_$APP.out" "$VERBOSE" || return 1
  runCmd "Building Docker image for $APP" docker build -t $REGISTRY/$APP:local .  || return 1
}

## compile and install in local maven repo control center
compileCC() {
  V=`mvn help:evaluate -Dexpression=project.version -q -DforceStdout`
  [ "$CCVERSION" != "$V" ] && err "Version does not match pomVersion: $V ccVersion: $CCVERSION" && return 1
  log -n "* Building Control Center version ${V} *"
  computeMvn
  local D="-q -ntp"
  [ -z "$VERBOSE" ] && D="-Dorg.slf4j.simpleLogger.showDateTime -Dorg.slf4j.simpleLogger.dateTimeFormat=HH:mm:ss.SSS"
  runToFile "'$MVN' $D -B -pl :control-center-app -Pproduction -DskipTests -am install" "compile-ccapp.out" "$VERBOSE" || return 1
  runToFile "'$MVN' $D -B -pl :control-center-app -Pproduction -Ddocker.tag=local docker:build" "build-ccapp-docker.out" "$VERBOSE" || return 1
  runToFile "'$MVN' $D -B -pl :control-center-keycloak package -Ddocker.tag=local docker:build" "build-cckeycloak-docker.out" "$VERBOSE" || return 1
}

## Build Apps used in CC and CC itself if testing the snapshot
# $1 whether CC version is snapshot or not
buildCC() {
  log -n "** Building Control Center and APPS - $VERSION $CCVERSION $1 **"
  local D=$PWD
  if [ -z "$SKIPBUILD" ]; then
    [ "$1" != true ] || compileCC || return 1 ; cd $D
    compileCCStarter || return 1 ; cd $D
    compileBakery || return 1 ; cd $D
  fi
  [ -n "$SKIPHELM" -o "$1" != true ] || runCmd -q "Update helm dependencies" helm dependency build charts/control-center
  prepareRegistry || return 1
  uploadLocalImages "$1" || return 1
  [ -z "$CCPUSH" ] || pushLocalToDockerhub next
}








