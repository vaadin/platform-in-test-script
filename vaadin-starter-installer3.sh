#!/usr/bin/env bash
# This script installs any specified starter project automatically

source utils.sh
set -e

version="$2"
spring_message="No issues found."
VERBOSE="hwuia"
system="mac"
PORT=8080

# checks and deletes old directory
check_directory(){
	[[ -d "$1" ]] && rm -rf "$1"
}

# kill the server
kill_server(){
	port="$1"
	if [[ "$system" == "mac" ]]; then
		doKill $(lsof -t -i:$port)
  elif [[ "$system" == "linux" ]]; then
    doKill $(fuser $port/tcp)
  else
    doKill $(ps | grep 'java' | awk '{print $1}')
	fi
}

# check the answer of "Do you wish to visually inspect it?"
check_answer(){ 
	if [[ $returnCode -eq 0 ]]; then
				ask "The server executed successfully. Check the server visuall and press enter when ready."
				kill_server $pid_run $PORT
	fi
}


git_clone(){
	git clone https://github.com/vaadin/$1.git
	cd $1
}

mvn_clean_install(){

    mvn clean install

}

base_starter_flow_osgi(){

  mvn_clean_install

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version 

  mvn_clean_install
}

mvn_verify(){

  mvn verify -Pit,production 

}

skeleton_starter_flow_cdi(){

  mvn_verify

  mvn wildfly:run

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version 

  mvn_verify

}

gradlew_boot(){

  ./gradlew clean bootRun

}

base_starter_spring_gradle(){

  gradlew_boot

  perl -pi -e "s/vaadinVersion=.*/vaadinVersion=$version/" gradle.properties


  # Edit the string and replacement string if they change in the future
  buildGradleString='mavenCentral\(\)'
  buildGradleReplace="mavenCentral\(\)\n\tmaven { setUrl('https:\/\/maven.vaadin.com\/vaadin-prereleases') }"

  perl -pi -e "s/$buildGradleString/$buildGradleReplace/" build.gradle


  # Edit the string and replacement string if they change in the future
  settingGradleString='pluginManagement {'
  settingGradleReplace="pluginManagement {\n  repositories {\n\tmaven { url = 'https:\/\/maven.vaadin.com\/vaadin-prereleases' }\n\tgradlePluginPortal()\n}"

  perl -pi -e "s/$settingGradleString/$settingGradleReplace/" settings.gradle

  gradlew_boot

}

mvn_install(){

  mvn install

}


remove_node-modules(){

  rm -rf ./main-ui/nodeModules

}

vaadin_flow_karaf_example(){


  mvn_install

  mvn -pl main-ui install -Prun

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version

  mvn_install

  remove-node-modules && mvn install

  mvn -pl main-ui install -Prun

}


mvnw_package_production(){

  ./mvnw package -Pproduction

}

mvnw_package_it(){

  ./mvnw package -Pit

}


base_starter_flow_quarkus(){


  ./mvnw 

  mvnw_package_production

  mvnw_package_it

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version

  ./mvnw

  mvnw_package_production

  mvnw_package_it

}

mvn_package_production(){

  mvn package -Pproduction

}

mvn_package_it(){

  mvn package -Pit

}

skeleton_starter_flow_spring(){

  # Disable automatic browser startup in development mode
	# Doesn't work on Linux and Windows
  #turn_off_spring_browser

  #change_spring_port
	checkBusyPort 8080 || { echo "IN HERE" ; kill_server $PORT; }
	echo "VALUE IS ------ $? ---------"
  runInBackgroundToFile mvn "spring.output" "xas"
	waitUntilMessageInFile "spring.output" "$spring_message" 100
	returnCode=$?
	check_answer "$returnCode"

	echo "Great"

	exit 0

  mvn_package_production

  mvn_package_it

  mvn versions:set-property -Dproperty=vaadin.version -DnewVersion=$version

	checkBusyPort $PORT || kill_server $PORT
  runInBackgroundToFile mvn "spring.output" "xas"
	waitUntilMessageInFile "spring.output" "$spring_message" 100

 
  rm -rf node_modules

	checkBusyPort $PORT || kill_server $PORT
  runInBackgroundToFile mvn "spring.output" "xas"
	waitUntilMessageInFile "spring.output" "$spring_message" 100


  mvn_package_production

  mvn_package_it

}

func_name=${1//-/_}

check_directory "$1"
git_clone "$1"

"$func_name"
