## bakery 23.1 (fixed)
patchRouterLink() {
  find src -name "*.java" | xargs perl -pi -e 's/RouterLink\(null, /RouterLink("", /g'
  H=`git status --porcelain src`
  if [ -n "$H" ]; then
    log "patched RouterLink occurrences in files: $F"
  fi
}

## Karaf 23.2.2
patchKarafLicenseOsgi() {
  __pom=main-ui/pom.xml
  [ -f $__pom ] && warn "Patching $__pom (adding license-checker 1.10.0)" && perl -pi -e \
    's,</dependencies>,<dependency><groupId>com.vaadin</groupId><artifactId>license-checker</artifactId><version>1.10.0</version></dependency></dependencies>,' \
    $__pom
}

## k8s-demo-app 23.3.0.alpha2
patchOldSpringProjects() {
  __artifact=`mvn help:evaluate -q -DforceStdout -Dexpression=project.parent.artifactId`
  if [ "$__artifact" = "spring-boot-starter-parent" ]; then
    __vers=`mvn help:evaluate -q -DforceStdout -Dexpression=project.parent.version | cut -d . -f1,2`
    [ "$__vers" != "2.7" ] && warn "Patching spring-boot-starter-parent from $__vers to 2.7.0" && mvn -q versions:update-parent -DparentVersion=2.7.0
  fi
}

## skeleton-starter-flow-spring 23.3.0.alpha2
patchIndexTs() {
  __file="frontend/index.ts"
  if grep -q 'vaadin/flow-frontend' $__file; then
    warn "Patching $__file because it has vaadin/flow-frontend/ occurrences"
    perl -pi -e 's,\@vaadin/flow-frontend/,Frontend/generated/jar-resources/,g' $__file
  fi
}