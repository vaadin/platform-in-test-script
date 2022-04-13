#!/usr/bin/env bash
# This script installs any specified starter project automatically



base_starter_flow_osgi_result="Not Tested"
skeleton_starter_flow_cdi_result="Not Tested"
skeleton_starter_flow_spring_result="Not Tested"
base_starter_spring_gradle_result="Not Tested"
base_starter_flow_quarkus_result="Not Tested"
vaadin_flow_karaf_example_result="Not Tested"

setup_result=""


# exit with instructions if not given three args
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
      return

    elif [[ "$remove" == "n" ]] || [[ "$remove" == "N" ]]; then
      fail "Error! Remove or rename the old directory before trying again."

    else
      echo "Error! Please enter a valid answer(y/n)!" >&2
      setup1
    fi
  fi
}


# setup2 clones a git repo and changes the branch
setup2(){

  version="$2"

  git clone https://github.com/vaadin/$1.git && cd "$1"

  git checkout "$3" || fail "Failed to change branch to $3"

}


# setup3 tests for any running web servers on port 8080 and optionally kills it
setup3(){

  lsof -i:8080 >/dev/null && read -p "You already have a web server running on port 8080. This will cause a conflict. Do you want to kill the running web server? y/n " answer1 || return

  if [[ "$answer1" == "y" ]] || [[ "$answer1" == "Y" ]]; then
    kill $(lsof -t -i:8080) || fail "Failed to kill the running web server!"

  elif [[ "$answer1" == "n" ]] || [[ "$answer1" == "N" ]]; then
    fail "Error! Stop the running web server before you start the script!"

  else
    echo "Error! Please enter a valid answer(y/n)!" >&2
    setup3
  fi

}


# if an error occurs, call this function
fail(){

  echo "$1" >&2


  case "$2" in
    base-starter-flow-osgi)
    base_starter_flow_osgi_result="Failed";
    ;;
    skeleton-starter-flow-cdi)
    skeleton_starter_flow_cdi_result="Failed";
    ;;
    skeleton-starter-flow-spring)
    skeleton_starter_flow_spring_result="Failed";
    ;;
    base-starter-spring-gradle)
    base_starter_spring_gradle_result="Failed";
    ;;
    base-starter-flow-quarkus)
    base_starter_flow_quarkus_result="Failed";
    ;;
    vaadin-flow-karaf-example)
    vaadin_flow_karaf_example_result="Failed";
    ;;
  esac


  if [[ "$setup_result" == "OK" ]]; then
    echo -e "\nResults:\n
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


mvn-clean-install(){

    mvn clean install >/dev/null && echo "mvn clean install succeeded!" || fail "mvn clean install failed!" "$1"

}


base-starter-flow-osgi(){

  mvn-clean-install "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!" "$FUNCNAME"

  mvn-clean-install "$FUNCNAME"

  mvn clean install -Dpnpm.enable=true >/dev/null && echo "mvn clean install with Dpnpm.enable=true succeeded!" \
  || fail "mvn clean install with Dpnpm.enable=true failed!" "$FUNCNAME"

  base_starter_flow_osgi_result="Successful"

  echo -e "\n--------------------------------------------\n| base-starter-flow-osgi build successful! |\n--------------------------------------------\n"

  return

}

mvn-verify(){

  mvn verify -Pit,production >/dev/null && echo "mvn verify -Pit,production succeeded!" || fail "mvn verify -Pit,production failed!" "$1"

}


check-wildfly-server(){

  pgrep -f "wildfly" >/dev/null && read -p "wildfly is already running! Do you want to kill it? y/n" answer2 || return

  if [[ "$answer2" == "y" ]] || [[ "$answer2" == "Y" ]]; then
    pgrep -f "wildfly" | xargs kill
  else
    echo "Shut down the server or kill it before running the script." >&2
    exit 1
  fi

}


skeleton-starter-flow-cdi(){


  check-wildfly-server

  mvn-verify "$FUNCNAME"

  # Press Ctrl-C to continue
  mvn wildfly:run


  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!" "$FUNCNAME"

  mvn-verify

  skeleton_starter_flow_cdi_result="Successful"

  echo -e "\n-----------------------------------------------\n| skeleton-starter-flow-cdi build successful! |\n-----------------------------------------------\n"


  return
}


gradlew-boot(){

  ./gradlew clean bootRun && echo "./gradlew clean bootRun succeeded!" || fail "./gradlew clean bootRun failed!" "$FUNCNAME"

}


base-starter-spring-gradle(){

  gradlew-boot

  perl -pi -e "s/vaadinVersion=.*/vaadinVersion=$version/" gradle.properties || fail "Could not edit gradle.properties!" "$FUNCNAME"

  #perl -pi -e "s/repositories {\n\tmavenCentral()\n/repositories {\n\tmavenCentral()\n\tmaven { setUrl('https:\/\/maven.vaadin.com\/vaadin-prereleases') }/" build.gradle


  # Edit the string and replacement string if they change in the future
  build_gradle_string='mavenCentral\(\)'
  build_gradle_replace="mavenCentral\(\)\n\tmaven { setUrl('https:\/\/maven.vaadin.com\/vaadin-prereleases') }"

  perl -pi -e "s/$build_gradle_string/$build_gradle_replace/" build.gradle || fail "Could not edit build.gradle!" "$FUNCNAME"


  # Edit the string and replacement string if they change in the future
  setting_gradle_string='pluginManagement {'
  setting_gradle_replace="pluginManagement {\n  repositories {\n\tmaven { url = 'https:\/\/maven.vaadin.com\/vaadin-prereleases' }\n\tgradlePluginPortal()\n}"

  perl -pi -e "s/$setting_gradle_string/$setting_gradle_replace/" settings.gradle || fail "Could not edit settings.gradle!" "$FUNCNAME"

  gradlew-boot

  base_starter_spring_gradle_result="Successful"

  echo -e "\n------------------------------------------------\n| base-starter-spring-gradle build successful! |\n------------------------------------------------\n"

  return

}


mvn-install(){

  mvn install && echo "mvn install succeeded!" || fail "mvn install failed!" "$1"

}


remove-node-modules(){

  rm -rf ./main-ui/node_modules && return 0 || return 1

}

vaadin-flow-karaf-example(){


  mvn-install "$FUNCNAME"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || fail "mvn -pl main-ui install -Prun failed!" "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!" "$FUNCNAME"

  mvn-install "$FUNCNAME"

  remove-node-modules && mvn install && echo "remove-node-modules && mvn install succeeded!" || fail "rm -rf ./main-ui/node_modules && mvn install failed!" "$FUNCNAME"

  mvn -pl main-ui install -Prun && echo "mvn -pl main-ui install -Prun succeeded!" || fail "mvn -pl main-ui install -Prun failed!" "$FUNCNAME"


  vaadin_flow_karaf_example_result="Successful"

  echo -e "\n-----------------------------------------------\n| vaadin-flow-karaf-example build successful! |\n-----------------------------------------------\n"

  return

}


mvnw-package-production(){

  ./mvnw package -Pproduction >/dev/null && echo "mvnw package -Pproduction succeeded!" || fail "mvnw package -Pproduction failed!" "$1"

}

mvnw-package-it(){

  ./mvnw package -Pit >/dev/null && echo "mvnw package -Pit succeeded!" || fail "mvnw package -Pit failed!" "$1"

}


base-starter-flow-quarkus(){

  ./mvnw && echo "./mvnw succeeded!" || fail "./mvnw failed!" "$FUNCNAME"

  mvnw-package-production "$FUNCNAME"

  mvnw-package-it "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!" "$FUNCNAME"

  ./mvnw && echo "mvnw succeeded!" || fail "mvnw failed!" "$FUNCNAME"

  mvnw-package-production "$FUNCNAME"

  mvnw-package-it "$FUNCNAME"

  #./mvnw package -Pit && echo "mvnw package -Pit succeeded!" || echo "mvnw package -Pit failed!"

  base_starter_flow_quarkus_result="Successful"

  echo -e "\n-----------------------------------------------\n| base-starter-flow-quarkus build successful! |\n-----------------------------------------------\n"

  return

}

mvn-package-production(){

  mvn package -Pproduction >/dev/null && echo "mvn package -Pproduction succeeded!" || fail "mvn package -Pproduction failed!" "$1"

}

mvn-package-it(){

  mvn package -Pit >/dev/null && echo "mvn package -Pit succeeded!" || fail "mvn package -Pit failed!" "$1"

}


skeleton-starter-flow-spring(){

  mvn || fail "mvn failed!" "$FUNCNAME"

  mvn-package-production "$FUNCNAME"

  mvn-package-it "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version >/dev/null \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed!" "$FUNCNAME"

  mvn || fail "mvn failed!" "$FUNCNAME"

  rm -rf node_modules && mvn || fail "rm -rf node_modules && mvn failed!" "$FUNCNAME"

  mvn-package-production "$FUNCNAME"

  mvn-package-it "$FUNCNAME"

  skeleton_starter_flow_spring_result="Successful"

  echo -e "\n--------------------------------------------------\n| skeleton-starter-flow-spring build successful! |\n--------------------------------------------------\n"

  return
}


# this function runs all the starter tests
all(){

  setup1 base-starter-flow-osgi "$2" "$3"
  setup2 base-starter-flow-osgi "$2" "$3"
  setup3 base-starter-flow-osgi "$2" "$3"
  setup_result="OK"
  base-starter-flow-osgi
  unset setup_result

  cd ..

  setup1 skeleton-starter-flow-cdi "$2" "$3"
  setup2 skeleton-starter-flow-cdi "$2" "$3"
  setup3 skeleton-starter-flow-cdi "$2" "$3"
  setup_result="OK"
  skeleton-starter-flow-cdi
  unset setup_result

  cd..

  setup1 skeleton-starter-flow-spring "$2" "$3"
  setup2 skeleton-starter-flow-spring "$2" "$3"
  setup3 skeleton-starter-flow-spring "$2" "$3"
  setup_result="OK"
  skeleton-starter-flow-spring
  unset setup_result

  cd ..

  setup1 base-starter-spring-gradle "$2" "$3"
  setup2 base-starter-spring-gradle "$2" "$3"
  setup3 base-starter-spring-gradle "$2" "$3"
  setup_result="OK"
  base-starter-spring-gradle
  unset setup_result

  cd ..

  setup1 base-starter-flow-quarkus "$2" "$3"
  setup2 base-starter-flow-quarkus "$2" "$3"
  setup3 base-starter-flow-quarkus "$2" "$3"
  setup_result="OK"
  base-starter-flow-quarkus
  unset setup_result

  cd ..

  setup1 vaadin-flow-karaf-example "$2" "$3"
  setup2 vaadin-flow-karaf-example "$2" "$3"
  setup3 vaadin-flow-karaf-example "$2" "$3"
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
  setup3 "$@"


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
