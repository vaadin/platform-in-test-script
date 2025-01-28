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
## K8s cluster and namespace
CC_CLUSTER=cc-cluster
CC_NS=control-center

## UI tests to run after the control-center is installed
CC_TESTS="cc-setup.js cc-install-apps.js cc-identity-management.js"

checkDockerRunning() {
  if ! docker ps > /dev/null 2>&1; then
    err "!! Docker is not running. Please start Docker and try again. !!"
    return 1
  fi
}

## Install Control Center with Helm
installCC() {
  [ -n "$VERBOSE" ] && D=--debug || D=""
  [ -n "$CC_KEY" -a -n "$CC_CERT" ] && args="--set app.tlsSecret=$CC_TLS_A --set keycloak.tlsSecret=$CC_TLS_K" || args=""
  runCmd "$TEST" "Installing Vaadin Control Center" \
   "time helm install control-center oci://docker.io/vaadin/control-center \
    -n $CC_NS --create-namespace --set livenessProbe.failureThreshold=20 \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL --set keycloak.host=$CC_AUTH $D $args"
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
  runCmd "$TEST" "Removing namespace $CC_NS" kubectl delete ns $CC_NS $KD
}

checkTls() {
  [ -n "$TEST" ] && return 0
  for i in `kubectl get ingresses -n $CC_NS | grep nginx | awk '{print $1}'`; do
    log "$i"
    H=`kubectl get ingress $i -n $CC_NS -o jsonpath='{.spec.rules[0].host}'`
    HS=`kubectl get ingress $i -n $CC_NS -o jsonpath='{.spec.tls[*].hosts[*]}'`
    S=`kubectl get ingress $i -n $CC_NS -o jsonpath='{.spec.tls[*].secretName}'`
    C=`kubectl get secret $S -n $CC_NS -o go-template='{{ index .data "tls.crt" | base64decode }}' | openssl x509 -noout -issuer -subject -enddate | tr '\n' ' '`
    log "Host: $H is in ingress $i with TLS config\n   hosts: $HS secret: $S cert: $C"
  done
}

## Configure secrets for the control-center and the keycloak servers
installTls() {
  [ -z "$CC_KEY" -o -z "$CC_CERT" ] && log "No CC_KEY and CC_CERT provided, skiping TLS installation" && return 0
  [ -n "$CC_FULL" ] && CC_CERT=$CC_FULL
  [ -z "$TEST" ] && log "Installing TLS $CC_TLS for $CC_CONTROL and $CC_AUT" || cmd "## Creating TLS file '$CC_DOMAIN.pem' from envs"
  f1=cc-tls.crt
  f2=cc-tls.key
  echo -e "$CC_CERT" > $f1 || return 1
  echo -e "$CC_KEY" > $f2 || return 1
  cat $f1 $f2 > $CC_DOMAIN.pem

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

  pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'` || return 1
  [ -n "$pod" ] && runCmd "$TEST" "Reloading nginx in $pod" "kubectl exec $pod -n "$CC_NS" -- nginx -s reload" || return 1
  runCmd "$TEST" "Waiting for reloading ingress" sleep 5
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
  [ -n "$SKIPPW" ] && return 0
  [ -z "$CC_CERT" -o -z "$CC_KEY" ] && NO_TLS=--notls || NO_TLS=""
  for f in $CC_TESTS; do
    runPlaywrightTests "$PIT_SCR_FOLDER/its/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --login=$CC_EMAIL $NO_TLS || return 1
    sleep 3
  done
}

## Main method for running control center
runControlCenter() {
  checkCommands kind helm docker kubectl || return 1
  checkBusyPort "443" || return 1
  checkDockerRunning || return 1
  ## Clean up from a previous run
  # stopCloudProvider
  uninstallCC $CC_CLUSTER $CC_NS
  # deleteCluster $CC_CLUSTER
  ## Start a new cluster
  createCluster $CC_CLUSTER $CC_NS || return 1
  # startCloudProvider || return 1
  ## Install Control Center
  installCC || return 1
  ## Control center takes a long time to start
  waitForCC 900 || return 1
  ## Show temporary user-email and password in the terminal
  showTemporaryPassword
  ## Install TLS certificates for the control-center and keycloak
  installTls && checkTls || return 1
  ## Forward the ingress (it needs root access since it uses port 443)
  forwardIngress $CC_NS || return 1
  ## Run Playwright tests
  runPwTests || return 1
  if [ -z "$TEST" -a -z "$KEEPCC" ]; then
    stopForwardIngress || return 1
    deleteCluster $CC_CLUSTER || return 1
  fi
}








