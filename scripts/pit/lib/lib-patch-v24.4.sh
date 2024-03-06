
applyv244Patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d frontend ] && F=frontend || F=*/frontend
  [ -d src/main ] && D=src/main || D=*/src/main

  case $app_ in
      *-gradle)
        echo "Patching Gradle project"
        [ "$app_" = "initializer-hilla-gradle" ] && patchInitializer && patchReactV244
        patchGradV244
        patchHillaSourcesV244 $D $F
        ;;
      *-react|*-react-*|*-react_*|react-*|hilla-crm-tutorial|flow-hilla-hybrid-example)
      echo "Patching React project"
        patchReactV244
        patchHillaSourcesV244 $D $F
        ;;
      *-lit|*-lit-*|*-lit_*|*-hilla-*|*-hilla|hilla-*)
      echo "Patching Lit project"
        patchLitV244
        patchHillaSourcesV244 $D $F
        ;;
      gs-crud-with-vaadin)
        ## TODO remove this when gs-crud-with-vaadin is fixed
        warn "Adding vaadin-maven-plugin to build block in pom.xml"
        perl -0777 -pi -e 's|(\s+)(</plugin>)|${1}${2}${1}<plugin>${1}    <groupId>com.vaadin</groupId>${1}    <artifactId>vaadin-maven-plugin</artifactId>${1}    <executions><execution><goals><goal>prepare-frontend</goal></goals></execution></executions>${1}</plugin>|' pom.xml
        ;;
      skeleton-starter-flow|base-starter-flow-quarkus|skeleton-starter-flow-cdi|archetype-jetty)
        warn "Adding exclusion for hilla-dev in pom.xml"
        perl -0777 -pi -e 's!(\s+)(<artifactId>(vaadin|vaadin-quarkus-extension)</artifactId>)!${1}${2}${1}<exclusions>${1}    <exclusion>${1}        <groupId>com.vaadin</groupId>${1}        <artifactId>hilla-dev</artifactId>${1}    </exclusion>${1}</exclusions>!' pom.xml
        ;;
  esac

  diff_=`git diff $D $F | egrep '^[+-]'`
  [ -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======" || true
}

patchHillaSourcesV244() {
  find $D -name "*.java" -exec perl -pi -e 's/import dev.hilla/import com.vaadin.hilla/g' '{}' ';'
  if [ -d "$F" ]; then
    find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/form|\@vaadin/hilla-lit-form|g' '{}' ';'
    find $F -name "*.ts" -exec perl -pi -e 's|Frontend/generated/dev/hilla|Frontend/generated/com/vaadin/hilla|g' '{}' ';'
    find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/frontend|\@vaadin/hilla-frontend|g' '{}' ';'
    find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/frontend|\@vaadin/hilla-frontend|g' '{}' ';'
    find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/react-form|\@vaadin/hilla-react-form|g' '{}' ';'
    find $F -name "*.ts" -exec perl -pi -e 's|\@hilla/|\@vaadin/|g' '{}' ';'
    find $F -name "*.tsx" -exec perl -pi -e 's|\@hilla/|\@vaadin/|g' '{}' ';'
    #cleanFrontendFiles
  fi
}

cleanFrontendFiles() {
  warn "Cleaning frontend package files"
  cmd "rm -rf package*.json node_modules"
  rm -rf package*.json node_modules
}


patchInitializer() {
  perl -pi -e 's|id\s+.dev\.hilla.\s+version\s+..+|id "com.vaadin" version "'$vers_'"|' build.gradle
  perl -0777 -pi -e 's|(repositories.*mavenCentral..\s+)|$1maven { setUrl("https://maven.vaadin.com/vaadin-prereleases") }\n|ms' build.gradle
  perl -0777 -pi -e 's|(.*)|pluginManagement {repositories {\n mavenLocal()\nmaven { setUrl("https://maven.vaadin.com/vaadin-prereleases") }\ngradlePluginPortal()\n}}\n${1}|ms' settings.gradle
  perl -0777 -pi -e 's|(.*)|buildscript {repositories {\n mavenCentral()\nmaven { setUrl("https://maven.vaadin.com/vaadin-prereleases") }\n}}\n${1}|ms' build.gradle
}

patchGradV244() {
  perl -pi -e "s|dev\.hilla:hilla-bom|com.vaadin:vaadin-bom|" build.gradle
  perl -pi -e "s|dev\.hilla:hilla-(react-)?spring-boot-starter|com.vaadin:vaadin-spring-boot-starter|" build.gradle
  [ -f gradle.properties ] && perl -pi -e "s|hillaVersion|vaadinVersion|" build.gradle settings.gradle gradle.properties
  perl -pi -e "s|dev\.hilla|com.vaadin|" build.gradle settings.gradle
}

patchReactV244() {
  renameMavenProperty hilla.version vaadin.version
  removeMavenBlock dependency dev.hilla hilla-react
  patchPomV244
}
patchLitV244() {
  renameMavenProperty hilla.version vaadin.version
  changeMavenBlock dependency dev.hilla hilla "\\\${vaadin.version}" com.vaadin vaadin
  patchPomV244
  perl -pi -e "s|(\s+)(<artifactId>vaadin-maven-plugin</artifactId>)|\$1\$2\n\$1<configuration><reactEnable>false</reactEnable></configuration>|g" pom.xml
}
patchPomV244() {
  changeMavenBlock dependency dev.hilla hilla-bom "\\\${vaadin.version}" com.vaadin vaadin-bom
  changeMavenBlock dependency dev.hilla hilla-spring-boot-starter "\\\${vaadin.version}" com.vaadin vaadin-spring-boot-starter
  changeMavenBlock dependency dev.hilla hilla-react-spring-boot-starter "\\\${vaadin.version}" com.vaadin vaadin-spring-boot-starter
  changeMavenBlock plugin dev.hilla hilla-maven-plugin "\\\${vaadin.version}" com.vaadin vaadin-maven-plugin
}

