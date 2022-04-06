#!/usr/bin/env bash
# This script installs any specified starter project automatically


# Important: Any test not ran is considered failed!
declare base_starter_flow_osgi_result="Failed"
declare skeleton_starter_flow_cdi_result="Failed"
declare skeleton_starter_flow_spring_result="Failed"
declare base_starter_spring_gradle_result="Failed"
declare base_starter_flow_quarkus_result="Failed"
declare vaadin_flow_karaf_example_result="Failed"

declare setup_result=""


# exit if not given three args
usage(){
  echo -e "usage: ./vaadin-starter-installer.sh project version branch
  example: ./vaadin-starter-installer.sh skeleton-starter-flow-spring 23.0.1 v23" >&2 && exit 1
}


# setup1 tests if you already have a previous project directory and optionally removes it
setup1(){
  if [[ -d "$1" ]]; then

    read -p "$1 already exists! Do you want to remove the existing one? y/n " remove

    if [[ "$remove" == "y" ]] || [[ "$remove" == "Y" ]]; then
      rm -rf "$1" || fail "Failed to remove $1!"
      git clone https://github.com/vaadin/$1.git || fail "Failed to git clone https://github.com/vaadin/$1.git"
      cd "$1" || fail "Failed to cd into ${1}!"

    elif [[ "$remove" == "n" ]] || [[ "$remove" == "N" ]]; then
      fail "Error! Remove or rename the old directory before trying again."

    else
      echo "Error! Please enter a valid answer(y/n)!" >&2
      setup1
    fi
  fi
}


# setup2 tests for any running web servers on port 8080
setup2(){

  version="$2"

  git clone https://github.com/vaadin/$1.git && cd "$1"

  git checkout "$3"

  lsof -i:8080 >/dev/null && read -p "You already have a web server running on port 8080. This will cause a conflict. Do you want to kill the running web server? y/n " answer1 || return

  if [[ "$answer1" == "y" ]] || [[ "$answer1" == "Y" ]]; then
    kill $(lsof -t -i:8080) || fail "Failed to kill the running web server!"

  elif [[ "$answer1" == "n" ]] || [[ "$answer1" == "N" ]]; then
    fail "Error! Stop the running web server before you start the script!"

  else
    echo "Error! Please enter a valid answer(y/n)!" >&2
    setup2
  fi

}


# if an error occurs, call this function
fail(){

  echo "$1" >&2

  if [[ "$setup_result" == "OK" ]]; then
    echo -e "\nResult:\n
    base-starter-flow-osgi: ${base_starter_flow_osgi_result}
    skeleton-starter-flow-cdi: ${skeleton_starter_flow_cdi_result}
    skeleton-starter-flow-spring: ${skeleton_starter_flow_spring_result}
    base-starter-spring-gradle: ${base_starter_spring_gradle_result}
    base-starter-flow-quarkus: ${base_starter_flow_quarkus_result}
    vaadin-flow-karaf-example: ${vaadin_flow_karaf_example_result}
    "
  fi

  exit 1
}



base-starter-flow-osgi(){


  mvn clean install >/dev/null && echo "mvn clean install succeeded!" || fail "mvn clean install failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  mvn clean install >/dev/null && echo "Bump mvn clean install succeeded!!" || fail "Bump mvn clean install failed!"

  mvn clean install -Dpnpm.enable=true >/dev/null && echo "mvn clean install with Dpnpm.enable=true succeeded!" \
  || fail "mvn clean install with Dpnpm.enable=true failed!"

  base_starter_flow_osgi_result="Successful"

  echo -e "\n--------------------------------------------\n| base-starter-flow-osgi build successful! |\n--------------------------------------------\n"


  return

}


skeleton-starter-flow-cdi(){


  pgrep -f "wildfly" >/dev/null && read -p "wildfly is already running! Do you want to kill it? y/n" answer2

  [[ "$answer2" == "y" ]] || [[ "$answer2" == "Y" ]] && pgrep -f "wildfly" | xargs kill
  [[ "$answer2" == "n" ]] || [[ "$answer2" == "N" ]] && exit 1


  # Press Ctrl-C to continue
  mvn wildfly:run


  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  # Press Ctrl-C to continue
  mvn clean wildfly:run

  # Press Ctrl-C to continue
  mvn clean wildfly:run -Dpnpm.enable=true

  skeleton_starter_flow_cdi_result="Successful"

  echo -e "\n-----------------------------------------------\n| skeleton-starter-flow-cdi build successful! |\n-----------------------------------------------\n"


  return
}


base-starter-spring-gradle(){


  ./gradlew clean bootRun && echo "./gradlew clean bootRun succeeded!"

  perl -pi -e "s/vaadinVersion=.*/vaadinVersion=$version/" gradle.properties || fail "Could not find gradle.properties!"

  perl -pi -e "s/pluginManagement {/pluginManagement {\n  repositories {\n\tmaven { url = 'https:\/\/maven.vaadin.com\/vaadin-prereleases' }\n\tgradlePluginPortal()\n}/" settings.gradle \
  || fail "Could not edit settings.gradle!"

  ./gradlew clean bootRun && echo "./gradlew clean bootRun succeeded!" || fail "./gradlew clean bootRun failed!"

  base_starter_spring_gradle_result="Successful"

  echo -e "\n------------------------------------------------\n| base-starter-spring-gradle build successful! |\n------------------------------------------------\n"

  return

}


vaadin-flow-karaf-example(){


  mvn install && echo "mvn install succeeded!" || fail "mvn install failed!"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || fail "mvn -pl main-ui install -Prun failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  mvn install && echo "1st mvn install succeeded!" || fail "1st mvn install failed!"

  mvn install && echo "2nd mvn install succeeded!" || fail "2nd mvn install failed!"

  rm -rf ./main-ui/node_modules && mvn install && echo "rm -rf ./main-ui/node_modules && mvn install succeeded!" || fail "rm -rf ./main-ui/node_modules && mvn install failed!"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || fail "mvn -pl main-ui install -Prun failed!"

  mvn install -Dpnpm.enable=true && echo "mvn install -Dpnpm.enable=true succeeded!" || fail "mvn install -Dpnpm.enable=true failed!"

  mvn -pl main-ui install -Prun -Dpnpm.enable=true && echo "mvn -pl main-ui install -Prun -Dpnpm.enable=true succeeded!" || fail "mvn -pl main-ui install -Prun -Dpnpm.enable=true failed!"

  rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true  \
  && echo "rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true succeeded!" \
  || fail "rm -rf ./main-ui/node_modules && mvn -pl main-ui install -Prun -Dpnpm.enable=true failed!"

  vaadin_flow_karaf_example_result="Successful"

  echo -e "\n-----------------------------------------------\n| vaadin-flow-karaf-example build successful! |\n-----------------------------------------------\n"

  return

}


base-starter-flow-quarkus(){


  ./mvnw package -Pproduction >/dev/null && echo "mvnw package -Pproduction succeeded!" || fail "mvnw package -Pproduction failed!"

  ./mvnw package -Pit >/dev/null && echo "mvnw package -Pit succeeded!" || fail "mvnw package -Pit failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"

  ./mvnw && echo "mvnw succeeded!" || fail "mvnw failed!"

  ./mvnw package -Pproduction >/dev/null && echo "mvnw package -Pproduction succeeded!!" || fail "mvnw package -Pproduction failed!"

  #./mvnw package -Pit && echo "mvnw package -Pit succeeded!" || echo "mvnw package -Pit failed!"

  base_starter_flow_quarkus_result="Successful"

  echo -e "\n-----------------------------------------------\n| base-starter-flow-quarkus build successful! |\n-----------------------------------------------\n"


  return

}


skeleton-starter-flow-spring(){


  mvn package -Pproduction >/dev/null && echo "mvn package -Pproduction succeeded!" || fail "mvn package -Pproduction failed!"

  mvn package -Pit >/dev/null && echo "mvn package -Pit succeeded!" || fail "mvn package -Pit failed!"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!"


  rm -rf node_modules >/dev/null || fail "Failed to remove the node_modules!"

  mvn || fail "mvn failed!"

  mvn package -Pproduction >/dev/null && echo "mvn package -Pproduction succeeded!" || fail "mvn package -Pproduction failed!"

  mvn package -Pit >/dev/null && echo "mvn package -Pit succeeded!" || fail "mvn package -Pit failed!"

  mvn -Dpnpm.enable=true && echo "mvn -Dpnpm.enable=true succeeded!" || fail "mvn -Dpnpm.enable=true failed!"

  mvn package -Pproduction -Dpnpm.enable=true && echo "mvn package -Pproduction -Dpnpm.enable=true succeeded!" || fail "mvn package -Pproduction -Dpnpm.enable=true failed!"

  skeleton_starter_flow_spring_result="Successful"

  echo -e "\n--------------------------------------------------\n| skeleton-starter-flow-spring build successful! |\n--------------------------------------------------\n"

  return
}


# this function runs all the starter tests
all(){

  setup1 base-starter-flow-osgi "$2" "$3"
  setup2 base-starter-flow-osgi "$2" "$3"
  setup_result="OK"
  base-starter-flow-osgi
  unset setup_result

  setup1 skeleton-starter-flow-cdi "$2" "$3"
  setup2 skeleton-starter-flow-cdi "$2" "$3"
  setup_result="OK"
  skeleton-starter-flow-cdi
  unset setup_result

  setup1 skeleton-starter-flow-spring "$2" "$3"
  setup2 skeleton-starter-flow-spring "$2" "$3"
  setup_result="OK"
  skeleton-starter-flow-spring
  unset setup_result

  setup1 base-starter-spring-gradle "$2" "$3"
  setup2 base-starter-spring-gradle "$2" "$3"
  setup_result="OK"
  base-starter-spring-gradle
  unset setup_result

  setup1 base-starter-flow-quarkus "$2" "$3"
  setup2 base-starter-flow-quarkus "$2" "$3"
  setup_result="OK"
  base-starter-flow-quarkus
  unset setup_result

  setup1 vaadin-flow-karaf-example "$2" "$3"
  setup2 vaadin-flow-karaf-example "$2" "$3"
  setup_result="OK"
  vaadin-flow-karaf-example
  unset setup_result

  echo -e "\n--------------------------\n| ALL BUILDS SUCCESSFUL! |\n--------------------------\n"


  exit 0

}


# main function
main(){


  [[ "$1" == "all" ]] && all "$@"

  setup1 "$@"
  setup2 "$@"


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

  exit 0

}


# call usage if not given three args
[[ "$#" != 3 ]] && usage


main "$@"
