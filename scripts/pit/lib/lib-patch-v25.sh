

applyv25patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d src/main ] && D=src/main || D=*/src/main
  F=$D/frontend

  changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 4.0.0-M3
  setVersionInGradle "org.springframework.boot" "4.0.0-M3"
  addAnonymousAllowedToAppLayout
  updateAppLayoutAfterNavigation
  updateSpringBootApplication
  updateGradleWrapper
  cleanAfterBumpingVersions
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
      ;;
    testbench-demo)
      ## TODO: changes are already in v25, make it main branch when 25.0 GA
      patchTestBenchJUnit
      ;;
  esac
  ## TODO: document in migration guide to 25
  patchImports 'import com.fasterxml.jackson.core.type.TypeReference;' 'import tools.jackson.core.type.TypeReference;' 

  diff_=`git diff $D $F | egrep '^[+-]'`
  [ -z "$TEST" -a -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======"

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
  computeGradle
  if [ -f build.gradle ]; then
    ## vaadinClean is not enough it needs to clean everything also
    runCmd "Removing build artifacts" "rm -rf build package-lock.json tsconfig* types* vite* target* src/main/frontend/generated/ src/main/bundles"
    runCmd "Cleaning project after version bump" "$GRADLE clean vaadinClean"
    return
  fi
  [ -z "$NOCURRENT" ] && [ ! -d target ] && return
  ## vaadin:clean-frontend is not enough it needs to clean target too
  ## note that archetype-spring (and maybe others) needs the production profile to have vaadin plugin available
  grep -q "flow-maven-plugin" pom.xml && mplugin=flow || mplugin=vaadin
  runCmd "Cleaning project after version bump" "mvn clean $mplugin:clean-frontend -Pproduction"
}

## Find all java class files that extend AppLayout and have afterNavigation() method, then update them to implement AfterNavigationObserver
## This break change is in https://github.com/vaadin/flow-components/issues/5449
## TODO: needs to be documented in vaadin migration guide to 25 and updated in starter repos
updateAppLayoutAfterNavigation() {
  find src -name "*.java" -exec grep -l "extends AppLayout" {} + | xargs grep -L "extends AppLayoutElement" | while read file; do
    # Check if the file contains afterNavigation method
    if grep -q "afterNavigation()" "$file"; then
      [ -z "$TEST" ] && warn "updating afterNavigation method in $file" || cmd "## updating afterNavigation method in $file"

      # Check if already implements AfterNavigationObserver
      if ! grep -q "implements.*AfterNavigationObserver" "$file"; then
        # Add implements AfterNavigationObserver to class declaration
        _cmd1="perl -pi -e 's/(public\s+class\s+[A-Za-z0-9_]+\s+extends\s+AppLayout)(\s*)(\{)/\$1 implements com.vaadin.flow.router.AfterNavigationObserver\$2\$3/' \"$file\""
        cmd "$_cmd1"
        [ -n "$TEST" ] || eval "$_cmd1"
      fi

      # Transform the method - handle both with and without @Override in one pattern
      _cmd2="perl -0777 -pi -e 's/(\s+)(?:@Override\s+)?protected\s+void\s+afterNavigation\(\)\s*\{\s*super\.afterNavigation\(\);\s*/\$1@Override\n\$1public void afterNavigation(com.vaadin.flow.router.AfterNavigationEvent event) {\n\$1/gs' \"$file\""
      cmd "$_cmd2"
      [ -n "$TEST" ] || eval "$_cmd2"
    fi
  done
}

## Find Application class with @SpringBootApplication and remove database initialization method and unused imports
## This is needed when upgrading to new Spring Boot versions where manual database initialization is no longer required
## TODO: needs to be documented in vaadin migration guide to 25
updateSpringBootApplication() {
  # Find the Application class with @SpringBootApplication annotation
  local app_file=$(find src -name "*.java" -exec grep -l "@SpringBootApplication" {} +)

  [ -z "$app_file" ] && return 0

  # Check if file contains the SqlDataSourceScriptDatabaseInitializer method
  if grep -q "SqlDataSourceScriptDatabaseInitializer" "$app_file"; then
    [ -z "$TEST" ] && warn "removing database initialization method from $app_file" || cmd "## removing database initialization method from $app_file"

    # Use perl line-by-line processing for more reliable method and import removal
    if [ -z "$TEST" ]; then
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
  F=`grep -rl 'AppShellConfigurator' src/main/java --include='*.java'`
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
  F=`grep -rl "$value" src/main/java --include='*.java'`
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
  F=`grep -rl "AppShellConfigurator" src/main/java --include='*.java'`
  [ -z "$F" ] && return
  if ! grep -q "$value" $F; then
    [ -z "$TEST" ] && warn "adding NPM import $value to $F" || cmd "## adding NPM import $value to $F"
    perl -pi -e 's|(public\s+class\s+.*?implements\s+AppShellConfigurator\s*\{)|\@com.vaadin.flow.component.dependency.NpmPackage(value="'$value'", version="'$version'")\n\1|' $F
  fi
}

patchImports() {
  F=`grep -rl "$1" src/main/java --include='*.java'`
  for i in $F; do
    [ -z "$TEST" ] && warn "replacing $1 in $i" || cmd "## replacing $1 in $i"
    perl -pi -e 's|'"$1"'|'"$2"'|g' $i
  done
}

patchTestBenchJUnit() {
  # Check if JUnit dependencies are already present
  if grep -q "junit-vintage-engine" pom.xml; then
    return 0
  fi
  [ -z "$TEST" ] && warn "adding JUnit dependencies to pom.xml" || cmd "## adding JUnit dependencies to pom.xml"
block="    <dependency>
              <groupId>org.junit.vintage</groupId>
              <artifactId>junit-vintage-engine</artifactId>
              <version>5.13.1</version>
              <scope>test</scope>
            </dependency>
            <dependency>
              <groupId>org.junit.jupiter</groupId>
              <artifactId>junit-jupiter-engine</artifactId>
              <version>5.13.1</version>
              <scope>test</scope>
            </dependency>
            <dependency>
              <groupId>org.junit.platform</groupId>
              <artifactId>junit-platform-launcher</artifactId>
              <version>1.13.1</version>
              <scope>test</scope>
            </dependency>"
  _cmd="perl -0777 -pi -e 's|(\s*)</dependencies>|\$1$block\$1</dependencies>|' pom.xml"
  cmd "$_cmd"
  [ -n "$TEST" ] || eval "$_cmd"
}