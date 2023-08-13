usage() {
  cat <<EOF
Use: $0 [version=] [starters=] [port=] [timeout=] [verbose] [offline] [interactive] [skiptests] [pnpm] [vite] [help]

 --version=string  Vaadin version to test, if not given it only tests current stable, otherwise it runs tests against current stable and then against given version.
 --starters=list   List of demos or presets separated by comma to run (default: all) valid options:`echo ,$DEFAULT_STARTERS | sed -e 's/,/\n                   · /g'`
 --demos           Run all demo projects
 --generated       Run all generated projects (start and archetypes)
 --port=number     HTTP port for thee servlet container (default: $DEFAULT_PORT)
 --timeout=number  Time in secs to wait for server to start (default $DEFAULT_TIMEOUT)
 --verbose         Show server output (default silent)
 --offline         Do not remove already downloaded projects, and do not use network for mvn (default online)
 --interactive     Play a bell and ask user to manually test the application (default non interactive)
 --skip-tests      Skip UI Tests (default run tests). Note: selenium-ide does not work in gitpod
 --skip-current    Skip running build in current version
 --skip-prod       Skip production validations
 --skip-dev        Skip dev-mode validations
 --pnpm            Use pnpm instead of npm to speed up frontend compilation (default npm)
 --vite            Use vite inetad of webpack to speed up frontend compilation (default webpack)
 --list            Show the list of available starters
 --hub             Use selenium hub instead of local chrome, it assumes that selenium docker is running as service in localhost
 --help            Show this message
 --commit          Commit changes to the base branch
 --test            Checkout starters, and show steps and commands to execute, but don't run them
EOF
  exit 1
}

checkArgs() {
  VERSION=current; PORT=$DEFAULT_PORT; TIMEOUT=$DEFAULT_TIMEOUT
  while [ -n "$1" ]
  do
    arg=`echo "$1" | cut -d= -f2`
    case "$1" in
      --port=*) PORT="$arg";;
      --generated) STARTERS=`echo "$PRESETS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`;;
      --demos) STARTERS=`echo "$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`;;
      --start*=*) STARTERS="$arg";;
      --version=*) VERSION="$arg";;
      --timeout=*) TIMEOUT="$arg";;
      --verbose|--debug) VERBOSE=true;;
      --offline) OFFLINE=true;;
      --interactive) INTERACTIVE=true;;
      --skip-tests) SKIPTESTS=true;;
      --skip-current) NOCURRENT=true;;
      --skip-dev) NODEV=true;;
      --skip-prod) NOPROD=true;;
      --pnpm) PNPM="-Dpnpm.enable=true";;
      --vite) VITE=true;;
      --list*)
        [ -z "$STARTERS" ] && STARTERS="$DEFAULT_STARTERS"
        L=`echo "$STARTERS" | tr "," "\n" | grep ...`
        [ -n "$arg" ] && echo "$L" | xargs -n $arg | tr ' ' , || echo "$L"
        exit 0
        ;;
      --help) usage && exit 0;;
      --update) UPDATE="true";;
      --hub) USEHUB="true";;
      --pre)
        PRESETS=`echo "$PRESETS" | sed -e 's,^latest-,pre-,g'`
        DEFAULT_STARTERS=`echo "$PRESETS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'` ;;
      --commit) COMMIT=true ;;
      --check)
        for i in `getReposFromWebsite` ;
        do
          echo "$DEMOS" | egrep -q "^$i$" && echo $i OK || echo $i NO
        done
        exit
        ;;
      --test)
        TEST=true ;;
      *) echo "Unknown option: $1" && usage && exit 1;;
    esac
    shift
  done

  ## discover valid starters, when only providing the project name without repo, folder, or branch parts
  S=""
  for i in `echo "$STARTERS" | tr ',' ' '`
  do
    H=`printf "$PRESETS\n$DEMOS" | egrep "^$i$|/$i$|/$i[/:]|^$i[/:]" | tr "\n" ","`
    [ -z "$H" ] && err "Unknown starter: $i" && exit 1
    [ -n "$S" ] && S="$S,$H" || S="$H"
  done
  STARTERS="$S"
}