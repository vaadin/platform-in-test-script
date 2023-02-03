
applyPatches() {
  app_=$1
  vers_=$2
  case $app_ in
    base-starter-flow-quarkus)
      patchProperty quarkus.version 999-jakarta-SNAPSHOT
      patchProperty maven.compiler.source 17
      patchProperty maven.compiler.target 17
    ;;
  esac
  if [ "$vers_" != current ]; then
    patchServletDep
    patchTo24
    patchSpring 3.1 3.1
    patchProperty java.version 17
    patchProperty jetty.version 11.0.13
    patchProperty jetty.plugin.version 11.0.13
    patchDependency org.apache.tomee.maven:tomee-maven-plugin 9.0.0.RC1
    patchDependency org.wildfly.plugins:wildfly-maven-plugin 4.0.0.Final
    patchDependency com.vaadin.k8s:vaadin-cluster-support 2.0-SNAPSHOT
    patchDependency com.vaadin:exampledata 6.1.0

    [ -d src/main ] && D=src/main || D=*/src/main
    H=`git diff pom.xml $D | egrep '^[+-]'`
    [ -n "$H" ] && warn "patched sources \n$H"
  fi
}

patchSpring() {
  currMinor="$1"
  nextMinor="$2"
  __artifact=`mvn help:evaluate -q -DforceStdout -Dexpression=project.parent.artifactId`
  if [ "$__artifact" = "spring-boot-starter-parent" ]; then
    __from=`mvn help:evaluate -q -DforceStdout -Dexpression=project.parent.version | cut -d . -f1,2`
    expr "$__from" : "$currMinor" >/dev/null && return
    expr "$__from" : "$nextMinor" >/dev/null && return
    _cmd="mvn -q versions:update-parent -DparentVersion=[,$nextMinor)"
    cmd "$_cmd" && $_cmd
    __to=`mvn help:evaluate -q -DforceStdout -Dexpression=project.parent.version`
    warn "Patched spring-boot-starter-parent from $__from to $__to"
  fi
}

patchProperty() {
  __curr=`grep "<$1>" pom.xml | perl -pe 's/\s*<'$1'>(.*)<\/'$1'>\s*/$1/g'`
  # __curr=`mvn help:evaluate -q -DforceStdout -Dexpression=$1`
  if [ -n "$__curr" -a "$__curr" != "$2" ]; then
    _cmd="mvn -B -q versions:set-property -Dproperty=$1 -DnewVersion=$2"
    cmd "$_cmd" && $_cmd
    warn "Patched $1 from $__curr to $2"
  fi
}

patchDependency() {
  H=`mvn dependency:list 2>/dev/null | grep $1 | sed -e 's/ *\[INFO\] *//g'`
  [ -z "$H" ] && return
  _cmd="mvn -q versions:use-dep-version -Dincludes=$1 -DdepVersion=$2 -DforceVersion=true"
  cmd "$_cmd" && $_cmd
  warn "Patched $H -> "`mvn dependency:list | grep "$1" | sed -e 's/ *\[INFO\] *//g'`
}

patchServletDep() {
  H=`mvn dependency:list | grep javax.servlet | sed -e 's/ *\[INFO\] *//g'`
  [ -z "$H" ] && return
  find . -name pom.xml | xargs perl -pi -e 's/((?:groupId|artifactId)>)javax(\.servlet)/$1jakarta$2/g'
  patchDependency jakarta.servlet:jakarta.servlet-api 5.0.0-M2
}

## 24.0
patchTo24() {
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

  find . -name pom.xml | xargs perl -pi -e 's/.*<selenium.version>.*//msg'

  find . -name pom.xml | xargs perl -0777 -pi -e 's/<dependency>\s*<groupId>javax.xml.bind<\/groupId>\s*<artifactId>jaxb-api<\/artifactId>\s*(<version>.+?<\/version>)?\s*<\/dependency>[ \n]*//msg'
  ## cdi
  find . -name pom.xml | xargs perl -0777 -pi -e 's/(<dependency>\s*<groupId>)javax(<\/groupId>\s*<artifactId>)javaee-api(<\/artifactId>\s*<version>).+?(<\/version>\s*<scope>provided<\/scope>\s*<\/dependency>[ \n]*)/$1jakarta.platform$2jakarta.jakartaee-api${3}8.0.0$4/msg'
  find . -name pom.xml | xargs perl -0777 -pi -e 's/(<plugin>\s*<groupId>org.wildfly.plugins<\/groupId>\s*<artifactId>wildfly-maven-plugin<\/artifactId>\s*<version>).+?(<\/version>\s*<configuration>\s*<version>).+?(<\/version>\s*<\/configuration>\s*<\/plugin>[ \n]*)/${1}2.1.0.Final${2}27.0.0.Final${3}/msg'


  ## spreadsheet
  find $D -name "*.java" | xargs perl -pi -e 's/listSelect.setDataProvider/listSelect.setItems/g'

  # bakery https://github.com/vaadin/flow/issues/15763
  if [ -d src/test ]; then
    find src/test -name "*.java" | xargs perl -pi -e 's/Assert.assertEquals\("maximum length is 255 characters", getErrorMessage\(textFieldElement\)\)/Assert.assertTrue(getErrorMessage(textFieldElement).matches("(maximum length is 255 characters|size must be between 0 and 255)"));/g'
    # find src/test -name "*.java" | xargs perl -pi -e 's/(productsPage|usersView|page)\.getSearchBar\(\).getCreateNewButton\(\)/${1}.getNewItemButton().get()/g'
    find src/test -name "*.java" | xargs perl -0777 -pi -e 's/(\@Test[\s\t]*public void editOrder\(\))/\@org.junit.Ignore ${1}/msg'
  fi
  echo pom.xml | xargs perl -0777 -pi -e 's/(vaadin-prereleases<\/url>\s*<snapshots>\s*<enabled>)false/${1}true/msg'
}

## k8s-demo-app 23.3.0.alpha2
patchOldSpringProjects() {
  patchSpring 2.7 2.8 23.3.0.alpha2
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
