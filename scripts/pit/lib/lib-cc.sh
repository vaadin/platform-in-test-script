. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh

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

startCloudProvider() {
   [ -z "$TEST" ] && docker container inspect kind-cloud-provider >/dev/null 2>&1 && log "Docker Kind Cloud Provider already running" && return
   runCmd "$TEST" "Starting Docker KinD Cloud Provider" \
    "docker run --name kind-cloud-provider --rm  -d --network kind \
      -v /var/run/docker.sock:/var/run/docker.sock \
      rophy/cloud-provider-kind:0.4.0-20241026-r1"
}

stopCloudProvider() {
  docker ps | grep -q kind-cloud-provider || return
  runCmd "$TEST" "Stoping Docker KinD Cloud Provider" \
    "docker kill kind-cloud-provider" || return
  docker ps | grep envoyproxy/envoy | awk '{print $1}' | xargs docker kill 2>/dev/null
}

startPortForward() {
  [ -z "$3" ] && echo "args err usage: startPortForward name-space service port" && return 1
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && return 0
  KUBECTL=`which kubectl`
  [ -z "$TEST" ] && log "Starting k8s port-forward $1 $2 $3 -> $4"
  if isLinux || isMac ; then
    [ -z "$TEST" ] && log "listening to ports <1024 requires sudo, type your password if requested"
    [ -n "$TEST" ] && cmd "## Start k8s port-forward service $2 port:$3 -> localhost:$4"
    cmd "sudo KUBECONFIG=\$HOME/.kube/config kubectl port-forward $2 $4:$3 -n $1"
    [ -z "$TEST" ] && sudo -n true || sudo true
    sudo -n true || return 1
    [ -z "$TEST" ] && sudo -n KUBECONFIG="$HOME/.kube/config" $KUBECTL port-forward $2 $4:$3 -n $1 &
  else
    [ -n "$TEST" ] && cmd "## Start k8s port-forward service $2 port:$3 -> localhost:$4"
    cmd "KUBECONFIG=\$HOME/.kube/config kubectl port-forward $2 $4:$3 -n $1"
    [ -z "$TEST" ] && $KUBECTL port-forward $2 $4:$3 -n $1 &
  fi
  [ -z "$TEST" ] && sleep 2 || return 0
}

stopPortForward() {
  H=`getPids kubectl "port-forward service/$1"`
  [ -z "$H" ] && return 0
  log "Stoping k8s port-forward $1 (pid $H)"
  sudo bash -c "kill -9 $H" || return 1
}

forwardIngress() {
  startPortForward $CC_NS service/control-center-ingress-nginx-controller 443 443
}

stopForwardIngress() {
  stopPortForward control-center-ingress-nginx-controller
}

createCluster() {
  runCmd "$TEST" "Creating KinD cluster: $CC_CLUSTER" \
   "kind create cluster --name $CC_CLUSTER" || return 1
  runCmd "$TEST" "Setting default namespace $CC_NS" \
   "kubectl config set-context --current --namespace=$CC_NS"
}

deleteCluster() {
  runCmd "$TEST" "Deleting Cluster $CC_CLUSTER" \
   "kind delete cluster --name $CC_CLUSTER" || return 1
}

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
  [ -z "$CC_KEY" -o -z "$CC_CERT" ] && log "Skiping TLS certificate installation, because it was not provided provided" && return
  [ -z "$TEST" ] && log "Installing TLS $CC_TLS for $CC_DOMAIN" || cmd "## Creating TLS files from envs"
  f1=/tmp/cc-tls.crt
  cmd 'echo -e "$CC_CERT" > $f1'
  echo -e "$CC_CERT" > $f1
  f2=/tmp/cc-tls.key
  cmd 'echo -e "$CC_KEY" > $f2'
  echo -e "$CC_KEY" > $f2
  runCmd "$TEST" "Creating TLS secret $CC_TLS_A in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_A --key '$f2' --cert '$f1'" || return 1
  runCmd "$TEST" "Creating TLS secret $CC_TLS_K in cluster" \
    "kubectl -n $CC_NS create secret tls $CC_TLS_K --key '$f2' --cert '$f1'" || return 1
  rm -f $f1 $f2
  pod=`kubectl -n $CC_NS get pods | grep control-center-ingress-nginx-controller | awk '{print $1}'`
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
  its_folder=`computeAbsolutePath`/its
  for f in $CC_TESTS; do
    runPlaywrightTests "$its_folder/$f" "" "prod" "control-center" --url=https://$CC_CONTROL  --email=$CC_EMAIL || return 1
  done
}

runControlCenter() {
    computeNpm
    case "$1" in
      start)
        checkCommands kind helm docker kubectl || return 1
        deleteCluster
        stopForwardIngress
        createCluster || return 1
        stopCloudProvider
        startCloudProvider || return 1
        installCC || waitForCC 400 || return 1
        tmp_email=`kubectl get secret control-center-user -o go-template="{{ .data.email | base64decode | println }}"`
        computeTemporaryPassword
        installTls
        forwardIngress || return 1
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








