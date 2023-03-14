
applyv24Patches() {
  app_=$1; type_=$2; vers_=$3
  [ -d src/main ] && D=src/main || D=*/src/main

  case $app_ in
    base-starter-flow-quarkus) changeMavenProperty quarkus.version 999-jakarta-SNAPSHOT ;;
    mpr-demo)
      find . -name MyUI.java | xargs perl -pi -e 's/(\@Push|\@MprTheme.*|\@LegacyUI.*|, *AppShellConfigurator)//g'
      changeMavenBlock dependency com.vaadin vaadin-server "" "" vaadin-server-mpr-jakarta '${11}${12}${1}${2}${3}${4}${5}${6}${7}${8}${9}${10}<scope>provided</scope>${10}'
      addAppConfigClass src/main/java/org/vaadin/mprdemo/ApplicationConfig.java
      ;;
    react*)
      cmd 'perl -pi -e '"'"'s/("\@vitejs\/plugin-react"):.*,/${1}: "^3.1.0"/g'"'"' package.json'
      perl -pi -e 's/("\@vitejs\/plugin-react"):.*,/${1}: "^3.1.0",/g' package.json
      ;;
    bakery-*)
      find src/test -name "*.java" | xargs perl -0777 -pi -e 's/(\@Test[\s\t]*public void editOrder\(\))/\@org.junit.Ignore ${1}/msg'
      ;;
    skeleton-starter-flow-cdi)
      changeMavenBlock plugin org.wildfly.plugins wildfly-maven-plugin "" "" "" '<configuration><version>27.0.0.Final</version></configuration>'
      ;;
    spreadsheet-demo)
      find $D -name "*.java" | xargs perl -pi -e 's/listSelect.setDataProvider/listSelect.setItems/g'
      ;;
  esac


  [ ! -f pom.xml ] || patchPomV24 || return 1
  [ ! -f gradlew ] || patchGradV24 || return 1
  patchSourcesV24 $D

  for i in pom.xml gradle.properties build.gradle; do
    [ -f $i ] && D="$i $D"
  done
  diff_=`git diff $D | egrep '^[+-]'`
  [ -n "$diff_" ] && echo "" && warn "Patched sources\n" && dim "====== BEGIN ======\n\n$diff_\n======  END  ======" || true
}

patchGradV24() {
   upgradeGradle 7.5 || return 1
   perl -pi -e "s|(^\s*sourceCompatibility *= *).*$|\$1'17'|" build.gradle
   perl -pi -e "s|(^\s*servletContainer *= *).*$|\$1'jetty11'|" build.gradle
   perl -pi -e "s|(^.*org\.gretty.*version\s*).*$|\$1'4.0.3'|" build.gradle
   perl -pi -e "s|(^.*org\.springframework\.boot.*version\s*).*$|\$1'3.0.2'|" build.gradle
}

patchPomV24() {
    ## This is a bit tricky since javax.servlet might be without the version tag
    changeMavenBlock dependency javax.servlet javax.servlet-api 5.0.0
    changeMavenBlock dependency jakarta.servlet jakarta.servlet-api 5.0.0
    changeMavenBlock dependency javax.servlet javax.servlet-api "" jakarta.servlet jakarta.servlet-api
    ##

    changeMavenBlock parent org.springframework.boot spring-boot-starter-parent 3.0.4
    removeMavenBlock dependency javax.xml.bind jaxb-api
    changeMavenBlock dependency javax javaee-api 8.0.0 jakarta.platform jakarta.jakartaee-api

    changeMavenBlock plugin org.eclipse.jetty jetty-maven-plugin 11.0.13

    # removeMavenProperty selenium.version
    changeMavenProperty selenium.version 4.8.1
    changeMavenProperty java.version 17
    changeMavenProperty maven.compiler.source 17
    changeMavenProperty maven.compiler.target 17
    changeMavenProperty jetty.version 11.0.13
    changeMavenProperty jetty.plugin.version 11.0.13
    changeMavenBlock dependency org.apache.tomee.maven tomee-maven-plugin 9.0.0.RC1
    changeMavenBlock dependency org.wildfly.plugins wildfly-maven-plugin 4.0.0.Final
    changeMavenBlock dependency com.vaadin.k8s vaadin-cluster-support 2.0-SNAPSHOT
    changeMavenBlock dependency com.vaadin exampledata 6.2.0
}

patchSourcesV24() {
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
