## LIBRARY for testing demos that exist in github

. `dirname $0`/lib/lib-validate.sh
. `dirname $0`/lib/lib-patch.sh

## Check demo branches for a given version
## It verifies that demos have the expected branch (v25, v25.0, etc.) and correct Vaadin version
## $1: version to check (e.g., 25.0.0, 25.1.0)
checkDemoBranches() {
  local version="$1"
  [ -z "$version" -o "$version" = "current" ] && err "Please provide a version with --version=X.Y.Z" && return 1

  # Extract major and minor versions
  local major=$(echo "$version" | cut -d. -f1)
  local minor=$(echo "$version" | cut -d. -f2)

  # Branch candidates to check: v25.0, v25
  local branch_candidates="v${major}.${minor} v${major}"

  bold "Checking demo branches for version $version"
  bold "Branch candidates: $branch_candidates"
  printnl

  local demos_list
  [ -n "$STARTERS" ] && demos_list=$(echo "$STARTERS" | tr ',' '\n') || demos_list="$DEMOS"

  for demo in $demos_list; do
    [ -z "$demo" ] && continue
    checkDemoBranch "$demo" "$version" "$branch_candidates"
  done
}

## Check a single demo's branch and version
## $1: demo name (e.g., skeleton-starter-flow, expo-flow:v25)
## $2: expected version (e.g., 25.0.0)
## $3: branch candidates (e.g., "v25.0 v25")
checkDemoBranch() {
  local demo="$1"
  local expected_version="$2"
  local branch_candidates="$3"

  local repo=$(getGitRepo "$demo")
  local explicit_branch=$(echo "$demo" | grep ':' | cut -d: -f2)
  local demo_name=$(getGitDemo "$demo")

  # Build git URL with token if available
  local token="${GHTK:-$GITHUB_TOKEN}"
  local git_url="https://github.com/${repo}.git"
  [ -n "$token" ] && git_url="https://${token}@github.com/${repo}.git"

  # If demo has explicit branch in its definition (e.g., expo-flow:v25)
  if [ -n "$explicit_branch" ]; then
    checkBranchVersion "$repo" "$explicit_branch" "$expected_version" "$demo_name"
    return
  fi

  # Try branch candidates in order
  local found_branch=""
  for branch in $branch_candidates; do
    if git ls-remote --heads "$git_url" "$branch" 2>/dev/null | grep -q "refs/heads/$branch"; then
      found_branch="$branch"
      break
    fi
  done

  if [ -z "$found_branch" ]; then
    # No version branch found, check default branch
    local default_branch=$(git ls-remote --symref "$git_url" HEAD 2>/dev/null | grep 'ref:' | sed 's|.*refs/heads/||' | awk '{print $1}')
    [ -z "$default_branch" ] && default_branch="main"
    warn "$demo_name: No branch found ($branch_candidates), using default: $default_branch"
    checkBranchVersion "$repo" "$default_branch" "$expected_version" "$demo_name"
  else
    checkBranchVersion "$repo" "$found_branch" "$expected_version" "$demo_name"
  fi
}

## Check if a branch has the expected Vaadin version
## $1: repo (e.g., vaadin/skeleton-starter-flow)
## $2: branch
## $3: expected version
## $4: demo name for display
checkBranchVersion() {
  local repo="$1"
  local branch="$2"
  local expected_version="$3"
  local demo_name="$4"

  # Build curl auth header if token available
  local token="${GHTK:-$GITHUB_TOKEN}"
  local auth_header=""
  [ -n "$token" ] && auth_header="-H \"Authorization: token ${token}\""

  # Get pom.xml from the branch
  local pom_url="https://raw.githubusercontent.com/${repo}/${branch}/pom.xml"
  local pom_content=$(eval curl -s -f $auth_header "$pom_url" 2>/dev/null)

  if [ -z "$pom_content" ]; then
    # Try build.gradle for gradle projects
    local gradle_url="https://raw.githubusercontent.com/${repo}/${branch}/gradle.properties"
    local gradle_content=$(eval curl -s -f $auth_header "$gradle_url" 2>/dev/null)

    if [ -z "$gradle_content" ]; then
      warn "$demo_name [$branch]: Cannot fetch build file"
      return 1
    fi

    # Extract version from gradle.properties
    local actual_version=$(echo "$gradle_content" | grep -E '^vaadinVersion=' | cut -d= -f2)
    [ -z "$actual_version" ] && actual_version=$(echo "$gradle_content" | grep -E '^hillaVersion=' | cut -d= -f2)

    compareVersions "$demo_name" "$branch" "$expected_version" "$actual_version"
    return
  fi

  # Extract vaadin.version from pom.xml
  local actual_version=$(echo "$pom_content" | grep '<vaadin.version>' | sed 's|.*<vaadin.version>\([^<]*\)</vaadin.version>.*|\1|')
  [ -z "$actual_version" ] && actual_version=$(echo "$pom_content" | grep '<hilla.version>' | sed 's|.*<hilla.version>\([^<]*\)</hilla.version>.*|\1|')

  # If not found, try submodules (for multi-module projects)
  if [ -z "$actual_version" ]; then
    for submodule in vaadin-app app ui frontend; do
      local sub_pom_url="https://raw.githubusercontent.com/${repo}/${branch}/${submodule}/pom.xml"
      local sub_pom_content=$(eval curl -s -f $auth_header "$sub_pom_url" 2>/dev/null)
      if [ -n "$sub_pom_content" ]; then
        actual_version=$(echo "$sub_pom_content" | grep '<vaadin.version>' | sed 's|.*<vaadin.version>\([^<]*\)</vaadin.version>.*|\1|')
        [ -z "$actual_version" ] && actual_version=$(echo "$sub_pom_content" | grep '<hilla.version>' | sed 's|.*<hilla.version>\([^<]*\)</hilla.version>.*|\1|')
        [ -n "$actual_version" ] && break
      fi
    done
  fi

  compareVersions "$demo_name" "$branch" "$expected_version" "$actual_version"
}

## Compare and display version status
## $1: demo name
## $2: branch
## $3: expected version
## $4: actual version
compareVersions() {
  local demo_name="$1"
  local branch="$2"
  local expected="$3"
  local actual="$4"

  if [ -z "$actual" ]; then
    warn "$demo_name [$branch]: Version not found in build file"
  elif [ "$actual" = "$expected" ]; then
    log "$demo_name [$branch]: OK ($actual)"
  else
    err "$demo_name [$branch]: MISMATCH - expected $expected, found $actual"
  fi
}

## Checkout a branch of a vaadin repository in github
## we add GITHUB_TOKEN or GHTK environment variable to the URL
## $1: the name of the demo in the form of `repo[:branch][/folder]`
checkoutDemo() {
  local _demo=`getGitDemo $1`
  local _branch=`getGitBranch $1`
  local _folder=`getGitFolder $1`
  local _workdir="$_demo$_folder"
  local _repo=`getGitRepo $1`
  local _base="https://github.com/"
  grep -q '^github' ~/.ssh/known_hosts 2>/dev/null && _base="git@github.com:"

  validateToken $_repo && _base=`echo "$_base" | sed -e 's|\(https://\)|\\1'$GHTK'@|'`
  local _gitUrl="${_base}${_repo}.git"
  [ -z "$VERBOSE" -o -n "$TEST" ] && _quiet="-q"
  if [ -z "$OFFLINE" -o ! -d "$_workdir" ]
  then
    [ ! -d "$_demo" ] || runCmd -qf "Removing preexisting folder $_demo" "rm -rf $_demo" || return 1
    runCmd -f "Cloning repository $_repo" "git clone $_quiet $_gitUrl" || return 1
    cmd "cd $_workdir"; cd "$_workdir" || return 1
  else
    cmd "cd $_workdir"; cd "$_workdir" || return 1
    runCmd -f "Reseting local changes in $_repo" "git reset $_quiet --hard HEAD" || return 1
    runCmd -f "Deleting preexisting .out files" "rm -rf *.out"
  fi
  [ -z "$_branch" ] || runCmd -f "Selecting branch: $_branch" "git checkout $_quiet $_branch"
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

## Get install command for dev-mode
getInstallCmdDev() {
  case $1 in
    *-gradle) echo "$GRADLE clean" ;;
    multi-module-example) echo "$MVN -ntp -B clean install -DskipTests $PNPM";;
    start) echo "rm -rf package-lock.json node_modules target frontend/generated; $MVN -ntp -B clean";;
    *) echo "$MVN -ntp -B clean $PNPM";;
  esac
}
## Get install command for prod-mode
getInstallCmdPrd() {
  H="$MVN -ntp -B clean install -Pproduction"
  if find src/test -name "*IT.java" -o -name "*spec.ts" 2>/dev/null | grep -q .
  then
    H="$H -Pit -Dcom.vaadin.testbench.Parameters.testsInParallel=2"
    isHeadless && H="$H -Dcom.vaadin.testbench.Parameters.headless=true -Dheadless" || H="$H -Dtest.headless=false" #for addon-template flow-hilla-hybrid-example
  fi

  [ -n "$SKIPTESTS" ] && E="-DskipTests"
  [ -z "$MAVEN_ARGS" ] &&  E="$E -Dmaven.test.redirectTestOutputToFile=true"

  case $1 in
    *-gradle)
      expr "$_version" : '2\.' >/dev/null && H="-hilla.productionMode" || H="-Pvaadin.productionMode"
      echo "$GRADLE clean build $H $PNPM";;
    *-quarkus) echo "$MVN -ntp -B clean package -Pproduction $E $PNPM -Dquarkus.analytics.disabled=true";;
    mpr-demo|spreadsheet-demo) echo "$MVN -ntp -B clean";;
    start) echo "$MVN -ntp -B install -Dmaven.test.skip -Pci" ;;
    form-filler-demo) echo "$H $E $PNPM -DOPENAI_TOKEN=$OPENAI_TOKEN";;
    testbench-demo) echo "$H $E $PNPM";;
    *) echo "$H $PNPM";;
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
    bakery-app-starter-flow-spring);;
    mpr-demo) echo "mpr-demo.js";;
    spreadsheet-demo) echo "spreadsheet-demo.js";;
    k8s-demo-app) echo "k8s-demo.js";;
    releases-graph) echo "releases.js";;
    cookbook|walking-skeleton*|business-app-starter-flow|*hilla*|spring-petclinic-vaadin-flow|gs-crud-with-vaadin|vaadin-form-example|vaadin-rest-example|vaadin-localization-example|vaadin-database-example|layout-examples|flow-quickstart-tutorial|flow-spring-examples|flow-crm-tutorial|layout-examples|flow-quickstart-tutorial|vaadin-oauth-example|designer-tutorial|*addon-template|addon-starter-flow|testbench-demo) echo "noop.js";;
    start) echo "start-wizard.js";;
    vaadin-oauth-example) echo "oauth.js";;
    bookstore-example) echo "bookstore.js";;
    form-filler-demo) echo "ai.js";;
    expo-flow) echo "expo-flow.js";;
    *) echo "hello.js";;
  esac
}

## Change version in build files
## $1: name of the demo
## $2: version to set
setDemoVersion() {
  [ -z "$2" ] && return 1
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
    bold -n ">>> PiT current $_demo"
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
  if setDemoVersion $_demo $_version >/dev/null
  then
    bold -n ">>> PiT next $_demo"
    applyPatches "$_demo" next "$_version" prod || return 1
    if hasDev $_demo; then
      # 6
      runValidations dev "$_version" "$_demo" "$_port" "$_installCmdDev" "$_runCmdDev" "$_readyDev" "$_test" || return 1
    fi
    if hasProduction $_demo; then
      # 7
      runValidations prod "$_version" "$_demo" "$_port" "$_installCmdPrd" "$_runCmdPrd" "$_readyPrd" "$_test" || return 1
    fi
  fi
}
