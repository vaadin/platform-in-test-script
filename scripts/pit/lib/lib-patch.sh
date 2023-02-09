
applyPatches() {
  app_=$1
  vers_=$2
  case $app_ in
    base-starter-flow-quarkus)
      [ "$vers_" = current ] && return
      changeMavenProperty quarkus.version 999-jakarta-SNAPSHOT
    ;;
    mpr-demo)
      [ "$vers_" = current ] && return
      find . -name MyUI.java | xargs perl -pi -e 's/(\@Push|\@MprTheme.*|\@LegacyUI.*|, *AppShellConfigurator)//g'
      find . -name MyUI.java | xargs perl -pi -e 's/(\@Push|\@MprTheme.*|\@LegacyUI.*|, *AppShellConfigurator)//g'

      changeMavenBlock dependency com.vaadin vaadin-server "" "" vaadin-server-mpr-jakarta '${11}${12}${1}${2}${3}${4}${5}${6}${7}${8}${9}${10}<scope>provided</scope>${10}'
      addAppConfigClass src/main/java/org/vaadin/mprdemo/ApplicationConfig.java
      ;;
    react*)
      [ "$vers_" = current ] && return
      cmd 'perl -pi -e '"'"'s/("\@vitejs\/plugin-react"):.*,/${1}: "^3.1.0"/g'"'"' package.json'
      perl -pi -e 's/("\@vitejs\/plugin-react"):.*,/${1}: "^3.1.0",/g' package.json
      ;;
    skeleton-starter-flow-cdi)
      [ "$vers_" = current ] && return
      changeMavenBlock plugin org.wildfly.plugins wildfly-maven-plugin "" "" "" '<configuration><version>27.0.0.Final</version></configuration>'
      ;;
  esac

  if [ "$vers_" != current ]; then
    perl -0777 -pi -e 's/(vaadin-prereleases<\/url>\s*<snapshots>\s*<enabled>)false/${1}true/msg' pom.xml
    ## This is a bit tricky since javax.servlet might be without the version tag
    changeMavenBlock dependency javax.servlet javax.servlet-api 5.0.0
    changeMavenBlock dependency jakarta.servlet jakarta.servlet-api 5.0.0
    changeMavenBlock dependency javax.servlet javax.servlet-api "" jakarta.servlet jakarta.servlet-api
    ##

    changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 3.0.2
    removeMavenBlock dependency javax.xml.bind jaxb-api
    changeMavenBlock dependency javax javaee-api 8.0.0 jakarta.platform jakarta.jakartaee-api

    removeMavenProperty selenium.version
    changeMavenProperty java.version 17
    changeMavenProperty maven.compiler.source 17
    changeMavenProperty maven.compiler.target 17
    changeMavenProperty jetty.version 11.0.13
    changeMavenProperty jetty.plugin.version 11.0.13
    changeMavenBlock dependency org.apache.tomee.maven tomee-maven-plugin 9.0.0.RC1
    changeMavenBlock dependency org.wildfly.plugins wildfly-maven-plugin 4.0.0.Final
    changeMavenBlock dependency com.vaadin.k8s vaadin-cluster-support 2.0-SNAPSHOT
    changeMavenBlock dependency com.vaadin exampledata 6.2.0

    patchSources

    [ -d src/main ] && D=src/main || D=*/src/main
    diff_=`git diff pom.xml $D | egrep '^[+-]'`
    [ -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n\n======  END  ======\n"
  fi
}

## 24.0
patchSources() {
  [ -d src/main ] && D=src/main || D=*/src/main
  find $D -name "*.java" | xargs perl -pi -e 's/javax\.(persistence|validation|annotation|transaction|inject|servlet)/jakarta.$1/g'
  find $D -name "*.java" | xargs perl -pi -e 's/import org.hibernate.annotations.Type;//g'
  find $D -name "*.java" | xargs perl -pi -e 's/^\s+\@Type\(type =.*$//g'
  find $D -name "*.java" | xargs perl -pi -e 's/\.antMatchers\(/.requestMatchers(/g'
  find $D -name "*.java" | xargs perl -pi -e 's/VaadinWebSecurityConfigurerAdapter/VaadinWebSecurity/g'
  find $D -name "*.java" | xargs perl -pi -e 's/import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter/import com.vaadin.flow.spring.security.VaadinWebSecurity/g'
  find $D -name "*.java" | xargs perl -pi -e 's/WebSecurityConfigurerAdapter/VaadinWebSecurity/g'
  find $D -name "*.java" | xargs perl -pi -e 's/\.authorizeRequests\(\)/.authorizeHttpRequests()/g'
  find $D -name "*.java" | xargs perl -pi -e 's/[\s]*\w[\w\d]+\.setPreventInvalidInput\([^\)]+\)[;\s]*//g'
  find $D -name "*.properties" | xargs perl -pi -e 's/javax\./jakarta./g'
  ## spreadsheet
  find $D -name "*.java" | xargs perl -pi -e 's/listSelect.setDataProvider/listSelect.setItems/g'

  # bakery https://github.com/vaadin/flow/issues/15763
  # if [ -d src/test ]; then
    # find src/test -name "*.java" | xargs perl -pi -e 's/Assert.assertEquals\("maximum length is 255 characters", getErrorMessage\(textFieldElement\)\)/Assert.assertTrue(getErrorMessage(textFieldElement).matches("(maximum length is 255 characters|size must be between 0 and 255)"));/g'
    # find src/test -name "*.java" | xargs perl -pi -e 's/(productsPage|usersView|page)\.getSearchBar\(\).getCreateNewButton\(\)/${1}.getNewItemButton().get()/g'
    # find src/test -name "*.java" | xargs perl -0777 -pi -e 's/(\@Test[\s\t]*public void editOrder\(\))/\@org.junit.Ignore ${1}/msg'
  # fi
}

## k8s-demo-app 23.3.0.alpha2
patchOldSpringProjects() {
  changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 2.7.4
}

## FIXED - bakery 23.1
patchRouterLink() {
  find src -name "*.java" | xargs perl -pi -e 's/RouterLink\(null, /RouterLink("", /g'
  H=`git status --porcelain src`
  if [ -n "$H" ]; then
    log "patched RouterLink occurrences in files: $F"
  fi
}

## FIXED - Karaf 23.2.2
patchKarafLicenseOsgi() {
  __pom=main-ui/pom.xml
  [ -f $__pom ] && warn "Patching $__pom (adding license-checker 1.10.0)" && perl -pi -e \
    's,</dependencies>,<dependency><groupId>com.vaadin</groupId><artifactId>license-checker</artifactId><version>1.10.0</version></dependency></dependencies>,' \
    $__pom
}

## FIXED - skeleton-starter-flow-spring 23.3.0.alpha2
patchIndexTs() {
  __file="frontend/index.ts"
  if test -f "$__file" && grep -q 'vaadin/flow-frontend' $__file; then
    warn "patch 23.3.0.alpha2 - Patching $__file because it has vaadin/flow-frontend/ occurrences"
    perl -pi -e 's,\@vaadin/flow-frontend/,Frontend/generated/jar-resources/,g' $__file
  fi
}

## FIXED - latest-typescript*, vaadin-flow-karaf-example, base-starter-flow-quarkus, base-starter-flow-osgi, 23.3.0.alpha3
patchTsConfig() {
  H=`ls -1 tsconfig.json */tsconfig.json 2>/dev/null`
  [ -n "$H" ] && warn "patch 23.3.0.alpha3 - Removing $H" && rm -f tsconfig.json */tsconfig.json
}

addAppConfigClass() {
cat << EOF > $1
package org.vaadin.mprdemo;

import com.vaadin.flow.component.page.AppShellConfigurator;
import com.vaadin.flow.component.page.Push;
import com.vaadin.mpr.core.LegacyUI;
import com.vaadin.mpr.core.MprTheme;

@Push
@MprTheme("mytheme")
@LegacyUI(OldUI.class)
public class ApplicationConfig implements AppShellConfigurator {
}
EOF
[ $? != 0 ] && return 1
git add $1
}
