## LIBRARY for testing demos that exist in github

. `dirname $0`/lib/lib-validate.sh
. `dirname $0`/lib/lib-patch.sh

## Checkout a branch of a vaadin repository in github
## we add GITHUB_TOKEN or GHTK environment variable to the URL
## $1: the name of the demo in the form of `repo[:branch][/folder]`
checkoutDemo() {
  _demo=`getGitDemo $1`
  _branch=`getGitBranch $1`
  _folder=`getGitFolder $1`
  _workdir="$_demo$_folder"
  _repo=`getGitRepo $1`
  _tk=${GITHUB_TOKEN:-${GHTK}}
  _base=${GITBASE:-https://gitub.com/}
  [ -n "$_tk" ] && _base=`echo "$_base" | sed -e 's|\(https://\)|\\1'$_tk'@|'`
  _gitUrl="${_base}${_repo}.git"
  [ -z "$VERBOSE" ] && _quiet="-q"
  if [ -z "$_offline" -o ! -d "$_workdir" ]
  then
    [ ! -d "$_demo" ] || runCmd -qf "Removing preexisting folder $_demo" "rm -rf $_demo" || return 1
    runCmd -f "Cloning repository $_repo" "git clone $_quiet $_gitUrl" || return 1
  else
    : ## TODO reset git
  fi
  cmd "cd $_workdir"
  cd "$_workdir"
  [ -z "$_branch" ] || (cmd "git checkout $_branch" && git checkout $_quiet "$_branch")
}
## returns the github repo URL of a demo
getGitRepo() {
  _repo=`echo $1 | cut -d : -f1`
  case $_repo in
    */*) echo $_repo | cut -d / -f1,2 ;;
    *) echo "vaadin/"`echo $_repo` ;;
  esac
}
## returns the current branch of a demo
getGitBranch() {
  case $1 in
    *:*) echo echo $1 | cut -d ":" -f2 ;;
  esac
}
## returns the folder with the demo in the repo
getGitFolder() {
  _repo=`echo $1 | cut -d : -f1`
  case $_repo in
    */*/*) echo "/"`echo $_repo | cut -d / -f3` ;;
  esac
}
## returns the name for the demo
getGitDemo() {
  _repo=`echo $1 | cut -d : -f1`
  case $_repo in
    */*) echo $_repo | cut -d / -f2 ;;
    *)   echo "$_repo" ;;
  esac
}

## commit changes performed during testing on fhe next version
## it should happend after first estable version is released e.g. 24.4.0
## $1: the name of the demo
## $2: the version of the demo
## $3: the command to compile the project for production so that package files etc, are updated
commitChanges() {
  _app=$1; _vers=$2; _compile="$3"

  case $_app in
    skeleton-starter-flow-spring|skeleton-starter-hilla-lit|skeleton-starter-hilla-react|start)
      return;;
  esac

  git ls-remote --heads >/dev/null 2>&1 || return 0
  git update-index --refresh >/dev/null
  git diff-index --quiet HEAD -- && return 0

  _baseBranch=v`echo "$_vers" | cut -d '.' -f1`
  _headBranch="update-to-$_baseBranch"
  _gaBranch="$_baseBranch.0"
  _tmpBranch="$_baseBranch.tmp"
  owner=`echo "$_repo" | cut -d / -f2`
  repo=`echo "$_repo" | cut -d / -f3-100`

  remotes=`git ls-remote --heads 2>/dev/null | grep refs | sed -e 's|.*refs/heads/||g' | egrep "^$_headBranch$"`
  if [ -n "$remotes" ]; then
    log "Branch $_app:$_headBranch already exists checkit and update it manually"
    return 0
  fi

  baseremote=`git ls-remote --heads 2>/dev/null | grep refs | sed -e 's|.*refs/heads/||g' | egrep "^$_baseBranch$"`
  if [ -z "$baseremote" ]; then
    log "Branch $_app:$_baseBranch does not already exit create it before tyring to commit changes"
    log "Creating branch $_baseBranch"
    _currBranch=`git branch  --show-current`
    git push -q -f origin $_currBranch:$_baseBranch || exit 1
    # git push -q origin :$_baseBranch || exit 1
  fi


  log "Committing and pushing changes"
  git checkout -q -b $_tmpBranch
  git add -- `ls -1d frontend */frontend src */src */src/main/frontend pom.xml */pom.xml 2>/dev/null | tr "\n" " "` ':!generated'
  git restore --staged `ls -1d pom.xml */pom.xml 2>/dev/null`

  if [ -n "$remotes" ]; then
    if git diff --quiet origin/$_headBranch; then
      log "No new changes to commit in $_app:$_headBranch"
      return 0
    fi
  fi

  if [ -n "$TEST" -a -n "$_compile" ]; then
    log "Compiling for production to update package files ..."
    cmd "$_compile"
    $_compile  > mvn.log 2>&1
    log "Exit status: $?"
  fi

  git commit -q -m "chore: update to $_vers" -a
  [ -n "$remotes" ] && git rebase origin/$_headBranch 2>/dev/null
  git push -q -f origin $_tmpBranch:$_headBranch 2>/dev/null
  if [ -n "$remotes" ]
  then
    log "PR for $_headBranch branch already exists"
  else
    log "Creating PR for $_headBranch branch"
    pr_url=`curl -s -L \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $_tk"\
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/repos/$owner/$repo/pulls \
      -d '{"title":"chore: PiT - Update to Vaadin '$_baseBranch'","head":"'$_headBranch'","base":"'$_baseBranch'","body":"Created by PiT Script"}' | jq -r '.html_url' 2>/dev/null`
    warn "$_app Created PR $pr_url"
  fi
}

## Get install command for dev-mode
getInstallCmdDev() {
  case $1 in
    *-gradle) echo "$GRADLE clean" ;;
    multi-module-example) echo "$MVN -ntp -B clean install -DskipTests $PNPM";;
    start) echo "rm -rf package-lock.json node_modules target frontend/generated; $MVN -ntp -B clean";;
    *) echo "$MVN -ntp -B clean -DskipTests $PNPM";;
  esac
}
## Get install command for prod-mode
getInstallCmdPrd() {
  H="-Dcom.vaadin.testbench.Parameters.testsInParallel=2"
  [ -z "$MAVEN_ARGS" ] &&  H="$H -Dmaven.test.redirectTestOutputToFile=true"
  isHeadless && H="$H -Dcom.vaadin.testbench.Parameters.headless=true -Dheadless" || H="$H -Dtest.headless=false" #for addon-template
  [ -n "$SKIPTESTS" ] && H="$H -DskipTests"
  case $1 in
    *-gradle)
      expr "$_version" : '2\.' >/dev/null && H="-hilla.productionMode" || H="-Pvaadin.productionMode"
      echo "$GRADLE clean build $H $PNPM";;
    *-quarkus) echo "$MVN -ntp -B clean package -Pproduction $H $PNPM -Dquarkus.analytics.disabled=true";;
    *hilla*|vaadin-form-example|flow-spring-examples|vaadin-oauth-example|layout-examples) echo "$MVN -ntp -B package -Pproduction $PNPM";;
    bakery-app-starter-flow-spring|skeleton-starter-flow-spring) echo "$MVN -ntp -B install -Pproduction,it $H $PNPM";;
    skeleton-starter-flow-cdi|k8s-demo-app) echo "$MVN -ntp -B verify -Pproduction $H $PNPM";;
    mpr-demo|spreadsheet-demo) echo "$MVN -ntp -B clean";;
    start) echo "$MVN -ntp -B install -Dmaven.test.skip -Pcircleci" ;;
    spring-petclinic-vaadin-flow) echo "$MVN -ntp -B install -Pproduction,it -DskipTests";;
    form-filler-demo) echo "$MVN -ntp -B clean install -Pproduction,it $H $PNPM -DOPENAI_TOKEN=$OPENAI_TOKEN";;
    testbench-demo) echo "$MVN -ntp -B clean install -Pproduction,it $H $PNPM -Dselenium.version=4.19.1";;
    *) echo "$MVN -ntp -B clean install -Pproduction,it $H $PNPM";;
  esac
}
## Get command for running the project dev-mode after install was run
getRunCmdDev() {
  case $1 in
    vaadin-flow-karaf-example) echo "$MVN -ntp -B -pl main-ui install -Prun $PNPM";;
    *-quarkus) echo "$MVN -ntp -B $PNPM -Dquarkus.analytics.disabled=true";;
    base-starter-flow-osgi) echo "java -jar app/target/app.jar";;
    skeleton-starter-flow-cdi) echo "$MVN -ntp -B wildfly:run $PNPM";;
    base-starter-gradle) echo "$GRADLE jettyStart";; # should be appRun but reads from stdin and fails
    *-gradle) echo "$GRADLE bootRun";;
    mpr-demo|testbench-demo) echo "$MVN -ntp -B jetty:run $PNPM";;
    multi-module-example) echo "$MVN -ntp -B spring-boot:run -pl vaadin-app";;
    spring-petclinic-vaadin-flow|gs-crud-with-vaadin) echo "$MVN -ntp -B spring-boot:run";;
    form-filler-demo) echo "$MVN -ntp -B $PNPM -DOPENAI_TOKEN=$OPENAI_TOKEN";;
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
    mpr-demo|spreadsheet-demo|layout-examples|skeleton-starter-flow|business-app-starter-flow|bookstore-example|testbench-demo) echo "$MVN -ntp -Pproduction -B jetty:run-war $PNPM";;
    *addon-template|addon-starter-flow) echo "$MVN -ntp -Pproduction -B jetty:run";;
    multi-module-example) echo "java -jar vaadin-app/target/*.jar";;
    ce-demo) echo "java -Dvaadin.ce.dataDir=. -jar target/*.jar";;
    start)
      H=""
      for i in api code file parser tree util ; do
        H="$H --add-exports=jdk.compiler/com.sun.tools.javac.$i=ALL-UNNAMED"
      done
      echo "java $H -jar target/*.jar";;
    form-filler-demo) echo "java -DOPENAI_TOKEN=$OPENAI_TOKEN -jar target/*.jar";;
    *) echo "java -jar target/*.jar" ;;
  esac
}
## Get ready message when running the project in dev-mode
getReadyMessageDev() {
  case $1 in
    base-starter-flow-osgi) echo "HTTP:8080";;
    skeleton-starter-flow-cdi) echo "Vaadin is running in DEVELOPMENT mode";;
    skeleton-starter-flow-spring|bakery-app-starter-flow-spring) echo "Started Application";;
    base-starter-flow-quarkus) echo "Listening on:";;
    vaadin-flow-karaf-example) echo "Artifact deployed";;
    spreadsheet-demo|layout-examples) echo "Started ServerConnector";;
    mpr-demo) echo "Vaadin is running in DEBUG MODE";;
    start) echo "Application running at http:";;
    *-gradle|flow-spring-examples) echo "Tomcat started|started and listening";;
    *) echo "Frontend compiled successfully|Started .*Application|Started Server";;
  esac
}
## Get ready message when running the project in prod-mode
getReadyMessagePrd() {
  case $1 in
    skeleton-starter-flow-spring|k8s-demo-app) echo "Vaadin is running in production mode";;
    base-starter-flow-quarkus) echo "Listening on: http://0.0.0.0:8080";;
    skeleton-starter-flow-cdi) echo "Registered web contex";;
    mpr-demo|spreadsheet-demo) echo "Started ServerConnector";;
    *-gradle) echo "Tomcat started|started and listening";;
    client-server-addon-template) echo 'Started ServerConnector.*:8080}';;
    bakery*|hilla-*-tutorial|start) echo "Started .*Application|Started Server";;
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
    bakery-app-starter-flow-spring);;
    mpr-demo) echo "mpr-demo.js";;
    spreadsheet-demo) echo "spreadsheet-demo.js";;
    k8s-demo-app) echo "k8s-demo.js";;
    business-app-starter-flow|*hilla*|spring-petclinic-vaadin-flow|gs-crud-with-vaadin|vaadin-form-example|vaadin-rest-example|vaadin-localization-example|vaadin-database-example|layout-examples|flow-quickstart-tutorial|flow-spring-examples|flow-crm-tutorial|layout-examples|flow-quickstart-tutorial|vaadin-oauth-example|designer-tutorial|*addon-template|addon-starter-flow|testbench-demo) echo "noop.js";;
    start) echo "start-wizard.js";;
    vaadin-oauth-example) echo "oauth.js";;
    bookstore-example) echo "bookstore.js";;
    form-filler-demo) echo "ai.js";;
    *) echo "hello.js";;
  esac
}

## Change version in build files
## $1: name of the demo
## $2: version to set
setDemoVersion() {
  case "$1" in
    base-starter-flow-quarkus|mpr-demo)
       if setVersion vaadin.version "$2"; then
        setFlowVersion "$2"
        [ "$1" = mpr-demo ] && setMprVersion "$2"
        return 0
       else
        return 1
       fi
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
# 0. compute variables and make preparations
# 1. checkout the project from github (if not in offline)
#    then compute other properties based in the sources
# 2. apply patches to the project for the dev-mode if needed
# 3. run validations in the current version to check that it's not broken
# 4. run validations for the current version in prod-mode (if project can be run in prod and dev)
# 5. increase version to the version used for PiT (if version given)
# 6. run validations for the new version in dev-mode
# 7. run validations for the new version in prod-mode (if project can be run in prod and dev)
runDemo() {
  MVN=mvn
  GRADLE=gradle
  _demo=`getGitDemo $1`
  _tmp="$2"
  _port="$3"
  _version="$4"
  _offline="$5"

  cd "$_tmp" || return 1

  _dir="$_tmp/$_demo"

  # 1
  checkoutDemo $1 || return 1

  computeMvn
  computeGradle

  printVersions || return 1

  _installCmdDev=`getInstallCmdDev $_demo`
  _installCmdPrd=`getInstallCmdPrd $_demo $_version`
  _runCmdDev=`getRunCmdDev $_demo`
  _runCmdPrd=`getRunCmdPrd $_demo`
  _readyDev=`getReadyMessageDev $_demo`
  _readyPrd=`getReadyMessagePrd $_demo`
  _port=`getPort $_demo`
  _test=`getTest $_demo`

  if [ -z "$NOCURRENT" ]
  then
    _current=`setDemoVersion $_demo current`
    [ -z "$_current" ] && reportError "Cannot get current version for $_demo"
    # 2
    applyPatches "$_demo" current "$_current" dev || return 1
    if hasDev $_demo; then
      # 3
      runValidations dev "$_current" "$_demo" "$_port" "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 4
      runValidations prod "$_current" "$_demo" "$_port" "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
  # 5
  if setDemoVersion $_demo $_version >/dev/null || [ -n "$NOCURRENT" ]
  then
    applyPatches "$_demo" next "$_version" prod || return 1
    if hasDev $_demo; then
      # 6
      runValidations dev "$_version" "$_demo" "$_port" "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 7
      runValidations prod "$_version" "$_demo" "$_port" "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
      [ -z "$COMMIT" ] || commitChanges $_demo $_version "$_installCmdPrd"
    fi
  fi
}
