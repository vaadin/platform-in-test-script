#!/bin/sh
. `dirname $0`/lib/lib-start.sh

trap "doExit" INT TERM EXIT

DEFAULT_PORT=8080
DEFAULT_PRESETS="latest-java,latest-java-top,latest-javahtml,latest-typescript,latest-typescript-top,latest-java_partial-auth,latest-typescript_partial-auth"
DEFAULT_TIMEOUT=220

usage() {
  cat <<EOF
Use: $0 [version=] [presets=] [port=] [timeout=] [verbose] [offline]"

  version      Vaadin version to test, by default current stable, otherwise it runs tests against current stable and then against provided version.
  presets      List of start presets separated by comman (default: $DEFAULT_PRESETS)
  port         HTTP Port for thee servlet container (default: $DEFAULT_PORT)
  timeout      Time in secs to wait for server to start (default $DEFAULT_TIMEOUT)
  verbose      Show server output (default silent)
  offline      Do not remove previous folders, and do not use network for mvn (default online)
  interactive  Play Bell and ask user to manually test the application
  skiptests    Skip Selenium Tests (They do not work in gitpod)
EOF
  exit 1
}

checkArgs() {
  VERSION=current; PORT=$DEFAULT_PORT; PRESETS=$DEFAULT_PRESETS; TIMEOUT=$DEFAULT_TIMEOUT
  while [ -n "$1" ]
  do
    arg=`echo "$1" | cut -d= -f2`
    case "$1" in
      port=*) PORT="$arg";;
      presets=*|starters=*) PRESETS="$arg";;
      version=*) VERSION="$arg";;
      timeout=*) TIMEOUT="$arg";;
      verbose|debug) VERBOSE=true;;
      offline) OFFLINE=true;;
      interactive) INTERACTIVE=true;;
      skiptests) SKIPTESTS=true;;
      *) echo "Unknown option: $1" && usage && exit 1;;
    esac
    shift
  done
}

### MAIN
main() {
  runStarters "$PRESETS" "$PORT" "$VERSION" "$OFFLINE"
}

checkArgs ${@}
main

