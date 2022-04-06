#!/usr/bin/env bash
# This script installs any specified starter project automatically


[[ "$#" != 3 ]] && echo -e "usage: ./vaadin-starter-installer.sh project version branch
example: ./vaadin-starter-installer.sh skeleton-starter-flow-spring 23.0.1 v23" >&2 && exit 1

if [[ -d "$1" ]]; then
  read -p "$1 already exists! Do you want to remove the existing one? y/n " remove
  [[ "$remove" == "y" ]] || [[ "$remove" == "Y" ]] && rm -rf "$1" && git clone https://github.com/vaadin/$1.git && cd "$1"
  [[ "$remove" == "n" ]] || [[ "$remove" == "N" ]] && echo "Error! Remove or rename the old directory before trying again." >&2 && exit 1
fi


version="$2"

git clone https://github.com/vaadin/$1.git && cd "$1"

git checkout "$3"


compilation-fail(){

  echo "$1" >&2
  exit 1
}


base-starter-flow-osgi(){


  mvn clean install >/dev/null && echo "mvn clean install succeeded!" || compilation-fail "mvn clean install failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || compilation-fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  mvn clean install >/dev/null && echo "Bump mvn clean install succeeded!!" || compilation-fail "Bump mvn clean install failed!"

  mvn clean install -Dpnpm.enable=true >/dev/null && echo "mvn clean install with Dpnpm.enable=true succeeded!" \
  || compilation-fail "mvn clean install with Dpnpm.enable=true failed!"

  echo -e "--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"


  exit 0

}


skeleton-starter-flow-cdi(){


  pgrep -f "wildfly" >/dev/null && read -p "wildfly is already running! Do you want to kill it? y/n" answer

  [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]] && pgrep -f "wildfly" | xargs kill
  [[ "$answer" == "n" ]] || [[ "$answer" == "N" ]] && exit 1


  # Press Ctrl-C to continue
  mvn wildfly:run


  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || compilation-fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  # Press Ctrl-C to continue
  mvn clean wildfly:run

  # Press Ctrl-C to continue
  mvn clean wildfly:run -Dpnpm.enable=true

  echo -e "--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"

  exit 0
}


base-starter-spring-gradle(){


  ./gradlew clean bootRun && echo "./gradlew clean bootRun succeeded!"

  perl -pi -e "s/vaadinVersion=.*/vaadinVersion=$version/" gradle.properties || compilation-fail "Could not find gradle.properties!"

  perl -pi -e "s/pluginManagement {/pluginManagement {\n  repositories {\n\tmaven { url = 'https:\/\/maven.vaadin.com\/vaadin-prereleases' }\n\tgradlePluginPortal()\n}/" settings.gradle \
  || compilation-fail "Could not edit settings.gradle!"

  ./gradlew clean bootRun && echo "./gradlew clean bootRun succeeded!"


  echo -e "\n--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"

  exit 0

}


vaadin-flow-karaf-example(){


  mvn install && echo "mvn install succeeded!" || compilation-fail "mvn install failed!"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || compilation-fail "mvn -pl main-ui install -Prun failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  mvn install && echo "1st mvn install succeeded!" || compilation-fail "1st mvn install failed!"

  mvn install && echo "2nd mvn install succeeded!" || compilation-fail "2nd mvn install failed!"

  rm -rf ./main-ui/node_modules && mvn install && echo "rm -rf ./main-ui/node_modules && mvn install succeeded!" || compilation-fail "rm -rf ./main-ui/node_modules && mvn install failed!"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || compilation-fail "mvn -pl main-ui install -Prun failed!"

  mvn install -Dpnpm.enable=true && echo "mvn install -Dpnpm.enable=true succeeded!" || compilation-fail "mvn install -Dpnpm.enable=true failed!"

  mvn -pl main-ui install -Prun -Dpnpm.enable=true && echo "mvn -pl main-ui install -Prun -Dpnpm.enable=true succeeded!" || compilation-fail "mvn -pl main-ui install -Prun -Dpnpm.enable=true failed!"

  rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true  \
  && echo "rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true succeeded!" \
  || compilation-fail "rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true failed!"


  echo -e "--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"

  exit 0

}


base-starter-flow-quarkus(){


  ./mvnw package -Pproduction >/dev/null && echo "mvnw package -Pproduction succeeded!" || compilation-fail "mvnw package -Pproduction failed!"

  ./mvnw package -Pit >/dev/null && echo "mvnw package -Pit succeeded!" || compilation-fail "mvnw package -Pit failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || compilation-fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  ./mvnw >/dev/null && echo "mvnw succeeded!" || compilation-fail "mvnw failed!"

  ./mvnw package -Pproduction >/dev/null && echo "mvnw package -Pproduction succeeded!!" || compilation-fail "mvnw package -Pproduction failed!"

  #./mvnw package -Pit && echo "mvnw package -Pit succeeded!" || echo "mvnw package -Pit failed!"

  echo -e "--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"

  exit 0

}


skeleton-starter-flow-spring(){


  mvn package -Pproduction >/dev/null && echo "mvn package -Pproduction succeeded!" || compilation-fail "mvn package -Pproduction failed!"

  mvn package -Pit >/dev/null && echo "mvn package -Pit succeeded!" || compilation-fail "mvn package -Pit failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || compilation-fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"


  rm -rf node_modules >/dev/null && mvn

  mvn package -Pproduction >/dev/null && echo "mvn package -Pproduction succeeded!" || compilation-fail "mvn package -Pproduction failed!"

  mvn package -Pit >/dev/null && echo "mvn package -Pit succeeded!" || compilation-fail "mvn package -Pit failed!"

  mvn -Dpnpm.enable=true && echo "mvn -Dpnpm.enable=true succeeded!" || compilation-fail "mvn -Dpnpm.enable=true failed!"

  mvn package -Pproduction -Dpnpm.enable=true && echo "mvn package -Pproduction -Dpnpm.enable=true succeeded!" || compilation-fail "mvn package -Pproduction -Dpnpm.enable=true failed!"


  echo -e "--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------"

  exit 0
}



case "$1" in

  base-starter-flow-osgi)
  base-starter-flow-osgi;;

  skeleton-starter-flow-cdi)
  skeleton-starter-flow-cdi;;

  skeleton-starter-flow-spring)
  skeleton-starter-flow-spring;;

  base-starter-spring-gradle)
  base-starter-spring-gradle;;

  vaadin-flow-karaf-example)
  vaadin-flow-karaf-example;;

  base-starter-flow-quarkus)
  base-starter-flow-quarkus;;

esac
