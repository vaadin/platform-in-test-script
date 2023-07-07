. `dirname $0`/lib/lib-validate.sh
. `dirname $0`/lib/lib-patch.sh

## Checkout a branch of a vaadin repository in github
checkoutDemo() {
  _branch=`getGitBranch $1`
  _repo=`getGitRepo $1`
  _tk=${GITHUB_TOKEN:-${GHTK}}
  [ -n "$_tk" ] && __tk=${_tk}@
  _gitUrl="https://${__tk}${_repo}.git"
  log "Checking out $1"
  cmd "git clone https://$_repo.git"
  cmd "cd $1"
  [ -z "$VERBOSE" ] && _quiet="-q"
  git clone $_quiet "$_gitUrl" || return 1
  [ -z "$_branch" ] || (cd $1 && cmd "git checkout $_branch" && git checkout $_quiet "$_branch")
}
## returns the github repo URL of a demo
getGitRepo() {
  case $1 in
    mpr-demo) echo "github.com/TatuLund/$1";;
    *) echo "github.com/vaadin/$1";;
  esac
}
## returns the current branch of a demo
getGitBranch() {
  case $1 in
    mpr-demo) echo "mpr-7";;
  esac
}

commitChanges() {
  _app=$1; _vers=$2;

  git ls-remote --heads >/dev/null 2>&1 || return 0
  git update-index --refresh >/dev/null
  git diff-index --quiet HEAD -- && return 0

  _baseBranch=v`echo "$_vers" | cut -d '.' -f1`
  _headBranch="update-to-$_baseBranch"

  remotes=`git ls-remote --heads 2>/dev/null | grep refs | sed -e 's|.*refs/heads/||g' | egrep "^$_baseBranch$"`
  [ -n "$remotes" ] && log "Branch $_baseBranch already exists" || (log "Creating branch $_baseBranch" && git checkout -b $_baseBranch && git push) || return 1

  owner=`echo "$_repo" | cut -d / -f2`
  repo=`echo "$_repo" | cut -d / -f3-100`

  log "Creating $_headBranch branch, committing and pushing changes"
  git checkout -b $_headBranch
  git push origin $_headBranch -d 2>/dev/null
  git add `ls -1d src frontend */src */frontend pom.xml */pom.xml 2>/dev/null | tr "\n" " "`
  git commit -q -m "chore: update to $_vers" -a
  git push -q -f

  pr_url=`curl -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $_tk"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$owner/$repo/pulls \
    -d '{"title":"chore: Update Vaadin '$_vers'","head":"'$_headBranch'","base":"'$_baseBranch'"}' | jq -r '.html_url' 2>/dev/null`
  warn "Created PR $pr_url"
}

## Get install command for dev-mode
getInstallCmdDev() {
  case $1 in
    # base-starter-flow-quarkus|skeleton-starter-flow-cdi|mpr-demo|spreadsheet-demo) echo "$MVN -ntp -B clean $PNPM";;
    *-gradle) echo "$GRADLE clean" ;;
    *) echo "$MVN -ntp -B clean install -DskipTests $PNPM";;
  esac
}
## Get install command for prod-mode
getInstallCmdPrd() {
  H="-Dcom.vaadin.testbench.Parameters.testsInParallel=2 -Dmaven.test.redirectTestOutputToFile=true"
  isHeadless && H="-Dheadless" || H="-Dtest.headless=false" #for addon-template
  isHeadless && H="$H -Dcom.vaadin.testbench.Parameters.headless=true $H"
  [ -n "$SKIPTESTS" ] && H="$H -DskipTests"
  case $1 in
    *hilla*gradle) echo "$GRADLE clean build -Philla.productionMode $PNPM";;
    *-gradle) echo "$GRADLE clean build -Pvaadin.productionMode $PNPM";;
    *hilla*|base-starter-flow-quarkus|vaadin-form-example|flow-spring-examples|vaadin-oauth-example|layout-examples) echo "$MVN -B package -Pproduction $PNPM";;
    bakery-app-starter-flow-spring|skeleton-starter-flow-spring) echo "$MVN -B install -Pproduction,it $H $PNPM";;
    skeleton-starter-flow-cdi|k8s-demo-app) echo "$MVN -ntp -B verify -Pproduction $H $PNPM";;
    mpr-demo|spreadsheet-demo) echo "$MVN -ntp -B clean";;
    *) echo "$MVN -ntp -B clean install -Pproduction,it $H $PNPM";;
  esac
}
## Get command for running the project dev-mode after install was run
getRunCmdDev() {
  case $1 in
    vaadin-flow-karaf-example) echo "$MVN -ntp -B -pl main-ui install -Prun $PNPM";;
    base-starter-flow-osgi) echo "java -jar app/target/app.jar";;
    skeleton-starter-flow-cdi) echo "$MVN -ntp -B wildfly:run $PNPM";;
    base-starter-gradle) echo "$GRADLE jettyStart";; # should be appRun but reads from stdin and fails
    *-gradle) echo "$GRADLE bootRun";;
    mpr-demo) echo "$MVN -ntp -B -Dvaadin.spreadsheet.developer.license=${SS_LICENSE} jetty:run $PNPM";;
    multi-module-example) echo "$MVN -ntp -B spring-boot:run -pl vaadin-app";;
    *) echo "$MVN -ntp -B $PNPM";;
  esac
}
## Get command for running the project prod-mode after install was run
getRunCmdPrd() {
  case $1 in
    base-starter-gradle) echo "$GRADLE jettyStartWar";; # should be appRunWar but reads from stdin and fails
    *-spring-gradle|*hilla*gradle) echo "java -jar ./build/libs/*-gradle.jar";;
    *-gradle) echo "$GRADLE jettyStartWar";;
    *hilla*|k8s-demo-app|skeleton-starter-flow-spring|bakery-app-starter-flow-spring|vaadin-form-example|flow-spring-examples|vaadin-oauth-example) echo "java -jar target/*.jar";;
    base-starter-flow-quarkus) echo "java -jar target/quarkus-app/quarkus-run.jar";;
    skeleton-starter-flow-cdi) echo "$MVN -ntp -B wildfly:run -Pproduction $PNPM";;
    mpr-demo) echo "$MVN -ntp -B -Dvaadin.spreadsheet.developer.license=${SS_LICENSE} jetty:run-war -Pproduction $PNPM";;
    spreadsheet-demo|layout-examples|skeleton-starter-flow|business-app-starter-flow|bookstore-example) echo "$MVN -ntp -Pproduction -B jetty:run-war $PNPM";;
    *addon-template|addon-starter-flow) echo "$MVN -ntp -Pproduction -B jetty:run";;
    multi-module-example) echo "java -jar vaadin-app/target/*.jar";;
    *) echo "java -jar target/*.jar" ;;
  esac
}
## Get ready message when running the project in dev-mode
getReadyMessageDev() {
  case $1 in
    base-starter-flow-osgi) echo "HTTP:8080";;
    skeleton-starter-flow-cdi) echo "Vaadin is running in DEVELOPMENT mode";;
    skeleton-starter-flow-spring) echo "Started Application";; # frontend bundle built
    bakery-app-starter-flow-spring) echo "Started Application";; # frontend bundle built
    base-starter-flow-quarkus) echo "Listening on:";;
    vaadin-flow-karaf-example) echo "Artifact deployed";;
    spreadsheet-demo|layout-examples) echo "Started ServerConnector";;
    mpr-demo) echo "Vaadin is running in DEBUG MODE";;
    k8s-demo-app) echo "frontend bundle built|Started Vite";;
    *-gradle|flow-spring-examples) echo "Tomcat started|started and listening";;
    hilla-*-tutorial) echo "Started Vite";;
    *) echo "Frontend compiled successfully|Started Application|Started Server";;
  esac
}
## Get ready message when running the project in prod-mode
getReadyMessagePrd() {
  case $1 in
    skeleton-starter-flow-spring|k8s-demo-app) echo "Vaadin is running in production mode";;
    base-starter-flow-quarkus) echo "Listening on: http://0.0.0.0:8080";;
    bakery-app-starter-flow-spring) echo "Started Application";;
    skeleton-starter-flow-cdi) echo "Registered web contex";;
    mpr-demo|spreadsheet-demo) echo "Started ServerConnector";;
    *-gradle) echo "Tomcat started|started and listening";;
    hilla-*-tutorial) echo "Started Application";;
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
    skeleton*) echo "hello.js";;
    business-app-starter-flow|*hilla*) echo "noop.js";;
    bakery-app-starter-flow-spring);;
    mpr-demo) echo "mpr-demo.js";;
    spreadsheet-demo) echo "spreadsheet-demo.js";;
    k8s-demo-app) echo "k8s-demo.js";;
    vaadin-form-example|vaadin-rest-example|vaadin-localization-example|vaadin-database-example|layout-examples|flow-quickstart-tutorial|flow-spring-examples|flow-crm-tutorial|layout-examples|flow-quickstart-tutorial|vaadin-oauth-example|designer-tutorial|*addon-template|addon-starter-flow) echo "noop.js";;
    vaadin-oauth-example) echo "oauth.js";;
    bookstore-example) echo "bookstore.js";;
    *) echo "hello.js";;
  esac
}

## Change version in build files
setDemoVersion() {
  case "$1" in
    base-starter-flow-quarkus|mpr-demo)
       setVersion vaadin.version "$2" || return 1
       setFlowVersion "$2" false
       setMprVersion "$2" false
       ;;
    *)
      __prop=`computeProp $1`
      __vers=`computeVersion "$__prop" $2`
      if expr "$1" : ".*gradle" >/dev/null
      then
        setGradleVersion $__prop $__vers
      else
        setVersion $__prop $__vers
      fi
      ;;
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
  MVN=mvn
  GRADLE=gradle
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

  computeMvn
  computeGradle

  printVersions || return 1

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
    applyPatches $_demo current $_current dev || return 1
    if hasDev $_demo; then
      # 2
      runValidations dev "$_current" "$_demo" "$_port" "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 3
      runValidations prod "$_current" "$_demo" "$_port" "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
  # 4
  if setDemoVersion $_demo $_version >/dev/null || [ -n "$NOCURRENT" ]
  then
    applyPatches $_demo next $_version prod || return 1
    if hasDev $_demo; then
      # 5
      runValidations dev "$_version" "$_demo" "$_port" "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 6
      runValidations prod "$_version" "$_demo" "$_port" "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
      [ -z "$COMMIT" ] || commitChanges $_demo $_version
    fi
  fi
}
