

applyv25patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d src/main ] && D=src/main || D=*/src/main
  F=$D/frontend


  addAnonymousAllowedToAppLayout
  updateAppLayoutAfterNavigation
  updateSpringBootApplication
  updateGradleWrapper
  _opt="<optional>true</optional>"
  case $app_ in
    business-app-starter-flow)
      ## TODO: Update all starters where applicable
      updateTheme
      removeJsImport '\@vaadin/vaadin-lumo-styles/badge'
      addNpmImport '\@polymer/polymer' '^3.5.2'
      ;;
    skeleton-starter-flow-cdi)
      ## TODO: needs to be documented in release notes, but also in migration guide to 25
      patchJaxrs $app_
      _opt=""
      ;;
    testbench-demo)
      ## TODO: changes are already in v25, make it main branch when 25.0 GA
      patchTestBenchJUnit
      ;;
    base-starter-flow-quarkus)
      ## TODO: changes are already in v25, make it main branch when 25.0 GA
      changeMavenProperty quarkus.platform.version 3.24.2
      ;;
    gs-crud-with-vaadin)
      ## TODO: Update test to use Mockito extension instead of Spring Boot test
      patchTestCrudWithVaadin
      ;;
    spring-petclinic-vaadin-flow)
      ## TODO: Update test to not use configuration
      patchTestPetClinic
      ;;
    hilla-quickstart-tutorial)
      ## TODO: Update Lumo imports in TypeScript files
      patchLumoImports
      ;;
    archetype-spring|initializer-vaadin-maven-react)
      ## TODO: spring 4 does not enables this prop as default as before
      ## should we deliver starters or demos with property enabled?
      enableLiveReload
      ;;
    start)
      ## TODO: document this for tests using spring tests
      addMavenDep org.springframework.boot spring-boot-webmvc-test test
      ## TODO: open an issue in start, why after vaadin:dance this is not installed
      ## For some reason npm install glob@^11.0.3 --save modifies devdeps but not deps
      perl -0777 -pi -e 's|(    "lit":)|\n    "glob": "^11.0.3",$1|' package.json
      ;;
    bookstore-example)
      ## TODO: check that documentation mention elemental is not a transitive dep anymore
      addMavenDep "com.google.gwt" "gwt-elemental" compile '\<version\>2.9.0\</version\>'
      ;;
  esac

  case $vers_ in
    *alpha7|*alpha8|*alpha9)       SV=4.0.0-M1 ;;
    *alpha10|*alpha11)             SV=4.0.0-M2 ;;
    *alpha12|*beta1|*beta2|*beta3) SV=4.0.0-M3 ;;
    *beta4)                        SV=4.0.0-RC1 ;;
    *beta*)
       SV=4.0.0
        ## TODO: document in migration guide to 25
        addHillaStarterIfNeeded $app_
        ## TODO: document in migration guide to 25 (bakery, mpr-demo, k8s-demo, start)
        replaceVaadinSpringWithStarter
        ## TODO: document in migration guide to 25
        addDevModeIfNeeded "$_opt"
       ;;
  esac

  changeMavenBlock parent org.springframework.boot spring-boot-starter-parent $SV
  setVersionInGradle "org.springframework.boot" $SV

  ## TODO: document in migration guide to 25
  patchImports 'import com.fasterxml.jackson.core.type.TypeReference;'\
               'import tools.jackson.core.type.TypeReference;'
  patchImports 'import com.fasterxml.jackson.databind' \
               'import tools.jackson.databind'
  patchImports 'import org.springframework.boot.autoconfigure.domain.EntityScan;' \
               'import org.springframework.boot.persistence.autoconfigure.EntityScan;'
  patchImports 'import org.springframework.boot.autoconfigure.web.servlet.error.ErrorMvcAutoConfiguration;' \
               'import org.springframework.boot.webmvc.autoconfigure.error.ErrorMvcAutoConfiguration;'
  ## start
  patchImports 'import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;' \
               'import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;'
  patchImports 'import org.springframework.boot.security.autoconfigure.servlet.SecurityAutoConfiguration;' \
               'import org.springframework.boot.security.autoconfigure.SecurityAutoConfiguration;'
  patchImports 'import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;' \
               'import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;'

  ## releases-graph
  patchImports 'import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;' ''
  ## ce-demo
  patchImports 'import com.fasterxml.jackson.core.JsonProcessingException;' ''
  patchImports 'throws JsonProcessingException' 'throws Exception'
  patchMapper

  diff_=`git diff -- pom.xml package.json *gradle* .gradle $D $D/../test $F | egrep '^[+-]'`
  [ -z "$TEST" -a -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======"

  cleanAfterBumpingVersions

  return 0
}

## Update Gradle wrapper to version 8.14 for v25 compatibility
## TODO: needs to be documented in vaadin migration guide to 25 and updated in starter repos
updateGradleWrapper() {
  local prop="gradle/wrapper/gradle-wrapper.properties"
  [ ! -f "$prop" ] && return 0
  grep -q "gradle-8\.14-bin\.zip" "$prop" && return 0

  [ -z "$TEST" ] && warn "updating Gradle wrapper to 8.14 in $prop" || cmd "## updating Gradle wrapper to 8.14 in $prop"
  setPropertyInFile "$prop" "distributionUrl" "https\\://services.gradle.org/distributions/gradle-8.14-bin.zip"
}

## TODO: needs to be documented in vaadin migration guide to 25
cleanAfterBumpingVersions() {
  if [ -f build.gradle ]; then
    computeGradle
    ## vaadinClean is not enough it needs to clean everything also
    runCmd "Removing build artifacts" "rm -rf build package-lock.json tsconfig* types* vite* target* src/main/frontend/generated/ src/main/bundles"
    runCmd "Cleaning project after version bump" "$GRADLE clean vaadinClean"
    ## TODO: temporary solution for https://github.com/vaadin/flow/issues/22586#issuecomment-3460191787
    # addRepoToGradle 'mavenLocal()'
    setPropertyInFile src/main/resources/application.properties vaadin.allowed-packages FOO
    return
  fi
  ## TODO: revise this https://github.com/vaadin/flow/issues/22676
  # [ ! -d src/main/frontend/views/ -a -n "$NOCURRENT" ] && return
  ## vaadin:clean-frontend is not enough it needs to clean target too
  ## note that archetype-spring (and maybe others) needs the production profile to have vaadin plugin available
  for i in `getPomFiles`; do
    # local T=`dirname $i`/target
    # if [ -d "$T" ]; then
      grep -q "vaadin-maven-plugin" $i && P=vaadin
      grep -q "flow-maven-plugin" $i && P=flow
      [ -z "$P" ] || runCmd -f "Cleaning project after version bump" "$MVN clean $P:clean-frontend -Pproduction -f $i"
    # fi
  done
}

## TODO: document this in migration guide
enableLiveReload() {
  setPropertyInFile src/main/resources/application.properties spring.devtools.livereload.enabled true
}

## Find all java class files that extend AppLayout and have afterNavigation() method, then update them to implement AfterNavigationObserver
## This break change is in https://github.com/vaadin/flow-components/issues/5449
## TODO: needs to be documented in vaadin migration guide to 25 and updated in starter repos
## The API has significantly changed in Spring Boot 4.0.0-M3.
## The entire Spring Boot auto-configuration for web applications has been restructured.
updateAppLayoutAfterNavigation() {
  find . -name "*.java" -exec grep -l "extends AppLayout" {} +  | while read file; do
    # Check if the file contains afterNavigation method
    if grep -q "afterNavigation()" "$file"; then
      [ -z "$TEST" ] && warn "updating afterNavigation method in $file" || cmd "## updating afterNavigation method in $file"

      # Check if already implements AfterNavigationObserver
      if ! grep -q "implements.*AfterNavigationObserver" "$file"; then
        # Add implements AfterNavigationObserver to class declaration
        _cmd1="perl -pi -e 's/(public\s+class\s+[A-Za-z0-9_]+\s+extends\s+AppLayout)(\s*)(\{)/\$1 implements com.vaadin.flow.router.AfterNavigationObserver\$2\$3/' \"$file\""
        cmd "$_cmd1"
        eval "$_cmd1"
      fi

      # Transform the method - handle both with and without @Override in one pattern
      _cmd2="perl -0777 -pi -e 's/(\s+)(?:@Override\s+)?protected\s+void\s+afterNavigation\(\)\s*\{\s*super\.afterNavigation\(\);\s*/\$1@Override\n\$1public void afterNavigation(com.vaadin.flow.router.AfterNavigationEvent event) {\n\$1/gs' \"$file\""
      cmd "$_cmd2"
      eval "$_cmd2"
    fi
  done
}

## Find Application class with @SpringBootApplication and remove database initialization method and unused imports
## This is needed when upgrading to new Spring Boot versions where manual database initialization is no longer required
## TODO: needs to be documented in vaadin migration guide to 25
updateSpringBootApplication() {
  # Find the Application class with @SpringBootApplication annotation
  local app_file=$(find . -name "*.java" -exec grep -l "@SpringBootApplication" {} +)

  [ -z "$app_file" ] && return 0

  # Check if file contains the SqlDataSourceScriptDatabaseInitializer method
  if grep -q "SqlDataSourceScriptDatabaseInitializer" "$app_file"; then
    [ -z "$TEST" ] && warn "removing database initialization method from $app_file" || cmd "## removing database initialization method from $app_file"

    # Use perl line-by-line processing for more reliable method and import removal
      perl -i -ne '
        BEGIN { $in_method = $braces = $removed = $found_bean = 0; }

        # Skip target imports - fixed regex pattern
        if (/^import\s+(javax\.sql\.DataSource|org\.springframework\.boot\.autoconfigure\.sql\.init\..*|org\.springframework\.context\.annotation\.Bean|.*SamplePersonRepository.*);/) {
          $removed++; next;
        }

        # Handle @Bean detection and method tracking
        if (/^\s*\@Bean\s*$/) { $found_bean = 1; $removed++; next; }
        if ($found_bean && /SqlDataSourceScriptDatabaseInitializer/) {
          $in_method = 1; $found_bean = 0;
          $braces += tr/\{/\{/ - tr/\}/\}/;
          $removed++; next;
        }
        if ($found_bean && !/SqlDataSourceScriptDatabaseInitializer/ && /\S/) { $found_bean = 0; print "\@Bean\n"; }

        # Track braces inside method and skip lines
        if ($in_method) {
          $braces += tr/\{/\{/ - tr/\}/\}/;
          $removed++;
          if ($braces <= 0) { $in_method = $braces = 0; }
          next;
        }

        print;
        END { warn "Removed $removed lines from SqlDataSourceScriptDatabaseInitializer method and imports\n" if $removed; }
      ' "$app_file"
    fi
}

patchJaxrs() {
  [ -f src/main/webapp/WEB-INF/jboss-deployment-structure.xml ] && return
  warn "Patching $1 to exclude jaxrs subsystem from WildFly deployment"
  cat <<EOF > src/main/webapp/WEB-INF/jboss-deployment-structure.xml
<jboss-deployment-structure>
    <deployment>
        <exclude-subsystems>
            <subsystem name="jaxrs" />
        </exclude-subsystems>
    </deployment>
</jboss-deployment-structure>
EOF
}

updateTheme() {
  F=`grep -rl 'AppShellConfigurator' . --include='*.java'`
  [ -z "$F" ] && return
  if grep -q '@Theme' $F; then
    [ -z "$TEST" ] && warn "removing @Theme annotation from $F" || cmd "## removing @Theme annotation from $F"
    perl -0777 -pi -e 's/\s*\@Theme\s*\(\s*.*?\s*\)\s*//s' $F
  fi
  if ! grep -q 'vaadin/vaadin-lumo-styles/lumo.css' $F; then
    [ -z "$TEST" ] && warn "adding @CssImport for Lumo theme to $F" || cmd "## adding @CssImport for Lumo theme to $F"
    perl -pi -e 's|(public\s+class\s+.*?implements\s+AppShellConfigurator\s*\{)|\@com.vaadin.flow.component.dependency.CssImport("\@vaadin/vaadin-lumo-styles/lumo.css")\n\1|' $F
  fi
}
removeJsImport() {
  value=$1
  # remove @JsModule("$1") if present
  F=`grep -rl "$value" . --include='*.java'`
  [ -z "$F" ] && return
  if grep -q "$value" $F; then
    [ -z "$TEST" ] && warn "removing @JsModule($value) annotation from $F" || cmd "## removing @JsModule($value) annotation from $F"
    perl -0777 -pi -e 's|\s*\@JsModule\s*\(\s*"'$value'"\s*\)||s' $F
  fi
}
addNpmImport() {
  value=$1
  version=$2
  # add import '$1'; to main layout if not present
  F=`grep -rl "AppShellConfigurator" . --include='*.java'`
  [ -z "$F" ] && return
  if ! grep -q "$value" $F; then
    [ -z "$TEST" ] && warn "adding NPM import $value to $F" || cmd "## adding NPM import $value to $F"
    perl -pi -e 's|(public\s+class\s+.*?implements\s+AppShellConfigurator\s*\{)|\@com.vaadin.flow.component.dependency.NpmPackage(value="'$value'", version="'$version'")\n\1|' $F
  fi
}

patchImports() {
  F=`grep -rl "$1" . --include='*.java'`
  for i in $F; do
    [ -z "$TEST" ] && warn "replacing $1 in $i" || cmd "## replacing $1 in $i"
    perl -pi -e 's|'"$1"'|'"$2"'|g' $i
  done
}

patchTestBenchJUnit() {
  # Check if JUnit dependencies are already present
  # https://github.com/vaadin/testbench-demo/issues/185
  if grep -q "junit-vintage-engine" pom.xml; then
    return 0
  fi
  [ -z "$TEST" ] && warn "adding JUnit dependencies to pom.xml" || cmd "## adding JUnit dependencies to pom.xml"
block="    <dependency>
              <groupId>org.junit.vintage</groupId>
              <artifactId>junit-vintage-engine</artifactId>
              <version>5.14.0</version>
              <scope>test</scope>
            </dependency>
            <dependency>
              <groupId>org.junit.jupiter</groupId>
              <artifactId>junit-jupiter-engine</artifactId>
              <version>5.14.0</version>
              <scope>test</scope>
            </dependency>
            <dependency>
              <groupId>org.junit.platform</groupId>
              <artifactId>junit-platform-launcher</artifactId>
              <version>1.14.0</version>
              <scope>test</scope>
            </dependency>"
  _cmd="perl -0777 -pi -e 's|(\s*)</dependencies>|\$1$block\$1</dependencies>|' pom.xml"
  cmd "$_cmd"
  [ -n "$TEST" ] || eval "$_cmd"
}

## Update gs-crud-with-vaadin test to use Mockito extension instead of Spring Boot test
## TODO: needs to be documented in vaadin migration guide to 25
patchTestCrudWithVaadin() {
  local test_file=$(find . -name "*CustomerEditorTests.java" -o -name "*CustomerEditor*Test*.java")
  [ -z "$test_file" ] && return 0
  [ -z "$TEST" ] && warn "updating CustomerEditor test to use Mockito extension in $test_file" || cmd "## updating CustomerEditor test to use Mockito extension in $test_file"
  # 1. Replace import org.mockito.InjectMocks with import org.junit.jupiter.api.extension.ExtendWith
  perl -pi -e 's|import org\.mockito\.InjectMocks;|import org.junit.jupiter.api.extension.ExtendWith;|' "$test_file"
  # 2. Replace import org.springframework.boot.test.context.SpringBootTest with import org.mockito.junit.jupiter.MockitoExtension
  perl -pi -e 's|import org\.springframework\.boot\.test\.context\.SpringBootTest;|import org.mockito.junit.jupiter.MockitoExtension;|' "$test_file"
  # 3. Replace @SpringBootTest with @ExtendWith(MockitoExtension.class)
  perl -pi -e 's|\@SpringBootTest|\@ExtendWith(MockitoExtension.class)|' "$test_file"
  # 4. Remove @InjectMocks annotation
  perl -pi -e 's|(\s*)\@InjectMocks\s*|$1|' "$test_file"
  # 5. Add editor instantiation in init method
  perl -0777 -pi -e 's|(\@BeforeEach\s*\n\s*public\s+void\s+init\(\)\s*\{\s*)|${1}editor = new CustomerEditor(customerRepository);\n\t\t|s' "$test_file"
}


## TODO: Update test to use SpringBootTest instead of DataJpaTest and update CacheConfiguration
patchTestPetClinic() {
  # First patch: Update CacheConfiguration.java
  local T1=src/main/java/org/springframework/samples/petclinic/backend/system/CacheConfiguration.java
  if [ -f $T1 ]; then
    [ -z "$TEST" ] && warn "patching $T1" || cmd "## updating CacheConfiguration to use EHCache autoconfiguration"
    cat <<EOF > $T1
/*
 * Copyright 2012-2019 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */

package org.springframework.samples.petclinic.backend.system;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Cache configuration for the Pet Clinic application.
 * This configuration enables Spring's caching abstraction and defines the required caches.
 */
@Configuration(proxyBeanMethods = false)
@EnableCaching
class CacheConfiguration {
        @Bean
        public CacheManager cacheManager() {
                // Create a simple in-memory cache manager with the required caches
                return new ConcurrentMapCacheManager("vets");
        }
}
EOF
  fi

  # Second patch: Update ClinicServiceTests.java
  local T2=src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java
  if [ -f $T2 ]; then
    [ -z "$TEST" ] && warn "patching $T2" || cmd "## updating ClinicServiceTests to use SpringBootTest"

    patch -p1 <<'EOF'
--- a/src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java
+++ b/src/test/java/org/springframework/samples/petclinic/service/ClinicServiceTests.java
@@ -19,10 +19,7 @@ import java.time.LocalDate;
 import java.util.Collection;
 import org.junit.jupiter.api.Test;
 import org.springframework.beans.factory.annotation.Autowired;
-import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
-import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase.Replace;
-import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
-import org.springframework.context.annotation.ComponentScan;
+import org.springframework.boot.test.context.SpringBootTest;
 import org.springframework.data.domain.Page;
 import org.springframework.data.domain.Pageable;
 import org.springframework.samples.petclinic.backend.owner.Owner;
@@ -34,7 +31,9 @@ import org.springframework.samples.petclinic.backend.vet.Vet;
 import org.springframework.samples.petclinic.backend.vet.VetRepository;
 import org.springframework.samples.petclinic.backend.visit.Visit;
 import org.springframework.samples.petclinic.backend.visit.VisitRepository;
+import org.springframework.samples.petclinic.service.EntityUtils;
 import org.springframework.stereotype.Service;
+import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
 import org.springframework.transaction.annotation.Transactional;

 /**
@@ -63,9 +62,8 @@ import org.springframework.transaction.annotation.Transactional;
  * @author Michael Isvy
  * @author Dave Syer
  */
-@DataJpaTest(includeFilters = @ComponentScan.Filter(Service.class))
-// Ensure that if the mysql profile is active we connect to the real database:
-@AutoConfigureTestDatabase(replace = Replace.NONE)
+@SpringBootTest
+@Transactional
 class ClinicServiceTests {

        @Autowired
EOF
  fi

  # Return error only if neither file exists
  [ ! -f $T1 -a ! -f $T2 ] && err "No files found: $T1 or $T2" && return 1
  return 0

}

## Update Lumo imports in TypeScript files for hilla-quickstart-tutorial
## Replace individual sizing and spacing imports with unified utility.css import
## TODO: needs to be documented in vaadin migration guide to 25
patchLumoImports() {
  local views_dir="src/main/frontend/views"
  [ ! -d "$views_dir" ] && return 0

  # Find all TypeScript files in the views directory
  local ts_files=$(find "$views_dir" -name "*.ts" -type f)
  [ -z "$ts_files" ] && return 0

  local file
  for file in $ts_files; do
    # Check if file contains @vaadin/vaadin-lumo-styles imports that are not utility.css
    local has_other_lumo_imports=$(grep "^import '@vaadin/vaadin-lumo-styles/" "$file" | grep -v "utility\.css" | wc -l)
    if [ "$has_other_lumo_imports" -gt 0 ]; then
      [ -z "$TEST" ] && warn "updating Lumo imports in $file" || cmd "## updating Lumo imports in $file"

      # Remove all @vaadin/vaadin-lumo-styles imports except utility.css
      perl -pi -e "s|^import '\@vaadin/vaadin-lumo-styles/(?!utility\.css).*';\s*\n||" "$file"

      # Add the new unified import if not already present
      if ! grep -q "@vaadin/vaadin-lumo-styles/utility.css" "$file"; then
        # Simply add the import at the top of the file using perl
        perl -i -pe 'print "import '\''\@vaadin/vaadin-lumo-styles/utility.css'\'';\n" if $. == 1' "$file"
      fi
    fi
  done
}

## TODO: needs to be documented in vaadin migration guide to 25
patchMapper() {
  # Find all Java files that contain the JavaTimeModule registration
  local java_files=$(grep -rEl "(.*mapper.registerModule.*JavaTimeModule.*|.*Json.*Exception.*)" . --include="*.java" 2>/dev/null)
  [ -z "$java_files" ] && return 0

  local file
  for file in $java_files; do
    [ -z "$TEST" ] && warn "patching jackson ussage in $file" || cmd "## patching jackson ussage in $file"

    # Remove the JavaTimeModule registration line
    perl -pi -e 's|.*mapper.registerModule.*JavaTimeModule.*||' "$file"

    # Replace IOException or Json.*Exception with Exception in the same file
    perl -pi -e 's/catch \((IOException|Json[A-z]*Exception)/catch (Exception/g' "$file"
  done
}


## Find all java class files that extends AppLayouts and add @AnonymousAllowed
## TODO: verify that this is explained in migration guide
addAnonymousAllowedToAppLayout() {
  find . -name "*.java" -exec grep -l "extends AppLayout[ {]" {} + | while read file; do
    # Insert the annotation above the class definition if not already present
    grep -q "com.vaadin.flow.server.auth.AnonymousAllowed" "$file" && continue
    warn "adding AnonymousAllowed to $file"
    perl -0777 -pi -e 's/(public\s+class\s+[A-Za-z0-9_]+\s+extends\s+AppLayout)/\@AnonymousAllowed\n\1/' "$file"
    # Add import if not present
    grep -q "import com.vaadin.flow.server.auth.AnonymousAllowed;" "$file" || \
      perl -pi -e 's|^(package\s+.*?;\s*)|\1\nimport com.vaadin.flow.server.auth.AnonymousAllowed;\n|' "$file"
  done
}

## Replaces vaadin-spring dependency with vaadin-spring-boot-starter in Maven projects
## This is needed for Vaadin v25 migration where vaadin-spring is deprecated
## TODO: verify that is explained in migration guide
replaceVaadinSpringWithStarter() {
  if [ -f "pom.xml" ]; then
    # Check if vaadin-spring dependency exists (not as exclusion)
    if grep -A 2 -B 2 "vaadin-spring" pom.xml 2>/dev/null | grep -q "<dependency>" 2>/dev/null; then
      # Check if it's not already vaadin-spring-boot-starter
      if ! grep -q "vaadin-spring-boot-starter" pom.xml 2>/dev/null; then
        [ -z "$TEST" ] && warn "Replacing vaadin-spring with vaadin-spring-boot-starter in pom.xml" || cmd "## Replacing vaadin-spring with vaadin-spring-boot-starter in pom.xml"
        
        # Replace vaadin-spring with vaadin-spring-boot-starter
        _cmd="perl -pi -e 's|<artifactId>vaadin-spring</artifactId>|<artifactId>vaadin-spring-boot-starter</artifactId>|g' pom.xml"
        cmd "$_cmd"
        [ -n "$TEST" ] || eval "$_cmd"
      else
        [ -z "$TEST" ] && log "vaadin-spring-boot-starter already present in Maven project"
      fi
    else
      [ -z "$TEST" ] && log "No vaadin-spring dependency found in Maven project"
    fi
  fi
}

## Adds vaadin-dev dependency for projects without Spring
## Checks if Spring is not present in build files and adds vaadin-dev dependency
## TODO: verify that is explained in migration guide
# $1 optional
addDevModeIfNeeded() {
  # Add vaadin-dev dependency if Spring is not found
    # Handle Maven projects
    if [ -f "pom.xml" ]; then
      # Check for actual dependency, not exclusions
      if ! grep -A 2 -B 2 "vaadin-dev" pom.xml 2>/dev/null | grep -q "<dependency>" 2>/dev/null; then
        [ -z "$TEST" ] && log "Adding vaadin-dev dependency to Maven project"
        addMavenDep "com.vaadin" "vaadin-dev" "compile" "$1"
      else
        [ -z "$TEST" ] && log "vaadin-dev dependency already present in Maven project"
      fi
    fi

    # Handle Gradle projects
    if [ -f "build.gradle" ]; then
      if ! grep -q "vaadin-dev" build.gradle 2>/dev/null; then
        [ -z "$TEST" ] && log "Adding vaadin-dev dependency to Gradle project"
        addGradleDep "com.vaadin" "vaadin-dev"
      else
        [ -z "$TEST" ] && log "vaadin-dev dependency already present in Gradle project"
      fi
    fi
}

## Adds Hilla Spring Boot Starter dependency if project uses Hilla
## Checks for Java files with Hilla imports or TypeScript files in views directories
## TODO: verify that is explained in migration guide
addHillaStarterIfNeeded() {
  local add_hilla=false
  local app=$1
  if [ -z "$app" ]; then
    app=`basename $PWD`
  fi
  case "$app" in
    initializer*react) add_hilla=true ;;
  esac

  # Check for Java files with Hilla imports
  if find . -name "*.java" -type f 2>/dev/null | xargs grep -l "import com\.vaadin\.hilla\." 2>/dev/null | grep -q .; then
    add_hilla=true
    [ -z "$TEST" ] && log "Found Java files with Hilla imports"
  fi

  # Check for TypeScript files in views directories
  if find . -path "*/src/main/frontend/views/*.ts" -o -path "*/frontend/views/*.ts" -o -path "*/src/main/frontend/views/*.tsx" -o -path "*/frontend/views/*.tsx" 2>/dev/null | grep -q .; then
    add_hilla=true
    [ -z "$TEST" ] && log "Found TypeScript view files"
  fi



  # Add Hilla Spring Boot Starter if conditions are met
  if [ "$add_hilla" = true ]; then
    # Handle Maven projects
    if [ -f "pom.xml" ]; then
      if ! grep -q "hilla-spring-boot-starter" pom.xml 2>/dev/null; then
        [ -z "$TEST" ] && log "Adding Hilla Spring Boot Starter dependency to Maven project"
        addMavenDep "com.vaadin" "hilla-spring-boot-starter" "compile"
      else
        [ -z "$TEST" ] && log "Hilla Spring Boot Starter dependency already present in Maven project"
      fi
    fi

    # Handle Gradle projects
    if [ -f "build.gradle" ]; then
      if ! grep -q "hilla-spring-boot-starter" build.gradle 2>/dev/null; then
        [ -z "$TEST" ] && log "Adding Hilla Spring Boot Starter dependency to Gradle project"
        addGradleDep "com.vaadin" "hilla-spring-boot-starter"
      else
        [ -z "$TEST" ] && log "Hilla Spring Boot Starter dependency already present in Gradle project"
      fi
    fi
  else
    [ -z "$TEST" ] && log "No Hilla usage detected, skipping Hilla Spring Boot Starter"
  fi
}

## Adds a Gradle dependency to build.gradle
## $1 groupId
## $2 artifactId
addGradleDep() {
  local groupId=$1
  local artifactId=$2
  local buildFile="build.gradle"

  [ ! -f "$buildFile" ] && return 0

  # Check if vaadin-spring-boot-starter is present to add after it
  if grep -q "implementation.*com\.vaadin:vaadin-spring-boot-starter" "$buildFile"; then
    [ -z "$TEST" ] && warn "Adding implementation '$groupId:$artifactId' after vaadin-spring-boot-starter in $buildFile" || cmd "## Adding implementation '$groupId:$artifactId' after vaadin-spring-boot-starter in $buildFile"

    _cmd="perl -pi -e \"s|(\\s*implementation\\s+['\\\"]com\\.vaadin:vaadin-spring-boot-starter['\\\"].*)|\\1\\n    implementation '$groupId:$artifactId'|\" \"$buildFile\""
    cmd "$_cmd"
    [ -n "$TEST" ] || eval "$_cmd"
  else
    # Fallback: add in dependencies block
    if grep -q "dependencies\\s*{" "$buildFile"; then
      [ -z "$TEST" ] && warn "Adding implementation '$groupId:$artifactId' to dependencies in $buildFile" || cmd "## Adding implementation '$groupId:$artifactId' to dependencies in $buildFile"

      _cmd="perl -pi -e \"s|(dependencies\\s*{)|\\1\\n    implementation '$groupId:$artifactId'|\" \"$buildFile\""
      cmd "$_cmd"
      [ -n "$TEST" ] || eval "$_cmd"
    fi
  fi
}



