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
  example: ./vaadin-starter-installer.sh skeleton_starter_flow_spring 23.0.1 v23" >&2
  exit 1
}


# checks what OS the user is using. $system variable will contain the name of the operating system
check_os(){

  os=$(uname)

  case "$os" in
   Darwin*)system="mac";;
   MINGW*)system="windows";;
   Linux*)system="linux";;
  esac

}


# check_directory checks if you already have a previous project directory and optionally removes it
check_directory(){

  if [[ -d "$1" ]]; then
      rm -rf "$1" || fail "ERROR: Failed to remove $1!"
      return
  fi
}


# clone_repo clones a git repo and changes the branch
clone_repo(){

  # this is used in all the starter projects
  version=$2

  git clone --quiet https://github.com/vaadin/$1.git || echo "\nERROR: Failed to git clone: vaadin/$1.git Are you sure that "\"$1\"" is the correct project?\n" 2>/dev/null


}


# kill the server
kill-server(){
    if [[ "$system" == "mac" ]]; then
      kill -2 $(lsof -t -i:$1)
    elif [[ "$system" == "linux" ]]; then
      fuser -k $1/tcp
    fi
}


# check and prompt the user for visual inspection
check_server_return(){

  sleep "$2"

  grep -q 'HTTP/1.1 200' <(curl --fail -I localhost:$1)
  exit_status=$?

  if [[ "$exitStatus" -eq 0 ]]; then 
    #play_bell &
    #bell_pid=$!
	  
    #read -p "The server exited with an HTTP exit code of 200. Do you still want to visually inspect it? y/n" answer2
		#echo "ANSWER2 IS : ${answer}\n"
    #kill $bell_pid &>/dev/null
    #if [[ "$answer2" == "y" || "$answer2" == "Y" ]]; then
    #  play_bell &
    #  bell_pid=$!
    #  read -p "Visual inspection of the server started. Press any key to continue the script." foo
    #  kill $bell_pid &>/dev/null
      kill-server "$1" 
      return
    #elif [[ "$answer2" == "n" || "$answer2" == "N" ]]; then
    #  kill-server "$1"
    #  return 
    #fi
  else
    fail "$3 ERROR: Server did not exit with an HTTP exit code of 200!"
  fi


}

# setup the directory
setup_directory(){

  cd "$1" || fail "ERROR: Failed to cd into $1"

  git checkout "$3" || fail "ERROR: Failed to change branch to $3"

}


# sounds the bell
play_bell(){
  while [[ 1 ]]; do
    echo -ne "\a"
    sleep 1
  done
}


# turn off automatic browser launch in development mode
turn_off_spring_browser(){
  sed -i '' -e 's/vaadin.launch-browser=true/vaadin.launch-browser=false/' ./src/main/resources/application.properties
}


# check_server tests for any running server on port 8080 and optionally kills it
check_server(){

  if [[ "$system" == "mac" ]]; then
    lsof -i:$1 >/dev/null
    exitValue=$?
  elif [[ "$system" == "linux" ]]; then
    fuser $1/tcp >/dev/null
    exitValue=$?
  fi

  if [[ $exitValue -eq 0 ]]; then
    play_bell &
    bell_pid=$!
    read -p "WARNING: You already have a server running on port $1. This will cause a conflict. Do you want to kill the running server? y/n " answer1
    kill $bell_pid &>/dev/null
  else
    # set setup_result to OK. This is needed when calling the show-result() function
    setup_result="OK"
    return
  fi

  if [[ "$answer1" == "y" ]] || [[ "$answer1" == "Y" ]]; then

    if [[ "$system" == "mac" ]]; then
      kill $(lsof -t -i:$1) &>/dev/null
			sleep 1
      lsof -i:$1 >/dev/null && kill -9 $(lsof -t -i:$1) &>/dev/null
      sleep 1
      lsof -i:$1 >/dev/null && fail "ERROR: Failed to kill the running server!"
    elif [[ "$system" == "linux" ]]; then
      fuser -k $1/tcp &>/dev/null
			sleep 1
      fuser $1/tcp && kill -9 $(fuser $1/tcp) &>/dev/null
			sleep 1
      fuser $1/tcp && fail "ERROR: Failed to kill the running server!"
    fi
  elif [[ "$answer1" == "n" ]] || [[ "$answer1" == "N" ]]; then
    fail "ERROR: Stop the running server before you start the script!"
  else
    echo "Please enter a valid answer(y/n)!" >&2
    check_server
  fi

  # set setup_result to OK. This is needed when calling the show-result() function
  setup_result="OK"

}


# if an error occurs, call this function
fail(){

  kill "$3" &>/dev/null

  echo -e "$2 - $1" >&2

  # tests what function failed and sets its status to failed
  case "$2" in
    base_starter_flow_osgi)
    base_starter_flow_osgi_result="Failed";
    ;;
    skeleton_starter_flow_cdi)
    skeleton_starter_flow_cdi_result="Failed";
    ;;
    skeleton_starter_flow_spring)
    skeleton_starter_flow_spring_result="Failed";
    ;;
    base_starter_spring_gradle)
    base_starter_spring_gradle_result="Failed";
    ;;
    base_starter_flow_quarkus)
    base_starter_flow_quarkus_result="Failed";
    ;;
    vaadin_flow_karaf_example)
    vaadin_flow_karaf_example_result="Failed";
    ;;
  esac


  show_results

  exit 1
}


# this function shows the results of the installation of the project(s)
show_results(){

    # this function always gets called at the end when running through all tests or if any test failed
    if [[ "$setup_result" == "OK" ]]; then
      echo -e "\nResults:\n
      base_starter_flow_osgi: ${base_starter_flow_osgi_result}
      skeleton_starter_flow_cdi: ${skeleton_starter_flow_cdi_result}
      skeleton_starter_flow_spring: ${skeleton_starter_flow_spring_result}
      base_starter_spring_gradle: ${base_starter_spring_gradle_result}
      base_starter_flow_quarkus: ${base_starter_flow_quarkus_result}
      vaadin_flow_karaf_example: ${vaadin_flow_karaf_example_result}
      "
    fi

}


mvn_clean_install(){

    mvn clean install &> "$pwd/osgi.output" && echo "mvn clean install succeeded!" || fail "ERROR: mvn clean install failed! Output dumped to osgi.output" "$1"

}


base_starter_flow_osgi(){

  mvn_clean_install "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version &> "$pwd/osgi.output" \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "ERROR: mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed! Output dumped to osgi.output" "$FUNCNAME"

  mvn_clean_install "$FUNCNAME"

  base_starter_flow_osgi_result="Successful"

  echo -e "\n--------------------------------------------\n| base_starter_flow_osgi build successful! |\n--------------------------------------------\n"

	rm $pwd/osgi.output

  return

}

mvn_verify(){

  mvn verify -Pit,production > "$pwd/cdi.output" && echo "mvn verify -Pit,production succeeded!" || fail "ERROR: mvn verify -Pit,production failed! Output dumped to cdi.ouput" "$1"

}


# cdi server starts on port 8080
skeleton_starter_flow_cdi(){


  #check-wildfly-server

  mvn_verify "$FUNCNAME"

                              #20 for fast computers
  check_server_return "8080" "40" &
  timer_pid=$!

  mvn wildfly:run &> "$pwd/cdi.output" && echo "mvn wildfly:run succeeded!" || fail "ERROR: mvn wildfly:run failed! Output dumped to cdi.output" "$timer_pid"


  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version &> "$pwd/cdi.output"  \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "ERROR: mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed! Output dumped to cdi.output" "$FUNCNAME"

  mvn_verify "$FUNCNAME"

  skeleton_starter_flow_cdi_result="Successful"

  echo -e "\n-----------------------------------------------\n| skeleton_starter_flow_cdi build successful! |\n-----------------------------------------------\n"

  rm $pwd/cdi.output

  return
}


gradlew_boot(){

   # There seems to be no way of stopping the gradlew server gracefully, so we can't test for errors here(since Ctrl-C will trigger an error)
  ./gradlew clean bootRun &> "$pwd/gradle.output" && echo "./gradlew clean bootRun succeeded! Output dumped to gradle.output" || kill "$2" &>/dev/null

}


base_starter_spring_gradle(){

  echo -e "\nNOTE: You are going to see an error after closing the gradle server! This is perfectly normal\n"

                              #35 for fast computers
  check_server_return "8080" "50" &
  timer_pid=$!

  gradlew_boot "$FUNCNAME" "$timer_pid"

  perl -pi -e "s/vaadinVersion=.*/vaadinVersion=$version/" gradle.properties &> "$pwd/gradle.output" || fail "ERROR: Could not edit gradle.properties! Output dumped to gradle.output" "$FUNCNAME" "$timer_pid"


  # Edit the string and replacement string if they change in the future
  build_gradle_string='mavenCentral\(\)'
  build_gradle_replace="mavenCentral\(\)\n\tmaven { setUrl('https:\/\/maven.vaadin.com\/vaadin-prereleases') }"

  perl -pi -e "s/$build_gradle_string/$build_gradle_replace/" build.gradle &> "$pwd/gradle.output" || fail "ERROR: Could not edit build.gradle! Output dumped to gradle.output" "$FUNCNAME"


  # Edit the string and replacement string if they change in the future
  setting_gradle_string='pluginManagement {'
  setting_gradle_replace="pluginManagement {\n  repositories {\n\tmaven { url = 'https:\/\/maven.vaadin.com\/vaadin-prereleases' }\n\tgradlePluginPortal()\n}"

  perl -pi -e "s/$setting_gradle_string/$setting_gradle_replace/" settings.gradle &> "$pwd/gradle.output" || fail "ERROR: Could not edit settings.gradle! Output dumped to gradle.output" "$FUNCNAME"

                              #35 for fast computers
  check_server_return "8080" "50" &
  timer_pid=$!

  gradlew_boot "$FUNCNAME" "$timer_pid"

  base_starter_spring_gradle_result="Successful"

  echo -e "\n------------------------------------------------\n| base_starter_spring_gradle build successful! |\n------------------------------------------------\n"

  rm $pwd/gradle.output

}


mvn_install(){

  mvn install &> "$pwd/karaf.output" && echo "mvn install succeeded!" || fail "ERROR: mvn install failed! Output dumped to karaf.output" "$1"

}


remove_node_modules(){

  rm -rf ./main-ui/node_modules  &> "$pwd/karaf.output" && return 0 || return 1

}

vaadin_flow_karaf_example(){


  mvn_install "$FUNCNAME"

  mvn -pl main-ui install -Prun &> "$pwd/karaf.output" && echo "mvn -pl main-ui install -Prun succeeded!" || fail "ERROR: mvn -pl main-ui install -Prun failed! Output dumped to karaf.output" "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version &> "$pwd/karaf.output" \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "ERROR: mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed! Output dumped to karaf.output" "$FUNCNAME"

  mvn_install "$FUNCNAME"

  remove_node_modules && mvn install &> "$pwd/karaf.output" && echo "remove_node_modules && mvn install succeeded!" || fail "ERROR: rm -rf ./main-ui/node_modules && mvn install failed! Output dumped to karaf.output" "$FUNCNAME"

  mvn -pl main-ui install -Prun &> "$pwd/karaf.output" && echo "mvn -pl main-ui install -Prun succeeded!" || fail "ERROR: mvn -pl main-ui install -Prun failed! Output dumped to karaf.output" "$FUNCNAME"


  vaadin_flow_karaf_example_result="Successful"

  echo -e "\n-----------------------------------------------\n| vaadin_flow_karaf_example build successful! |\n-----------------------------------------------\n"

	rm $pwd/karaf.output

}


mvnw_package_production(){

  ./mvnw package -Pproduction &> "$pwd/quarkus.output" && echo "mvnw package -Pproduction succeeded!" || fail "ERROR: mvnw package -Pproduction failed! Output dumped to quarkus.output" "$1"

}

mvnw_package_it(){

  ./mvnw package -Pit &> "$pwd/quarkus.output" && echo "mvnw package -Pit succeeded!" || fail "ERROR: mvnw package -Pit failed! Output dumped to quarkus.output" "$1"

}


base_starter_flow_quarkus(){

                              #40 for fast computers
  check_server_return "8080" "60" &
  timer_pid=$!

  ./mvnw &> "$pwd/quarkus.output" && echo "./mvnw succeeded!" || fail "ERROR: ./mvnw failed! Output dumped to quarkus.output" "$FUNCNAME" "$timer_pid"

  mvnw_package_production "$FUNCNAME"

  mvnw_package_it "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version &> "$pwd/quarkus.output" \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "ERROR: mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed! Output dumped to quarkus.output" "$FUNCNAME"

                              #40 for fast computers
  check_server_return "8080" "60" &
  timer_pid=$!

  ./mvnw &> "$pwd/quarkus.output" && echo "mvnw succeeded!" || fail "ERROR: mvnw failed! Output dumped to quarkus.output" "$FUNCNAME" "$timer_pid"

  mvnw_package_production "$FUNCNAME"

  mvnw_package_it "$FUNCNAME"

  base_starter_flow_quarkus_result="Successful"

  echo -e "\n-----------------------------------------------\n| base_starter_flow_quarkus build successful! |\n-----------------------------------------------\n"

  rm $pwd/quarkus.output 

}

mvn_package_production(){

  mvn package -Pproduction &> "$pwd/spring.output" && echo "mvn package -Pproduction succeeded!" || fail "ERROR: mvn package -Pproduction failed! Output dumped to spring.output" "$1"

}

mvn_package_it(){

  mvn package -Pit &> "$pwd/spring.output" && echo "mvn package -Pit succeeded!" || fail "ERROR: mvn package -Pit failed! Output dumped to spring.output" "$1"

}


skeleton_starter_flow_spring(){

  # Disable automatic browser statrtup in development mode
  turn_off_spring_browser

  #change_spring_port

                              #40 for fast computers
  check_server_return "8080" "60" &
  timer_pid=$!

  mvn spring-boot:run &> "$pwd/spring.output" || fail "mvn spring-boot:run. Output dumped to spring.output" "$FUNCNAME" "$timer_pid"

  mvn_package_production "$FUNCNAME"

  mvn_package_it "$FUNCNAME"

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version &> "$pwd/spring.output" \
  && echo "mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version succeeded!" \
  || fail "ERROR: mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version failed! Output dumped to spring.output" "$FUNCNAME"

                              #140 for fast computers
  check_server_return "8080" "260" &
  timer_pid=$!

  mvn -Dserver.port=8080 >/dev/null || fail "mvn failed!" "$FUNCNAME" "$timer_pid"

  rm -rf node_modules >/dev/null || fail "ERROR: rm -rf node_modules failed!" "$FUNCNAME"

                             #60 for fast computers
  check_server_return "8080" "100" &
  timer_pid=$!

  mvn -Dserver.port=8080 >/dev/null || fail "ERROR: mvn failed!" "$FUNCNAME" "$timer_pid"

  mvn_package_production "$FUNCNAME"

  mvn_package_it "$FUNCNAME"

  skeleton_starter_flow_spring_result="Successful"

  echo -e "\n--------------------------------------------------\n| skeleton_starter_flow_spring build successful! |\n--------------------------------------------------\n"
}


# this function runs all the starter tests
all(){

	check_os

  check_server "8080"

  check_directory base-starter-flow-osgi "$2" "$3"
  clone_repo base-starter-flow-osgi "$2" "$3"

  check_directory skeleton-starter-flow-cdi "$2" "$3"
  clone_repo skeleton-starter-flow-cdi "$2" "$3"

  check_directory skeleton-starter-flow-spring "$2" "$3"
  clone_repo skeleton-starter-flow-spring "$2" "$3"

  check_directory base-starter-spring-gradle "$2" "$3"
  clone_repo base-starter-spring-gradle "$2" "$3"

  check_directory base-starter-flow-quarkus "$2" "$3"
  clone_repo base-starter-flow-quarkus "$2" "$3"

  check_directory vaadin-flow-karaf-example "$2" "$3"
  clone_repo vaadin-flow-karaf-example "$2" "$3"


  setup_directory base-starter-flow-osgi "$2" "$3"
  base_starter_flow_osgi
	cd ..

  setup_directory skeleton-starter-flow-cdi "$2" "$3"
  skeleton_starter_flow_cdi
  cd ..

  setup_directory skeleton-starter-flow-spring "$2" "$3"
  skeleton_starter_flow_spring
  cd ..

  setup_directory base-starter-spring-gradle "$2" "$3"
  base_starter_spring_gradle
  cd ..

  setup_directory base-starter-flow-quarkus "$2" "$3"
  base_starter_flow_quarkus
  cd ..

  setup_directory vaadin-flow-karaf-example "$2" "$3"
  vaadin_flow_karaf_example


  show_results

  exit 0
}

# main function
main(){ 

	pwd=$PWD

  [[ "$1" == "all" ]] && all "$@"

  # run all the setups
  check_directory "$@"
  clone_repo "$@"
  check_server "8080"
  check_server "8081"
  check_server "8082"
  setup_directory "$@"

  func_name=${1//-/_}

  "$func_name"

  exit 0

}

# call usage if not given three args
[[ "$#" != 3 ]] && usage

main "$@"
