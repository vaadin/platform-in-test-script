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
# CC_TLS_A=control-center-cert
# CC_TLS_K=control-center-keycloak-cert
CC_CLUSTER=cc-cluster
CC_NS=control-center
CC_TESTS="cc-setup.js cc-install-apps.js"

installCC() {
  [ -n "$VERBOSE" ] && D=--debug || D=""
  # [ -n "$CC_KEY" -a -n "$CC_CERT" ] && args="--set app.tlsSecret=$CC_TLS_A --set keycloak.tlsSecret=$CC_TLS_K" || args=""
  runCmd "$TEST" "Installing Vaadin Control Center" \
   "time helm install control-center oci://docker.io/vaadin/control-center \
    -n $CC_NS --create-namespace --set livenessProbe.failureThreshold=20 \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL --set keycloak.host=$CC_AUTH $D"

    # helm install control-center oci://docker.io/vaadin/control-center -n control-center --create-namespace  \
    #  --set domain=alcala.org   --set user.email=admin@alcala.org   \
    #  --set app.host=control-local.alcala.org   --set keycloak.host=auth-local.alcala.org  \
    #   --set livenessProbe.failureThreshold=15
    # $args 
    # --wait $D"
}

waitForCC() {
  log "Waiting for Control Center to be ready"
  last=""
  while true; do
      elapsed=`expr ${elapsed:-0} + 1`
      [ "$elapsed" -ge "${1:-900}" ] && log "Timeout $1 sec. exceeded." && return 1
      H=`kubectl get pods -n $CC_NS | egrep 'control-center-[0-9abcdef]+-..... ' | awk '{print $3" "$4}'`
      case "$H" in
        "")
          log "Control center not installed in k8s" && return 1 ;;
        Running*)
          echo "" && log "Done ($elapsed secs.)"
          return 0 ;;
        *)
          [ "$H" != "$last" ] && ([ -n "$last" ] && echo "" || true) && log "Control center initializing $H" || printf .
          last="$H"
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
  # pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'` || return 1
  # [ -n "$pod" ] && runCmd "$TEST" "Reloading nginx in $pod" "kubectl exec $pod -- nginx -s reload" || return 1
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
  computeNpm
  [ -n "$SKIPPW" ] && return 0
  for f in $CC_TESTS; do
    runPlaywrightTests "$PIT_SCR_FOLDER/its/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --email=$CC_EMAIL $NO_TLS || return 1
  done
}

runControlCenter() {
    case "$1" in
      start)
        checkCommands kind helm docker kubectl || return 1
        ## Clean up from a previous run
        stopCloudProvider
        deleteNamespace $CC_CLUSTER $CC_NS
        ## Start a new cluster
        createCluster $CC_CLUSTER $CC_NS || return 1
        startCloudProvider || return 1
        ## Install Control Center
        installCC || waitForCC 900 || return 1
        tmp_email=`kubectl get secret control-center-user -o go-template="{{ .data.email | base64decode | println }}"`
        computeTemporaryPassword
        forwardIngress $CC_NS || return 1
        waitUntilHttpResponse https://$CC_CONTROL 443 120 || return 1
        waitUntilHttpResponse https://$CC_AUTH 443 120 || return 1
        ## Update TLS certificates
        [ -n "$CC_KEY" -a -n "$CC_CERT" ] && installTls || NO_TLS="--notls"
        ## Run Playwright tests
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








