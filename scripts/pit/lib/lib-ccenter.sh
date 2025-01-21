. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh
. `dirname $0`/lib/lib-k8s-kind.sh

## Configuration
CC_DOMAIN=alcala.org
CC_CONTROL=control-local.$CC_DOMAIN
CC_AUTH=auth-local.$CC_DOMAIN
CC_EMAIL=admin@$CC_DOMAIN
# Original cert secrets are: control-center-cert and control-center-keycloak-cert
CC_TLS_A=cc-control-app-tls
CC_TLS_K=cc-control-login-tls
CC_CLUSTER=cc-cluster
CC_NS=control-center
CC_TESTS="cc-setup.js cc-install-apps.js"

## Install Control Center with Helm
installCC() {
  [ -n "$VERBOSE" ] && D=--debug || D=""
  ## TODO: why this fails
  # [ -n "$CC_KEY" -a -n "$CC_CERT" ] && args="--set app.tlsSecret=$CC_TLS_A --set keycloak.tlsSecret=$CC_TLS_K" || args=""
  runCmd "$TEST" "Installing Vaadin Control Center" \
   "time helm install control-center oci://docker.io/vaadin/control-center \
    -n $CC_NS --create-namespace --set livenessProbe.failureThreshold=20 \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL --set keycloak.host=$CC_AUTH $D $args"
  ## TODO: dont wait most times it takes a long, therefore we use our own wait
  # --wait $D"
}

## a loop for waiting to the control-center to be ready
# $1: timeout in seconds (default 900)
waitForCC() {
  log "Waiting for Control Center to be ready"
  last=""
  while true; do
      elapsed=`expr ${elapsed:-0} + 1`
      [ "$elapsed" -ge "${1:-900}" ] && log "Timeout ${1:-900} sec. exceeded." && return 1
      H=`kubectl get pods -n $CC_NS | egrep 'control-center-[0-9abcdef]+-..... ' | awk '{print $3" "$4}'`
      case "$H" in
        "")
          log "Control center not installed in k8s" && return 1 ;;
        Running*)
          echo "" && log "Done ($elapsed secs.) - $H"
          return 0 ;;
        *)
          [ "$H" != "$last" ] && ([ -n "$last" ] && echo "" || true) && log "Control center initializing - $H" || printf .
          last="$H"
          sleep 1
          ;;
      esac
  done
}

## Uninstall control-center
uninstallCC() {
  H=`kubectl get ns`
  echo "$H" | egrep -q "^$CC_NS " || return 0
  [ -n "$VERBOSE" ] && D=--debug || D=""
  runCmd "$TEST" "Uninstalling Control-Center" helm uninstall control-center --wait -n $CC_NS $D
  runCmd "$TEST" "Removing namespace $CC_NS" kubectl delete ns $CC_NS --v=6
}

## Configure secrets for the control-center and the keycloak servers
installTls() {
  [ -z "$CC_KEY" -o -z "$CC_CERT" ] && log "No CC_KEY and CC_CERT provided, skiping TLS installation" && return 0
  [ -z "$TEST" ] && log "Installing TLS $CC_TLS for $CC_CONTROL and $CC_AUT" || cmd "## Creating TLS files from envs"
  f1=/tmp/cc-tls.crt
  cmd 'echo -e "$CC_CERT" > $f1'
  echo -e "$CC_CERT" > $f1 || return 1
  f2=/tmp/cc-tls.key
  cmd 'echo -e "$CC_KEY" > $f2'
  echo -e "$CC_KEY" > $f2 || return 1
  # BASE64_KEY=`echo -n "$CC_KEY" | openssl base64 -A`
  # BASE64_CERT=`echo -n "$CC_CERT" | openssl base64 -A`

  runCmd "$TEST" "Creating TLS secret $CC_TLS_A in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_A --key '$f2' --cert '$f1'" || return 1
  runCmd "$TEST" "Creating TLS secret $CC_TLS_K in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_K --key '$f2' --cert '$f1'" || return 1

  kubectl patch ingress control-center -n $CC_NS --type=merge --patch \
    '{"spec": {"tls": [{"hosts": ["'$CC_CONTROL'"],"secretName": "'$CC_TLS_A'"}]}}'

  kubectl patch ingress control-center -n $CC_NS --type=merge --patch \
    '{"spec": {"tls": [{"hosts": ["'$CC_AUTH'"],"secretName": "'$CC_TLS_K'"}]}}'

  cat $f2 $f2 > /tmp/$CC_DOMAIN.pem
  rm -f $f1 $f2
  pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'` || return 1
  [ -n "$pod" ] && runCmd "$TEST" "Reloading nginx in $pod" "kubectl exec $pod -n "$CC_NS" -- nginx -s reload" || return 1
  sleep 10
  # runCmd "$TEST" "Restaring ingress" \
  #   "kubectl -n $CC_NS rollout restart deployment control-center-ingress-nginx-controller" || return 1
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
  [ -z "$CC_CERT" -o -z "$CC_KEY" ] && NO_TLS=--notls || NO_TLS=--notls
  for f in $CC_TESTS; do
    ## loop until we get a valid https response from the control-center and keycloak
    waitUntilHttpResponse https://$CC_CONTROL '^< HTTP/2 401' || return 1
    waitUntilHttpResponse https://$CC_AUTH Keycloak || return 1
    runPlaywrightTests "$PIT_SCR_FOLDER/its/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --email=$CC_EMAIL $NO_TLS || return 1
    sleep 3
  done
}

## Main method for running control center
runControlCenter() {
    case "$1" in
      start)
        checkCommands kind helm docker kubectl || return 1
        ## Clean up from a previous run
        stopCloudProvider
        uninstallCC $CC_CLUSTER $CC_NS
        # deleteCluster $CC_CLUSTER
        ## Start a new cluster
        createCluster $CC_CLUSTER $CC_NS || return 1
        # startCloudProvider || return 1
        ## Install Control Center
        installCC || return 1
        ## Control center takes a long time to start
        waitForCC 900 || return 1
        ## Forward the ingress (it needs root access since it uses port 443)
        forwardIngress $CC_NS || return 1
        ## Show temporary user-email and password in the terminal
        showTemporaryPassword
        ## Install TLS certificates for the control-center and keycloak
        installTls
        ## Run Playwright tests
        runPwTests || return 1
        if [ -z "$KEEPCC" ]; then
          stopForwardIngress
          deleteCluster
        fi
        ;;
      stop)
        stopCloudProvider
        stopPortForward
        deleteCluster
        ;;
    esac
}








