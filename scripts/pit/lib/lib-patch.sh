
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
      ## TODO: re-enable when https://github.com/vaadin/quarkus/issues/271 is fixed
      ## See also: https://vaadin.com/docs/latest/flow/integrations/quarkus#quarkus.vaadin.knownissues
      # moveQuarkusBomToBottom
      ;;
    addon-template)
      ## TODO: remove when https://github.com/vaadin/flow/issues/23785 is fixed
      ## flow-server 25.1+ no longer pulls servlet-api transitively; Jetty plugin provides it
      ## at runtime but not at compile time, so test code that touches VaadinSession fails.
      if [ "$type_" = next ]; then
        addMavenDep pom.xml "jakarta.servlet" "jakarta.servlet-api" "provided"
      fi
      ;;
    flow-spring-examples)
      ## TODO: remove when https://github.com/vaadin/flow-spring-examples/issues/330 is fixed
      if [ "$type_" = next ]; then
        changeBlock \
          '<artifactId>commons-io</artifactId>' '\n' \
          '${1}\n            <version>2.21.0</version>${3}' pom.xml
      fi
      ;;
    testbench-demo|skeleton-starter-flow)
      ## TODO: remove when vaadin/testbench#2219 is fixed
      ## Vaadin 25.2 uses JUnit 6.0.3 but testbench-core-junit5 and some starters
      ## pin JUnit 5.x versions causing conflicts. Force JUnit 6 BOM, align
      ## all junit-platform artifacts, and upgrade surefire (3.0.0-M7 brings
      ## its own junit-platform-launcher 1.x that conflicts with JUnit 6).
      if [ "$type_" = next ]; then
        changeMavenBlock dependency org.junit junit-bom 6.0.3
        changeMavenBlock plugin org.apache.maven.plugins maven-surefire-plugin 3.5.4
        ## Remove hardcoded JUnit versions so the junit-bom 6.0.3 governs all
        perl -pi -e 's|<version>5\.14\.0</version>||g; s|<version>1\.14\.0</version>||g' pom.xml
        perl -0777 -pi -e 's|(<dependencyManagement>\s*<dependencies>)|$1\n            <dependency><groupId>org.junit.platform</groupId><artifactId>junit-platform-engine</artifactId><version>6.0.3</version></dependency>\n            <dependency><groupId>org.junit.platform</groupId><artifactId>junit-platform-commons</artifactId><version>6.0.3</version></dependency>\n            <dependency><groupId>org.junit.platform</groupId><artifactId>junit-platform-launcher</artifactId><version>6.0.3</version></dependency>|' pom.xml
      fi
      [ "$app_" = testbench-demo ] && S=src/test/screenshots && [ -d "$S" ] && runCmd "Removing $S" "rm -rf $S"
      ;;
    vaadin-showcase|spring-petclinic-vaadin-flow|walking-skeleton)
      ## Repos use Spring Boot < 4.0.4 which brings Jackson 3.0.x.
      ## Vaadin 25.2+ needs Jackson 3.1+ (available since Boot 4.0.4).
      ## Only needed for next since the repos work fine with their pinned Vaadin version.
      if [ "$type_" = next ]; then
        changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 4.0.5
      fi
      ;;
    skeleton-starter-flow-spring)
      ## TODO: remove when vaadin/testbench#2221 is fixed (browserless artifacts added to BOM)
      ## browserless-test-* not in vaadin-testbench-bom, Maven can't resolve versions.
      ## SpringBrowserlessTest is in browserless-test-spring, not browserless-test-junit6.
      if [ "$type_" = next ]; then
        changeMavenBlock dependency com.vaadin browserless-test-junit6 1.1.0-alpha1 com.vaadin browserless-test-spring
      fi
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
      ## TODO: remove when repo upgrades to Spring Boot 4.0.4+
      ## Spring Boot 4.0.0 brings Jackson 3.0.2 incompatible with Vaadin 25.1+ (needs 3.1+)
      changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 4.0.5
      ;;
    skeleton-starter-hilla-lit-gradle|skeleton-starter-hilla-react-gradle)
      ## TODO: remove when repos upgrade to Spring Boot 4.0.4+
      ## Spring Boot 4.0.0 brings Jackson 3.0.2 incompatible with Vaadin 25.1+ (needs 3.1+)
      perl -pi -e "s/id 'org.springframework.boot' version '4\.0\.[0-3]'/id 'org.springframework.boot' version '4.0.5'/" build.gradle
      ;;
    initializer-vaadin-*-react)
      ## Vaadin 25 no longer includes Hilla by default, need to add it for React views
      if [ -f pom.xml ]; then
        addMavenDep pom.xml "com.vaadin" "hilla-spring-boot-starter" "compile"
      elif [ -f build.gradle ]; then
        perl -pi -e "s|(implementation\s*['\"]com\.vaadin:vaadin-spring-boot-starter['\"])|\$1\n    implementation 'com.vaadin:hilla-spring-boot-starter'|" build.gradle
      fi
      ;;
    npm-addon-template)
      ## package.json has all Vaadin component versions hardcoded in overrides.
      ## When bumping vaadin.version, the plugin updates dependencies but not overrides,
      ## causing npm EOVERRIDE conflict. Removing it lets the plugin regenerate it.
      if [ "$type_" = next ]; then
        rm -f package.json
      fi
      ;;
    start)
      ## TODO: remove when vaadin/start#3650 is fixed
      ## Vaadin 25.2 regenerates tsconfig.json without allowImportingTsExtensions,
      ## causing TS5097 errors in production Vite build.
      if [ "$type_" = next ]; then
        cat > fix-tsconfig.cjs << 'FIXEOF'
const fs = require("fs");
const t = fs.readFileSync("tsconfig.json", "utf8").replace(/\/\/[^\n]*/g, "");
const j = JSON.parse(t);
j.compilerOptions.allowImportingTsExtensions = true;
fs.writeFileSync("tsconfig.json", JSON.stringify(j, null, 2));
FIXEOF
        perl -pi -e "s|run\('compile-ts'\);|run('compile-ts');\nexecSync('node fix-tsconfig.cjs');|" vite.config.ts
      fi
      ;;
    expo-flow)
      ## TODO: remove
      ## Tailwind CSS plugin fails to resolve bare @import in META-INF/resources (vaadin/flow#23560)
      perl -pi -e 's|\@import "((?!\./)[^"]+\.css)"|\@import "./$1"|g' src/main/resources/META-INF/resources/styles.css
      ## TODO: remove when vaadin/flow-components#9218 is resolved (deprecated aliases added)
      ## Slider/RangeSlider/RangeSliderValue removed in alpha4, renamed to Decimal* variants
      ## Also SpringBrowserlessTest API changed, breaking PlaygroundViewTest
      if [ "$type_" = next ]; then
        find src/main -name "*.java" -exec perl -pi -e '
          s/import com\.vaadin\.flow\.component\.slider\.Slider;/import com.vaadin.flow.component.slider.DecimalSlider;/g;
          s/import com\.vaadin\.flow\.component\.slider\.RangeSlider;/import com.vaadin.flow.component.slider.DecimalRangeSlider;/g;
          s/import com\.vaadin\.flow\.component\.slider\.RangeSliderValue;/import com.vaadin.flow.component.slider.DecimalRangeSliderValue;/g;
          s/\bnew RangeSlider\(/new DecimalRangeSlider(/g;
          s/\bnew RangeSliderValue\(/new DecimalRangeSliderValue(/g;
          s/\bnew Slider\(/new DecimalSlider(/g;
          s/\bRangeSlider\b/DecimalRangeSlider/g;
          s/\bRangeSliderValue\b/DecimalRangeSliderValue/g;
          s/(?<![a-zA-Z])Slider\b(?!Element)/DecimalSlider/g;
        ' {} +
        rm -rf src/test
      fi
      ;;
    signals-cases)
      ## TODO: remove when https://github.com/vaadin/signals-cases/issues/169 is fixed
      ## ErrorProne needs -XDaddTypeAnnotationsToSymbol on JDK<22
      changeBlock '<plugin>\s*<groupId>am.ik.maven</groupId>' '</plugin>' remove pom.xml
      ## unnamed variables (_) finalized in JDK 22 (JEP 456), replace for JDK 21 compat
      find src -name "*.java" -exec perl -pi -e 's/\b_ ->/unused ->/g' {} +
      ;;
    base-starter-gradle)
      ## gretty uses archivePath removed in Gradle 9, downgrade to 8.14.2 (vaadin/base-starter-gradle#311)
      perl -pi -e 's/gradle-[\d.]+(-\w+)?-bin\.zip/gradle-8.14.2-bin.zip/' gradle/wrapper/gradle-wrapper.properties
      ## failOnNoDiscoveredTests is Gradle 9 only, remove it for 8.x
      perl -pi -e 's/^\s*failOnNoDiscoveredTests\s*=.*$//' build.gradle
      ;;
  esac
  case "$vers_" in
    ## The minimum version of Java supported by vaadin is 17, hence we test for it
    23*|24*)
      setJavaVersion 17
      ;;
    25.*)
      ## The minimum version of Java supported by vaadin 25 is 21
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
    25.2.*|25.1.*|25.0.*|current) : ;;
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

