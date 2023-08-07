__scripts=

## Run after updating Vaadin/Hilla versions in order to patch sources
applyPatches() {
  app_=$1; type_=$2; vers_=$3; mod_=$4
  [ -n "$TEST" ] || log "Applying Patches for $app_ $type_ $vers_"
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
      [ -z "$TEST" ] && warn removing tsconfig.json
      cmd "rm -f tsconfig.json"
      rm -f tsconfig.json
      [ -z "$TEST" ] && warn removing ~/vaadin/node*
      cmd "rm -rf ~/vaadin/node*"
      rm -rf ~/vaadin/node*
      ;;
  esac
  case $vers_ in
    *alpha*|*beta*|*rc*|*SNAP*) addPrereleases; enableSnapshots ;;
  esac
  [ "$type_" = current ] && return 0
  case $vers_ in
    24.0*|2.0*)
      . $PIT_SCR_FOLDER/lib/lib-patch-v24.sh
      [ "$type_" = 'next' ] && applyv24Patches "$app_" "$type_" "$vers_"
      ;;
  esac
}

## Run at the beginning of Validate in order to skip upsupported app/version combination
isUnsupported() {
  app_=$1; mod_=$2; vers_=$3;

  ## FIXED - Jetty fails in 23.3 + Linux https://github.com/vaadin/flow/issues/16097
  # [ $app_ = archetype-jetty -a $vers_ = 23.3.6 -a $mod_ = dev ] && isLinux && return 0

  ## Karaf and OSGi unsupported in 24.x
  [ $app_ = vaadin-flow-karaf-example -o $app_ = base-starter-flow-osgi ] && return 0

  ## Everything else is supported
  return 1
}



## FIXED - k8s-demo-app 23.3.0.alpha2
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