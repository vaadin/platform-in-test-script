. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh
. `dirname $0`/lib/lib-k8s-kind.sh

## Configuration
CC_DOMAIN=alcala.org
CC_CONTROL=control-local.$CC_DOMAIN
CC_AUTH=auth-local.$CC_DOMAIN
CC_EMAIL=admin@$CC_DOMAIN
CC_TLS_A=cc-control-app-tls
CC_TLS_K=cc-control-login-tls
CC_CLUSTER=cc-cluster
CC_NS=control-center
CC_TESTS="cc-setup.js cc-install-apps.js"

installCC() {
  [ -n "$VERBOSE" ] && D=--debug
  runCmd "$TEST" "Installing Vaadin Control Center" \
   "helm install control-center oci://docker.io/vaadin/control-center \
    -n $CC_NS --create-namespace \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL \
    --set keycloak.host=$CC_AUTH \
    --set keycloak.tlsSecret=$CC_TLS_K \
    --set app.tlsSecret=$CC_TLS_A \
    --set livenessProbe.failureThreshold=10 \
    --wait $D"
}

waitForCC() {
  log "Waiting for Control Center to be ready"
  while true; do
      elapsed=`expr ${elapsed:-0} + 1`
      [ "$elapsed" -ge "$1" ] && log "Timeout $1 sec. exceeded." && return 1
      H=`kubectl get pods -n $CC_NS | egrep 'control-center-[0-9abcdef]+-..... ' | awk '{print $3" "$4}'`
      case "$H" in
        "")
          log "Control center not installed in k8s" && return 1 ;;
        Running*)
          return 0 ;;
        *)
          log "Control center initializing $H"
          sleep 1
          ;;
      esac
  done
}

uninstallCC() {
  kubectl delete ns $CC_NS
  kubectl delete ns ingress-nginx
}

installTls() {
  [ -z "$TEST" ] && log "Installing TLS $CC_TLS for $CC_DOMAIN" || cmd "## Creating TLS files from envs"
  f1=/tmp/cc-tls.crt
  cmd 'echo -e "$CC_CERT" > $f1'
  echo -e "$CC_CERT" > $f1 || return 1
  f2=/tmp/cc-tls.key
  cmd 'echo -e "$CC_KEY" > $f2'
  echo -e "$CC_KEY" > $f2 || return 1
  runCmd "$TEST" "Creating TLS secret $CC_TLS_A in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_A --key '$f2' --cert '$f1'" || return 1
  runCmd "$TEST" "Creating TLS secret $CC_TLS_K in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_K --key '$f2' --cert '$f1'" || return 1
  cat $f2 $f2 > /tmp/$CC_DOMAIN.pem
  rm -f $f1 $f2
  pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'` || return 1
  [ -n "$pod" ] && runCmd "$TEST" "Reloading nginx in $pod" "kubectl exec $pod -- nginx -s reload" || return 1
  # runCmd "$TEST" "Restaring ingress" \
  #   "kubectl -n $CC_NS rollout restart deployment control-center-ingress-nginx-controller" || return 1
}

computeTemporaryPassword() {
  email=`runCmd "$TEST" "Getting temporary admin email for Control Center" \
    "kubectl -n $CC_NS get secret control-center-user -o go-template=\"{{ .data.email | base64decode | println }}\""`
  passw=`runCmd "$TEST" "Getting temporary admin password for Control Center" \
    "kubectl -n $CC_NS get secret control-center-user -o go-template=\"{{ .data.password | base64decode | println }}\""`
  [ -n "$email" -a -n "$passw" ] && warn "Temporary credentials for Control Center: $email / $passw"
}

runPwTests() {
  [ -n "$SKIPPW" ] && return 0
  for f in $CC_TESTS; do
    runPlaywrightTests "$PIT_SCR_FOLDER/its/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --email=$CC_EMAIL $NO_TLS || return 1
  done
}

runControlCenter() {
    computeNpm
    case "$1" in
      start)
        checkCommands kind helm docker kubectl || return 1
        deleteCluster $CC_CLUSTER
        stopForwardIngress $CC_NS
        createCluster $CC_CLUSTER $CC_NS || return 1
        stopCloudProvider
        startCloudProvider || return 1
        installCC || waitForCC 400 || return 1
        tmp_email=`kubectl get secret control-center-user -o go-template="{{ .data.email | base64decode | println }}"`
        computeTemporaryPassword
        [ -n "$CC_KEY" -a -n "$CC_CERT" ] && installTls || NO_TLS="--notls"
        forwardIngress $CC_NS || return 1
        runPwTests || return 1
        err=$?
        if [ -z "$KEEPCC" ]; then
          stopForwardIngress
          deleteCluster
        fi
        return $err
        ;;
      stop)
        stopCloudProvider
        deleteCluster
        ;;
    esac
}








