. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-playwright.sh

## Configuration
CC_DOMAIN=alcala.org
CC_CONTROL=control-local.$CC_DOMAIN
CC_AUTH=auth-local.$CC_DOMAIN
CC_EMAIL=admin@$CC_DOMAIN
CC_TLS=control-center-tls
CC_CLUSTER=cc-cluster
CC_NS=control-center

startCloudProvider() {
   docker container inspect kind-cloud-provider >/dev/null 2>&1 && log "Docker Kind Cloud Provider already running" && return
   runCmd "$TEST" "Starting Docker KinD Cloud Provider" \
    "docker run --name kind-cloud-provider --rm  -d --network kind \
      -v /var/run/docker.sock:/var/run/docker.sock \
      rophy/cloud-provider-kind:0.4.0-20241026-r1"
}

stopCloudProvider() {
  docker kill kind-cloud-provider 2>/dev/null || return
  log "Stoped Docker KinD Cloud Provider"
}

startPortForward() {
  [ -z "$3" ] && echo "startPortForward name-space service port" && return 1
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && return 0
  KUBECTL=`which kubectl`
  log "Starting k8s port-forward $1 $2 $3 -> $4"
  if isLinux || isMac ; then
    log "listening to ports <1024 requires sudo, type your password if requested"
    sudo true || return 1
    sudo KUBECONFIG="$HOME/.kube/config" $KUBECTL port-forward $2 $4:$3 -n $1 &
  else
    $KUBECTL port-forward $2 $4:$3 -n $1 &
  fi
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
    --set app.tlsSecret=$CC_TLS \
    --set keycloak.host=$CC_AUTH \
    --set keycloak.tlsSecret=$CC_TLS \
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
          log "Control center running $H" && return 0 ;;
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
  log "Installing TLS $CC_TLS for $CC_DOMAIN"
  f1=/tmp/cc-tls.crt
  echo -e "$CC_CERT" > $f1
  f2=/tmp/cc-tls.key
  echo -e "$CC_KEY" > $f2
  runCmd "$TEST" "Creating TLS secret $CC_TLS" \
    "kubectl -n $CC_NS create secret tls $CC_TLS --key '$f2' --cert '$f1'"
  rm -f $f1 $f2
}

runControlCenter() {
    computeNpm
    case "$1" in
      start)
        checkCommands kind helm docker kubectl || return 1
        deleteCluster
        createCluster || return 1
        stopCloudProvider
        startCloudProvider || return 1
        installCC || waitForCC 400 || return 1
        [ -n "$CC_KEY" -a -n "$CC_CERT" ] && installTls || return 1
        forwardIngress || return 1
        sleep 2
        tmp_pass=`kubectl -n $CC_NS get secret control-center-user -o go-template="{{ .data.password | base64decode | println }}"`
        log "Control Center installed, login to https://$CC_CONTROL with the username $CC_EMAIL and password: $tmp_pass"
        test=`computeAbsolutePath`/its/cc-setup.js
        checkPort 443 || return 1
        runPlaywrightTests "$test" "" "prod" "control-center" --url=https://$CC_CONTROL  --email=$CC_EMAIL
        stopForwardIngress
        deleteCluster
        ;;
      stop)
        stopCloudProvider
        deleteCluster
        ;;
      install-board)
        installDashBoard ;;
      uninstall-board)
        uninstallDashBoard ;;
    esac
}








