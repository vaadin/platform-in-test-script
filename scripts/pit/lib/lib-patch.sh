__scripts=

## Run after updating Vaadin/Hilla versions in order to patch sources
applyPatches() {
  app_=$1; type_=$2; vers_=$3; mod_=$4
  [ -n "$TEST" ] || log "Applying Patches for $app_ $type_ $vers_"

  case $vers_ in
    *alpha*|*beta*|*rc*|*SNAP*) addPrereleases;;
  esac
  expr "$vers_" : ".*SNAPSHOT" >/dev/null && enableSnapshots
  expr "$vers_" : "24.3.0.alpha.*" >/dev/null && addSpringReleaseRepo
  downgradeJava
  removeDeprecated
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
    ce-demo)
      echo $vers_
      case $vers_ in
        # https://github.com/vaadin/collaboration-engine-internal/issues/1049   
        # 24.5*) patchCeLicense ;; 
        # CE is OS since 24.5.0
        24.3*|24.4*) installCeLicense ;;
      esac
      ;;
    form-filler-demo)
      [ -n "$TEST" ] && ([ -z "$OPENAI_TOKEN" ] && cmd "export OPENAI_TOKEN=your_AI_token") && return 0
      [ -z "$OPENAI_TOKEN" ] && err "Set correctly the OPENAI_TOKEN env var" && return 1
      ;;
    initializer*)
       # https://github.com/vaadin/flow/issues/19526#issuecomment-2152719735
       [ -d frontend/generated ] && GN=frontend/generated || GN=src/main/frontend/generated
       [ -d $GN ] && cmd "Cleaning Generated folder: rm -rf $GN" && rm -rf $GN
       ;;
    ### disabled until proper fix for init-app goal https://github.com/vaadin/hilla/issues/2053
    # initializer-hilla-maven)
    #   cmd "$MVN vaadin:init-app" && $MVN -q vaadin:init-app ;;
    # initializer-hilla-gradle)
    #   cmd "$GRADLE -q hillaInitApp" && $GRADLE -q hillaInitApp  >/dev/null ;;
    *hilla*|*-lit*|start)
      ## TODO: adjust 2.4 when hilla-quickstart-tutorial hilla-basics-tutorial are fixed
      # [ "$type_" = 'next' ] <-- removed because it fails in current start projects
      if [ -d frontend ] && echo "$vers_" | grep -Eq "2\.5[\.-].*|24\.3[\.-].*|24\.4[\.-].*" ; then
        _v=`grep -r 'createRenderRoot(): Element' frontend | cut -d ':' -f1 | tr '\n' ' '`
        _cmd="perl -pi -e 's/createRenderRoot\(\): Element \| ShadowRoot/createRenderRoot\(\): HTMLElement | DocumentFragment/g' $_v"
        [ -n "$_v" ] && cmd "$_cmd" && eval "$_cmd"
      fi
      ;;
  esac

  if [ "$type_" = 'current' ]; then
    case $vers_ in
      24.5.*|24.4.*|current) : ;;
      *) reportError "Using old version $vers_" "Please upgrade $app_ to latest stable" ;;
    esac
  fi

  # case $vers_ in
  #   24.0*|2.0*)
  #     . $PIT_SCR_FOLDER/lib/lib-patch-v24.sh
  #     [ "$type_" != 'next' ] && return 0 || applyv24Patches "$app_" "$type_" "$vers_"
  #     ;;
  #   2.3*)
  #     [ "$type_" != 'current' ] && cmd "rm -rf package.json node_modules" && rm -rf package.json node_modules || return 0
  #     ;;
  # esac

  # case $vers_ in
  #   24.4*)
  #     . $PIT_SCR_FOLDER/lib/lib-patch-v24.4.sh
  #     [ "$type_" != 'next' ] && return 0 || applyv244Patches "$app_" "$type_" "$vers_"
  #     ;;
  # esac

  # always successful
  return 0
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


downgradeJava() {
  [ ! -f pom.xml ] && return
  grep -q '<java.version>21</java.version>' pom.xml || return
  cmd "perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml"
  perl -pi -e 's|<java.version>21</java.version>|<java.version>17</java.version>|' pom.xml
  warn "Downgraded Java version from 21 to 17 in pom.xml"
}

removeDeprecated() {
  [ ! -f pom.xml ] && return
  grep -q '<productionMode>true</productionMode>' pom.xml || return
  cmd "perl -0777 -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml"
  perl -pi -e 's|\s*<productionMode>true</productionMode>\s*||' pom.xml
  warn "Removed deprecated productionMode from pom.xml"
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


installCeLicense() {
  LIC=ce-license.json
  [ -n "$TEST" ] && ([ -z "$CE_LICENSE" ] && cmd "## Put a valid CE License in ./$LIC" || cmd "## Copy your CE License to ./$LIC") && return 0
  [ -z "$CE_LICENSE" ] && err "No \$CE_LICENSE provided" && [ -z "$TEST" ] && return 1
  warn "Creating license file ./$LIC with the \$CE_LICENSE content"
  cmd "echo \"\$CE_LICENSE\" > $LIC"
  echo "$CE_LICENSE" > $LIC
}

patchCeLicense() {
warn "Patching CE License in src/main/java/com/jensjansson/ce/Application.java"
cat <<EOF > src/main/java/com/jensjansson/ce/Application.java || return 1
package com.jensjansson.ce;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

import com.jensjansson.ce.bot.BotManager;
import com.jensjansson.ce.data.service.PersonService;
import com.vaadin.collaborationengine.CollaborationEngine;
import com.vaadin.collaborationengine.CollaborationEngineConfiguration;
import com.vaadin.flow.component.page.AppShellConfigurator;
import com.vaadin.flow.component.page.Push;
import com.vaadin.flow.server.PWA;
import com.vaadin.flow.server.ServiceInitEvent;
import com.vaadin.flow.server.VaadinServiceInitListener;
import com.vaadin.flow.theme.Theme;

/**
 * The entry point of the Spring Boot application.
 */
@SpringBootApplication
@PWA(name = "CE Demo", shortName = "CE Demo")
@Push
@Theme("ce-demo")
public class Application extends SpringBootServletInitializer
        implements AppShellConfigurator, VaadinServiceInitListener {

    private static final Logger LOGGER = LoggerFactory.getLogger(Application.class);

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

    @Autowired
    PersonService personService;

    @Override
    public void serviceInit(ServiceInitEvent serviceInitEvent) {
        CollaborationEngine ce = CollaborationEngine.configure(serviceInitEvent.getSource(),
                new CollaborationEngineConfiguration());
        BotManager.createInstance(personService, ce);
    }
}
EOF
}

