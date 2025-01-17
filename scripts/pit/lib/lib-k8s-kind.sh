. `dirname $0`/lib/lib-utils.sh

startCloudProvider() {
   [ -z "$TEST" ] && docker container inspect kind-cloud-provider >/dev/null 2>&1 && log "Docker Kind Cloud Provider already running" && return
   runCmd "$TEST" "Starting Docker KinD Cloud Provider" \
    "docker run --quiet --name kind-cloud-provider --rm  -d --network kind \
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
  startPortForward $1 service/control-center-ingress-nginx-controller 443 443
}

stopForwardIngress() {
  stopPortForward control-center-ingress-nginx-controller
}

createCluster() {
  runCmd "$TEST" "Creating KinD cluster: $1" \
   "kind create cluster --name $1" || return 1
  runCmd "$TEST" "Setting default namespace $2" \
   "kubectl config set-context --current --namespace=$2"
}

deleteCluster() {
  runCmd "$TEST" "Deleting Cluster $1" \
   "kind delete cluster --name $1" || return 1
}








