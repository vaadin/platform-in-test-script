usage() {
  cat <<EOF
Use: $0 [version=] [starters=] [port=] [timeout=] [verbose] [offline] [interactive] [skiptests] [help]

  version      Vaadin version to test, by default current stable, otherwise it runs tests against current stable and then against given version.
  starters     List of demos o presets separated by comma to run (default: all) valid options:
                 `echo $DEFAULT_STARTERS | sed -e 's/,/\n                 /g'`
  port         HTTP Port for thee servlet container (default: $DEFAULT_PORT)
  timeout      Time in secs to wait for server to start (default $DEFAULT_TIMEOUT)
  verbose      Show server output (default silent)
  offline      Do not remove previous folders, and do not use network for mvn (default online)
  interactive  Play Bell and ask user to manually test the application (default non interactive)
  skiptests    Skip Selenium IDE Tests (default run tests). Note: selenium-ide does not work in gitpod 
  help         Show this message
EOF
  exit 1
}

checkArgs() {
  VERSION=current; PORT=$DEFAULT_PORT; STARTERS=$DEFAULT_STARTERS; TIMEOUT=$DEFAULT_TIMEOUT
  while [ -n "$1" ]
  do
    arg=`echo "$1" | cut -d= -f2`
    case `echo $1 | sed -e 's/\-//g'` in
      port=*) PORT="$arg";;
      starters=*) STARTERS="$arg";;
      version=*) VERSION="$arg";;
      timeout=*) TIMEOUT="$arg";;
      verbose|debug) VERBOSE=true;;
      offline) OFFLINE=true;;
      interactive) INTERACTIVE=true;;
      skiptests) SKIPTESTS=true;;
      help|h) usage && exit 0;;
      *) echo "Unknown option: $1" && usage && exit 1;;
    esac
    shift
  done
}