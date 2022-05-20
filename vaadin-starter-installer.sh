#!/usr/bin/env bash
# This script installs any specified starter project automatically

source utils.sh

_port=8080
VERBOSE=''
TIMEOUT='150'

# exit with instructions if not given three args
usage(){
  echo -e "usage: ./vaadin-starter-installer.sh project version branch
  example: ./vaadin-starter-installer.sh skeleton_starter_flow_spring 23.0.1 v23" >&2
  exit 1
}


# clone_repo clones a git repo and changes the branch
clone_repo(){

  # this is used in all the starter projects
  version=$2

  git clone --quiet https://github.com/vaadin/$1.git || echo "\nERROR: Failed to git clone: vaadin/$1.git Are you sure that "\"$1\"" is the correct project?\n" 2>/dev/null


}

# setup the directory
setup_directory(){

  cd "$1" || fail "ERROR: Failed to cd into $1"

  git checkout "$3" || fail "ERROR: Failed to change branch to $3"

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

	print_success "$FUNCNAME"

	rm $pwd/osgi.output

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

  #echo -e "\n-----------------------------------------------\n| skeleton_starter_flow_cdi build successful! |\n-----------------------------------------------\n"
	
	print_success "$FUNCNAME"

  rm $pwd/cdi.output

}


gradlew_boot(){

   # There seems to be no way of stopping the gradlew server gracefully, so we can't test for errors here(since Ctrl-C will trigger an error)
  ./gradlew clean bootRun &> "$pwd/gradle.output" && echo "./gradlew clean bootRun succeeded! Output dumped to gradle.output" || kill "$2" &>/dev/null

}


base_starter_spring_gradle(){

  echo -e "\nNOTE: You are going to see an error after closing the gradle server! This is perfectly normal.\n"

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

	print_success "$FUNCNAME"

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

	print_success "$FUNCNAME"

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

	print_success "$FUNCNAME"

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
	# Doesn't work on Linux and Windows
  #turn_off_spring_browser

  #change_spring_port

                              #40 for fast computers
  #check_server_return "8080" "60" &
	
  #timer_pid=$!

	log "Running mvn"
  runInBackgroundToFile mvn "spring.output" "$VERBOSE"
	waitUntilMessageInFile "spring.output" "No issues found." "$TIMEOUT"
	checkHttpServlet "https://localhost:8080"
	waitForUserWithBell
	ask "Server exited successfuly. Do you wish to visually inspect it?(y/n)"
	[[ "$key" == 'y' ]] && waitForUserWithBell "Inspect the server and then press enter"
	
	echo "\nHurray! It worked!!!!!!!!!!!!!\n"

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
	checkBusyPort 8080

  setup_directory "$@"

  func_name=${1//-/_}

  "$func_name"

  exit 0

}

# call usage if not given three args
[[ "$#" != 3 ]] && usage

main "$@"
