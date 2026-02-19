
## LIBRARY for patching Vaadin starters or demos
##   It has especial workarounds for specific apps.
##   There could be especial patches for specific versions of Apps, Vaadin or Hilla
##   Patches for special versions are maintained in separated files like lib-patch-v24.sh, lib-patch-v24.4.sh
##   These especial patches are loaded and applied in this script

## Run after updating Vaadin/Hilla versions in order to patch sources
# $1 application/starter name
# $2 type (current | next)
# $3 version
# $4 mode (dev | prod)
applyPatches() {
  app_=$1; type_=$2; vers_=$3; mod_=$4
  [ -n "$TEST" ] || log "Applying Patches for $app_ $type_ $vers_"

  case $vers_ in
    *alpha*|*SNAP*) addPrereleases;;
  esac
  expr "$vers_" : ".*SNAPSHOT" >/dev/null && enableSnapshots
  checkProjectUsingOldVaadin "$type_" "$vers_"
  checkProjectHasProductionProfile
  upgradeExampleData

  case $app_ in
    archetype-hotswap)
      ## need to happen in patch phase not in the run phase
      enableJBRAutoreload ;;
    vaadin-oauth-example)
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-id \
        553339476434-a7kb9vna7limjgucee2n0io775ra5qet.apps.googleusercontent.com
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-secret \
        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
      ;;
    releases-graph)
      setPropertyInFile src/main/resources/application.properties \
        github.personal.token ${GHTK:-$GITHUB_TOKEN}
      ;;
    mpr-demo)
      SS=~/vaadin.spreadsheet.developer.license
      [ ! -f $SS ] && err "Install a Valid License $SS" && return 1
      ;;
    form-filler-demo)
      [ -n "$TEST" ] && ([ -z "$OPENAI_TOKEN" ] && cmd "export OPENAI_TOKEN=your_AI_token") && return 0
      [ -z "$OPENAI_TOKEN" ] && err "Set correctly the OPENAI_TOKEN env var" && return 1
      ;;
    vaadin-quarkus)
      [ -n "$TEST" ] || log "Fixing quarkus dependencyManagement https://vaadin.com/docs/latest/flow/integrations/quarkus#quarkus.vaadin.knownissues"
      ## TODO: should not be needed with latest LC
      moveQuarkusBomToBottom
      ## TODO: remove when https://github.com/vaadin/quarkus/issues/265
      ## it needs to be changed in both current and next releases
      changeBlock \
        '<artifactId>vaadin-quarkus</artifactId>' '\n' \
        '${1}\n    <packaging>quarkus</packaging>${3}' pom.xml
      ;;
    testbench-demo)
      S=src/test/screenshots
      [ -d "$S" ] && runCmd "Removing $S" "rm -rf $S"
      ;;
    archetype-spring)
      ## archetype hardcodes vaadin-maven-plugin version instead of using ${vaadin.version}
      if [ "$type_" = next ]; then
        changeBlock \
          '<artifactId>vaadin-maven-plugin</artifactId>\s*<version>' '</version>' \
          '${1}'$vers_'${3}' pom.xml
      fi
      ;;
    multi-module-example)
      ## backend/pom.xml has its own parent (spring-boot-starter-parent), so it needs the repo too
      if [ "$type_" = next ]; then
        (cd backend && addRepoToPom "https://maven.vaadin.com/vaadin-prereleases")
      fi
      ;;
    initializer-vaadin-*-react)
      ## Vaadin 25 no longer includes Hilla by default, need to add it for React views
      if [ -f pom.xml ]; then
        addMavenDep pom.xml "com.vaadin" "hilla-spring-boot-starter" "compile"
      elif [ -f build.gradle ]; then
        perl -pi -e "s|(implementation\s*['\"]com\.vaadin:vaadin-spring-boot-starter['\"])|\$1\n    implementation 'com.vaadin:hilla-spring-boot-starter'|" build.gradle
      fi
      ;;
    expo-flow)
      ## TODO: remove
      ## Tailwind CSS plugin fails to resolve bare @import in META-INF/resources (vaadin/flow#23560)
      perl -pi -e 's|\@import "((?!\./)[^"]+\.css)"|\@import "./$1"|g' src/main/resources/META-INF/resources/styles.css
      ;;
    base-starter-gradle)
      ## gretty uses archivePath removed in Gradle 9, downgrade to 8.14.2 (vaadin/base-starter-gradle#311)
      perl -pi -e 's/gradle-[\d.]+(-\w+)?-bin\.zip/gradle-8.14.2-bin.zip/' gradle/wrapper/gradle-wrapper.properties
      ## failOnNoDiscoveredTests is Gradle 9 only, remove it for 8.x
      perl -pi -e 's/^\s*failOnNoDiscoveredTests\s*=.*$//' build.gradle
      ;;
    spreadsheet-demo)
      ## TODO: remove when fixed https://github.com/vaadin/flow/issues/23530#issuecomment-3928679559
      if [ "$type_" = next ]; then
        runCmd -f "Cleaning project after version bump" "$MVN -ntp -B clean vaadin:clean-frontend"
      fi
      ;;
  esac
  case "$vers_" in
    ## The minimum version of Java supported by vaadin is 17, hence we test for it
    23*|24*)
      setJavaVersion 17
      ;;
    25.0.0*)
      ## The minimum version of Java supported by vaadin is 17, hence we test for it
      setJavaVersion 21
      ;;
  esac

  # always successful
  return 0
}

## We use this function to check if the project in its reporitory has not been updated to latest stable vaadin version
checkProjectUsingOldVaadin() {
  [ "$1" != 'current' ] && return
  case $vers_ in
    25.1.*|25.0.*|current) : ;;
    *) reportError "Using old version $vers_" "Please upgrade $app_ to latest stable" ;;
  esac
}

## Check that the project does not have the deprecated 'production' profile in pom.xml
checkProjectHasProductionProfile() {
  [ ! -f pom.xml ] && return
  H=$(grep -l '<id>production</id>' pom.xml 2>/dev/null)
  [ -n "$H" ] && reportError "Project has deprecated 'production' profile" "Please remove the 'production' profile from pom.xml, use 'mvn -Pproduction' is no longer needed in Vaadin 25+"
}

## Upgrade exampledata to 7.0.0-alpha1 for target builds
## exampledata 6.2.0 uses com.vaadin.flow.server.frontend.FrontendUtils which was
## moved to com.vaadin.flow.internal.FrontendUtils in flow 25.1 (vaadin/flow#22956)
upgradeExampleData() {
  [ "$type_" != next ] && return
  changeMavenBlock dependency com.vaadin exampledata 7.0.0-alpha1
}

## Run at the beginning of Validate in order to skip upsupported app/version combination
isUnsupported() {
  app_=$1; mod_=$2; vers_=$3;

  ## Karaf and OSGi unsupported in 24.x
  [ $app_ = vaadin-flow-karaf-example -o $app_ = base-starter-flow-osgi ] && return 0

  ## Everything else is supported
  return 1
}

## Moves quarkus dependency to the bottom of the dependencyManagement block
moveQuarkusBomToBottom() {
  changeBlock  \
    '<dependencyManagement>\s*<dependencies>)(\s*<dependency>\s*<groupId>\${quarkus\.platform\.group-id}.*?</dependency>' \
    '\s*</dependencies>\s*</dependencyManagement>' \
    '${1}${3}${2}${4}' pom.xml
}

# removeDeprecated() {
#   [ ! -f pom.xml ] && return
#   grep -q '<productionMode>true</productionMode>' pom.xml || return
#   cmd "perl -0777 -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml"
#   perl -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml
#   warn "Removed deprecated productionMode from pom.xml"
# }

## FIXED - k8s-demo-app 23.3.0.alpha2
# patchOldSpringProjects() {
#   changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 2.7.4
# }

## FIXED - bakery 23.1
# patchRouterLink() {
#   find src -name "*.java" | xargs perl -pi -e 's/RouterLink\(null, /RouterLink("", /g'
#   H=`git status --porcelain src`
#   if [ -n "$H" ]; then
#     log "patched RouterLink occurrences in files: $F"
#   fi
# }

## FIXED - Karaf 23.2.2
# patchKarafLicenseOsgi() {
#   __pom=main-ui/pom.xml
#   [ -f $__pom ] && warn "Patching $__pom (adding license-checker 1.10.0)" && perl -pi -e \
#     's,</dependencies>,<dependency><groupId>com.vaadin</groupId><artifactId>license-checker</artifactId><version>1.10.0</version></dependency></dependencies>,' \
#     $__pom
# }

## FIXED - skeleton-starter-flow-spring 23.3.0.alpha2
# patchIndexTs() {
#   __file="frontend/index.ts"
#   if test -f "$__file" && grep -q 'vaadin/flow-frontend' $__file; then
#     warn "patch 23.3.0.alpha2 - Patching $__file because it has vaadin/flow-frontend/ occurrences"
#     perl -pi -e 's,\@vaadin/flow-frontend/,Frontend/generated/jar-resources/,g' $__file
#   fi
# }

## FIXED - latest-typescript*, vaadin-flow-karaf-example, base-starter-flow-quarkus, base-starter-flow-osgi, 23.3.0.alpha3
# patchTsConfig() {
#   H=`ls -1 tsconfig.json */tsconfig.json 2>/dev/null`
#   [ -n "$H" ] && warn "patch 23.3.0.alpha3 - Removing $H" && rm -f tsconfig.json */tsconfig.json
# }

## FIXED - ce does not need any license since 24.5
# installCeLicense() {
#   LIC=ce-license.json
#   [ -n "$TEST" ] && ([ -z "$CE_LICENSE" ] && cmd "## Put a valid CE License in ./$LIC" || cmd "## Copy your CE License to ./$LIC") && return 0
#   [ -z "$CE_LICENSE" ] && err "No \$CE_LICENSE provided" && [ -z "$TEST" ] && return 1
#   warn "Creating license file ./$LIC with the \$CE_LICENSE content"
#   cmd "echo \"\$CE_LICENSE\" > $LIC"
#   echo "$CE_LICENSE" > $LIC
# }

