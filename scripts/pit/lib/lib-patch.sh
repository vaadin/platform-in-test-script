## LIBRARY for patching Vaadin starters or demos
##   It has especial workarounds for specific apps.
##   There could be especial patches for specific versions of Apps, Vaadin or Hilla
##   Patches for special versions are maintained in separated files like lib-patch-v24.sh, lib-patch-v24.4.sh
##   These especial patches are loaded and applied in this script

## Run after updating Vaadin/Hilla versions in order to patch sources
applyPatches() {
  app_=$1; type_=$2; vers_=$3; mod_=$4
  [ -n "$TEST" ] || log "Applying Patches for $app_ $type_ $vers_"

  case $vers_ in
    *alpha*|*beta*|*rc*|*SNAP*) addPrereleases;;
  esac
  expr "$vers_" : ".*SNAPSHOT" >/dev/null && enableSnapshots
  expr "$vers_" : "24.3.0.alpha.*" >/dev/null && addSpringReleaseRepo
  checkProjectUsingOldVaadin "$type_" "$vers_"
  downgradeJava

  case $app_ in
    archetype-hotswap) enableJBRAutoreload ;;
    vaadin-oauth-example)
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-id \
        553339476434-a7kb9vna7limjgucee2n0io775ra5qet.apps.googleusercontent.com
      setPropertyInFile src/main/resources/application.properties \
        spring.security.oauth2.client.registration.google.client-secret \
        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
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
      log "Fixing quarkus dependencyManagement https://vaadin.com/docs/latest/flow/integrations/quarkus#quarkus.vaadin.knownissues"
      moveQuarkusBomToBottom
      ;;
  esac

  # always successful
  return 0
}

## We use this function to check if the project in its reporitory has not been updated to latest stable vaadin version
checkProjectUsingOldVaadin() {
  [ "$1" != 'current' ] && return
  case $vers_ in
    24.6.*|24.5.*|current) : ;;
    *) reportError "Using old version $vers_" "Please upgrade $app_ to latest stable" ;;
  esac
}

## Run at the beginning of Validate in order to skip upsupported app/version combination
isUnsupported() {
  app_=$1; mod_=$2; vers_=$3;

  ## Karaf and OSGi unsupported in 24.x
  [ $app_ = vaadin-flow-karaf-example -o $app_ = base-starter-flow-osgi ] && return 0

  ## Everything else is supported
  return 1
}

## The minimum version of Java supported by vaadin is 17, hence we test for it
downgradeJava() {
  [ ! -f pom.xml ] && return
  grep -q '<java.version>21</java.version>' pom.xml || return
  cmd "perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml"
  perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml
  warn "Downgraded Java version from 21 to 17 in pom.xml"
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

