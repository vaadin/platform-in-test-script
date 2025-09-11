. `dirname $0`/lib/lib-utils.sh

### LIBRARY for parsing arguments when `run.sh` is executed

## the usage message, it should be synchronized with the function used for extracting the arguments below
usage() {
  cat <<EOF
Use: $0 with the next options:

 --version=string  Vaadin version to test, if not given it only tests current stable, otherwise it runs tests against current stable and then against given version.
 --demos           Run all demo projects
 --generated       Run all generated projects (start and archetypes)
 --port=number     HTTP port for thee servlet container (default: $DEFAULT_PORT)
 --timeout=number  Time in secs to wait for server to start (default $DEFAULT_TIMEOUT)
 --jdk=NN          Use a specific JDK version to run the tests
 --verbose         Show server output (default silent)
 --offline         Do not remove already downloaded projects, and do not use network for mvn (default online)
 --interactive     Play a bell and ask user to manually test the application (default non interactive)
 --skip-tests      Skip UI Tests (default run tests). Note: selenium-ide does not work in gitpod
 --skip-current    Skip running build in current version
 --skip-prod       Skip production validations
 --skip-dev        Skip dev-mode validations
 --skip-clean      Do not clean maven cache
 --skip-helm       Do not re-install control-center with helm and continue running tests, implies (--offline, --keep-cc)
 --skip-pw         Do not run playwright tests
 --cluster=name    Run tests in an existing k8s cluster
 --vendor=name     Use a specific cluster vendor to run control-center tests options: [dd, kind, do] (default: kind)
 --keep-cc         Keep control-center running after tests
 --keep-apps       Keep installed apps in control-center, implies --keep-cc
 --proxy-cc        Forward port 443 from k8s cluster to localhost
 --events-cc       Display events from control-center
 --cc-version      Install this version for current
 --skip-build      Skip building the docker images for control-center
 --delete-cluster  Delete the cluster/s
 --dashboard=*     Install kubernetes dashboard, options [install, uninstall] (default: install)
 --pnpm            Use pnpm instead of npm to speed up frontend compilation (default npm)
 --vite            Use vite inetad of webpack to speed up frontend compilation (default webpack)
 --list            Show the list of available starters
 --hub             Use selenium hub instead of local chrome, it assumes that selenium docker is running as service in localhost
 --commit          Commit changes to the base branch
 --test            Checkout starters, and show steps and commands to execute, but don't run them
 --headless        Run the browser in headless mode even if interactive mode is enabled
 --headed          Run the browser in headed mode even if interactive mode is disabled
 --function        run only one function of the libs in current folder.
                   everything after this argument is the function name and arguments passed to the function.
                   you should take care with arguments that contain spaces, they should be quoted twice.
 --help            Show this message
 --starters=list   List of demos or presets separated by comma to run (default: all) valid options:`echo ,$DEFAULT_STARTERS | tr ' ' , | sed -e 's/,/\n                   · /g'`
EOF
  exit 1
}

## check arguments passed to `run.sh` script and set global variables
checkArgs() {
  VERSION=current; export PORT=$DEFAULT_PORT; TIMEOUT=$DEFAULT_TIMEOUT; CLUSTER=pit; VENDOR=kind; CCVERSION=current
  while [ -n "$1" ]
  do
    arg=`echo "$1" | grep = | cut -d= -f2`
    case "$1" in
      --port=*) export PORT="$arg";;
      --generated) STARTERS=`echo "$PRESETS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`;;
      --demos) STARTERS=`echo "$DEMOS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`;;
      --start*=*)
        ## discover valid starters, when only providing the project name without repo, folder, or branch parts
        S=""
        for i in `echo "$arg" | tr ',' ' '`
        do
          b=${i%%:*}
          n=${b#\!}
          H=`printf "$PRESETS\n$DEMOS" | egrep "^$n$|/$n$|/$n[/:]|^$n[/:]" | head -1`
          [ -z "$H" ] && err "Unknown starter: $n" && exit 1
          [ "$n" = "$i" ] && S="$S,$H" || S="$i"
        done
        STARTERS="$S";;
      --version=*) VERSION="$arg";;
      --timeout=*) TIMEOUT="$arg";;
      --jdk=*) JDK="$arg";;
      --verbose|--debug) VERBOSE=true;;
      --offline) OFFLINE=true;;
      --interactive) INTERACTIVE=true;;
      --skip-tests) SKIPTESTS=true;;
      --skip-current) NOCURRENT=true;;
      --skip-dev) NODEV=true;;
      --skip-prod) NOPROD=true;;
      --skip-pw) SKIPPW=true;;
      --cluster=*) CLUSTER="$arg";;
      --vendor=*)
        VENDOR="$arg"
        [ "$VENDOR" = dd ] && CLUSTER="docker-desktop"
      ;;
      --cc-version*) CCVERSION="$arg";;
      --keep-cc) KEEPCC=true;;
      --keep-apps) KEEPAPPS=true;;
      --skip-build) SKIPBUILD=true;;
      --skip-helm)  OFFLINE=true; KEEPCC=true; SKIPHELM=true ;;
      --pnpm) PNPM="-Dpnpm.enable=true";;
      --vite) VITE=true;;
      --list*)
        for i in `echo "${STARTERS#,}" | tr "," " "`; do
          [ "${i#\!}" != "$i" ] && STARTERS="" && DEFAULT_STARTERS=`echo "$DEFAULT_STARTERS" | grep -v "${i#\!}"`
        done
        [ -z "$STARTERS" ] && STARTERS="${DEFAULT_STARTERS}" || STARTERS=`echo "$STARTERS" | tr "," "\n" | grep ...`
        [ -z "$arg" ] && arg=1
        echo "$STARTERS" | xargs -n $arg | tr ' ' ,
        exit 0
        ;;
      --help) usage && exit 0;;
      --update) UPDATE="true";;
      --hub) USEHUB="true";;
      --pre)
        PRESETS=`echo "$PRESETS" | sed -e 's,^latest-,pre-,g'`
        DEFAULT_STARTERS=`echo "$PRESETS" | tr "\n" "," | sed -e 's/^,//' | sed -e 's/,$//'`
        ;;
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
      --skip-clean)
        NO_CLEAN=true;;
      --function)
        shift
        RUN_FUCTION=${*}
        break ;;
      --proxy*)
        setClusterContext "$CLUSTER" "$CC_NS" "$VENDOR" || exit 1
        isCCInstalled || exit 1
        VERBOSE=true runCmd "Running CC proxy" kubectl port-forward service/control-center-ingress-nginx-controller 443:443 -n $CC_NS
        exit ;;
      --events*)
        VERBOSE=true runCmd "Showing CC events" kubectl get events --watch -n $CC_NS -o 'custom-columns="LAST SEEN:.lastTimestamp,TYPE:.type,REASON:.reason,NAME:.metadata.name,MESSAGE:.message"'
        exit ;;
      --dash*)
        if [ "$arg" = uninstall ]; then
          uninstallDashBoard
        else
          installDashBoard
          VERBOSE=true runCmd "Running CC proxy" kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
        fi
        exit ;;
      --delete-cluster) deleteCluster; exit ;;
      --headless) HEADLESS=true ;;
      --headed)   HEADLESS=false ;;
      --ghtk=*|--gh-token=*)   GHTK=$arg ;;
      *) echo "Unknown option: $1" && usage && exit 1;;
    esac
    shift
  done



}
