. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh
. `dirname $0`/lib/lib-k8s-kind.sh

## Domain and Host Configuration
CC_DOMAIN=local.alcala.org
CC_CONTROL=control.$CC_DOMAIN
CC_AUTH=auth.$CC_DOMAIN
CC_EMAIL=admin@$CC_DOMAIN
## Secret cert names
# Original are: control-center-cert and control-center-keycloak-cert
CC_TLS_A=cc-control-app-tls
CC_TLS_K=cc-control-login-tls
## Ingress names
CC_ING_A=control-center
CC_ING_K=control-center-keycloak-ingress
# Namespace used for CC
CC_NS=control-center

## UI tests to run after the control-center is installed
CC_TESTS=${CC_TESTS:-cc-setup.js cc-install-apps.js cc-identity-management.js cc-localization.js}

checkDockerRunning() {
  if ! docker ps > /dev/null 2>&1; then
    err "!! Docker is not running. Please start Docker and try again. !!"
    return 1
  fi
}

## Install Control Center with Helm
installCC() {
  [ -n "SKIPHELM" ] && H=`kubectl get pods 2>&1` && echo "$H" | egrep -q 'control-center-[0-9abcdef]+-..... ' && return 0
  [ -n "$VERBOSE" ] && D=--debug || D=""
  [ -n "$CC_KEY" -a -n "$CC_CERT" ] && args="--set app.tlsSecret=$CC_TLS_A --set keycloak.tlsSecret=$CC_TLS_K" || args=""
  [ "$1" = "next" ] && args="$args charts/control-center --set app.image.tag=local" || args="$args oci://docker.io/vaadin/control-center"

  runCmd "$TEST" "Installing Vaadin Control Center" \
   "time helm install control-center $args \
    -n $CC_NS --create-namespace --set livenessProbe.failureThreshold=20 \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL --set keycloak.host=$CC_AUTH $D" || return 1
}

## a loop for waiting to the control-center to be ready
# NOTE: --wait is not working properly since there are pods restarting because of performance issues
# $1: timeout in seconds (default 900)
waitForCC() {
  [ -n "$TEST" ] && return 0
  log "Waiting for Control Center to be ready"
  last=""
  while true; do
      elapsed=`expr ${elapsed:-0} + 1`
      [ "$elapsed" -ge "${1:-900}" ] && log "Timeout ${1:-900} sec. exceeded." && return 1
      H=`kubectl get pods -n $CC_NS | egrep 'control-center-[0-9abcdef]+-..... ' | awk '{print $2" "$3" "$4}'`
      case "$H" in
        "")
          log "Control center not installed in k8s" && return 1 ;;
        1/1*Running*)
          echo "" && log "Done ($elapsed secs.) - Status: $H"
          return 0 ;;
        *)
          [ "$H" != "$last" ] && ([ -n "$last" ] && echo "" || true) && log "Control center initializing - Status: $H" || printf .
          last="$H"
          sleep 1
          ;;
      esac
  done
}

## Uninstall control-center
uninstallCC() {
  H=`kubectl get ns 2>&1`
  [ $? = 0 ] && echo "$H" | egrep -q "^$CC_NS " || return 0
  [ -n "$VERBOSE" ] && HD=--debug && KD=--v=10
  runCmd "$TEST" "Uninstalling Control-Center" helm uninstall control-center --wait -n $CC_NS $HD
  runCmd "$TEST" "Removing namespace $CC_NS" kubectl delete ns $CC_NS $KD $1
}

getTLs() {
  log "TLS config for ingress: $1"
  H=`kubectl get ingress $1 -n $CC_NS -o jsonpath='{.spec.rules[0].host}'`
  HS=`kubectl get ingress $1 -n $CC_NS -o jsonpath='{.spec.tls[*].hosts[*]}'`
  S=`kubectl get ingress $1 -n $CC_NS -o jsonpath='{.spec.tls[*].secretName}'`
  C=`kubectl get secret $S -n $CC_NS -o go-template='{{ index .data "tls.crt" | base64decode }}' | openssl x509 -noout -issuer -subject -enddate | tr '\n' ' '`
  log "Host: $H is in ingress $1 with TLS config\n   hosts: $HS secret: $S cert: $C"
}

checkTls() {
  [ -n "$TEST" ] && return 0
  log "Checking TLS certificates for all ingresses hosted in the cluster"
  [ -n "$TEST" -o -n "$SKIPHELM" ] && return 0
  for i in `kubectl get ingresses -n $CC_NS | grep nginx | awk '{print $1}'`; do
    getTLs "$i"
  done
}

reloadIngress() {
  [ -n "$TEST" ] && return 0
  pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'` || return 1
  [ -n "$pod" ] && runCmd "$TEST" "Reloading nginx in $pod" "kubectl exec $pod -n "$CC_NS" -- nginx -s reload" || return 1
  [ -z "$TEST" ] && sleep 3
}

## Configure secrets for the control-center and the keycloak servers
installTls() {
  [ -n "$SKIPHELM" ] && return 0
  [ -z "$CC_KEY" -o -z "$CC_CERT" ] && log "No CC_KEY and CC_CERT provided, skiping TLS installation" && return 0
  # [ -n "$CC_FULL" ] && CC_CERT="$CC_FULL"
  [ -z "$TEST" ] && log "Installing TLS $CC_TLS for $CC_CONTROL and $CC_AUTH" || cmd "## Creating TLS file '$CC_DOMAIN.pem' from envs"
  f1=cc-tls.crt
  f2=cc-tls.key
  f3=$CC_DOMAIN.pem
  echo -e "$CC_CERT" > $f1 || return 1
  echo -e "$CC_KEY" > $f2 || return 1
  cat $f1 $f2 > $f3

  # remove old secrets if they exist (only needed for testing purposes since secrets are deleted before running the helm chart)
  kubectl get secret $CC_TLS_A -n $CC_NS >/dev/null 2>&1 && kubectl delete secret $CC_TLS_A -n $CC_NS
  kubectl get secret $CC_TLS_K -n $CC_NS >/dev/null 2>&1 && kubectl delete secret $CC_TLS_K -n $CC_NS

  # generate new secrets
  runCmd "$TEST" "Creating TLS secret $CC_TLS_A in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_A --key '$f2' --cert '$f1'" || return 1
  runCmd "$TEST" "Creating TLS secret $CC_TLS_K in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_K --key '$f2' --cert '$f1'" || return 1
  # not needed anymore
  rm -f $f1 $f2

  # patch the ingress with the new secrets (only needed for testing purposes since secrets are set with the helm chart args)
  runCmd "$TEST" "patching $CC_TLS_A" kubectl patch ingress $CC_ING_A -n $CC_NS --type=merge --patch \
    "'"'{"spec": {"tls": [{"hosts": ["'$CC_CONTROL'"],"secretName": "'$CC_TLS_A'"}]}}'"'"
  runCmd "$TEST" "patching $CC_TLS_K" kubectl patch ingress $CC_ING_K -n $CC_NS --type=merge --patch \
    "'"'{"spec": {"tls": [{"hosts": ["'$CC_AUTH'"],"secretName": "'$CC_TLS_K'"}]}}'"'"

  [ -n "$TEST" ] && return 0

  reloadIngress || return 1
}

## Show temporary user-email and password in the terminal
showTemporaryPassword() {
  email=`runCmd "$TEST" "Getting temporary admin email for Control Center" \
    "kubectl -n $CC_NS get secret control-center-user -o go-template=\"{{ .data.email | base64decode | println }}\""`
  passw=`runCmd "$TEST" "Getting temporary admin password for Control Center" \
    "kubectl -n $CC_NS get secret control-center-user -o go-template=\"{{ .data.password | base64decode | println }}\""`
  [ -n "$email" -a -n "$passw" ] && warn "Temporary credentials for Control Center: $email / $passw"
}

## Run Playwright tests for the control-center
runPwTests() {
  computeNpm
  [ -d screenshots.out ] && runCmd "$TEST" "Removing old screenshots" "rm -rf screenshots.out"
  [ -n "$SKIPPW" ] && return 0
  [ -z "$CC_CERT" -o -z "$CC_KEY" ] && NO_TLS=--notls || NO_TLS=""
  for f in $CC_TESTS; do
    runPlaywrightTests "$PIT_SCR_FOLDER/its/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --login=$CC_EMAIL $NO_TLS || return 1
    if [ "$f" = cc-install-apps.js ]; then
      reloadIngress && checkTls || return 1
    fi
  done
}

setClusterContext() {
  [ "$1" = "$KIND_CLUSTER" ] && current=kind-$1 || current=$1
  ns=$2
  H=`kubectl config get-contexts  | tr '*' ' ' | awk '{print $1}' | egrep "^$current$"`
  [ -z "$H" ] && log "Cluster $current not found in kubectl contexts" && return 1
  runCmd "$TEST" "Setting context to $current" "kubectl config use-context $current" || return 1
  H=`kubectl config current-context`
  [ "$H" != "$current" ] && log "Current context is not $current" && return 1
  runCmd "$TEST" "Setting default namespace to $ns" "kubectl config set-context --current --namespace=$ns" || return 1
  kubectl get ns >/dev/null 2>&1 || return 1
}

buildCC() {
  computeMvn
  [ -z "$VERBOSE" ] && D=-q || D=""
  runCmd "$TEST" "Compiling CC" "'$MVN' $D -ntp -B -pl :control-center-app -Pproduction -DskipTests -am install" || return 1
  runCmd "$TEST" "Creating CC application docker image" "'$MVN' $D -ntp -B -pl :control-center-app -Pproduction -Ddocker.tag=local docker:build" || return 1
  runCmd "$TEST" "Creating CC keycloack docker image" "'$MVN' $D -ntp -B -pl :control-center-keycloak package -Ddocker.tag=local docker:build" || return 1
  if [ "$CLUSTER" = "$KIND_CLUSTER" ]; then
      runCmd "$TEST" "Load docker image control-center-app for Kind" kind load docker-image vaadin/control-center-app:local --name "$CLUSTER" || return 1
      runCmd "$TEST" "Load docker image control-center-keycloak for Kind " kind load docker-image vaadin/control-center-keycloak:local --name "$CLUSTER" || return 1
  fi
  runCmd "$TEST" "Update helm dependencies" helm dependency build charts/control-center
}

## Main method for running control center
runControlCenter() {
  [ -z "$TEST" ] && bold "----> Running builds and tests on app control-center version=$1"
  [ -n "$TEST" ] && cmd "### Run PiT for: app=contro-center version=$1"

  ## Clean up CC from a previous run unless SKIPHELM is set
  [ -z "$SKIPHELM" ] && uninstallCC

  ## Check if port 443 is busy
  [ -z "$TEST" ] && checkBusyPort "443" || return 1

  ## Install Control Center
  installCC $1 || return 1
  ## Control center takes a long time to start
  waitForCC 900 || return 1

  ## Show temporary user-email and password in the terminal
  showTemporaryPassword

  ## Install TLS certificates for the control-center and keycloak
  installTls && checkTls || return 1

  ## Forward the ingress (it needs root access since it uses port 443)
  # checkPort "443"
  [ "$CLUSTER" != "$KIND_CLUSTER" ] || forwardIngress $CC_NS || return 1

  ## Run Playwright tests for the control-center
  runPwTests || return 1
  stopForwardIngress || return 1

  ## Delete the KinD cluster if it was created in this test if --keep-cc is not set
  [ -n "$TEST" -o -n "$KEEPCC" -o "$CLUSTER" != "$KIND_CLUSTER" ] || deleteKindCluster "$CLUSTER" || return 1
  ## Otherwise, uninstall the control-center if --keep-cc is not set
  [ -n "$TEST" -o -n "$KEEPCC" -o "$CLUSTER"  = "$KIND_CLUSTER" ] || uninstallCC --wait=false || return 1

  [ -z "$TEST" ] && bold "----> The version $1 of 'control-center' app was successfully built and tested.\n"

  return 0
}

validateControlCenter() {
  checkCommands docker kubectl helm unzip || return 1
  checkDockerRunning || return 1

  ## Start a new kind cluster if needed
  CLUSTER=${CLUSTER:-$KIND_CLUSTER}
  [ "$CLUSTER" != "$KIND_CLUSTER" ] || createKindCluster $CLUSTER $CC_NS || return 1

  ## Set the context to the cluster
  setClusterContext "$CLUSTER" "$CC_NS" || return 1

  buildCC || return 1
  runControlCenter next
  # if [ -z "$NOCURRENT" ]; then
  #   runControlCenter current
  # fi
}







