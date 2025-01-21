. `dirname $0`/lib/lib-utils.sh

startCloudProvider() {
   [ -z "$TEST" ] && docker container inspect kind-cloud-provider >/dev/null 2>&1 && log "Docker Kind Cloud Provider already running" && return
   runCmd "$TEST" "Starting Docker KinD Cloud Provider" \
    "docker run --quiet --name kind-cloud-provider --rm  -d  \
      -v /var/run/docker.sock:/var/run/docker.sock \
      rophy/cloud-provider-kind:0.4.0-20241026-r1"

      # --network kind -p 443:443
}

stopCloudProvider() {
  docker ps | grep kind-cloud-provider || return 0
  runCmd "$TEST" "Stoping Docker KinD Cloud Provider" \
    "docker kill kind-cloud-provider" || return 1
  docker ps | grep envoyproxy/envoy | awk '{print $1}' | xargs docker kill 2>/dev/null
}

##
# $1: command
setSuid() {
  W=`which $1` || return 1
  R=`realpath $W` || return 1
  O=`ls -l "$R" | awk '{print $3}'`
  P=`ls -l "$R" | awk '{print $1}'`
  echo "$O $P"
  [ "$O" = "root" ] || runCmd "$TEST" "Changing owner to root to: $R" "sudo chown root $R" || return 1
  expr "$P" : "^-..s" >/dev/null || runCmd "$TEST" "Setting sUI to $R" "sudo chmod u+s $R" || return 1
}

##
# $1: namespace
# $2: service
# $3: port in guest
# $4: target port in host
startPortForward() {
  echo 1 "$1"
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && log "Already running k8s port-forward $1 $2 $3 -> $4 with pid $H" && return 0
  [ -z "$TEST" ] && log "Starting k8s port-forward $1 $2 $3 -> $4"
  [ "$4" -le 1024 ] && setSuid kubectl || return 1
  runInBackgroundToFile "kubectl port-forward $2 $4:$3 -n $1" "k8s-port-forward-$3-$4.log" || return 1
}

##
# $1: service
stopPortForward() {
  H=`getPids kubectl "port-forward service/$1"`
  [ -z "$H" ] && return 0
  runCmd "$TEST" "Stoping k8s port-forward $1" "kill -TERM $H" || return 1
}

forwardIngress() {
  startPortForward ${1:-$CC_NS} service/control-center-ingress-nginx-controller 443 443 || return 1
  sleep 3
}

stopForwardIngress() {
  stopPortForward control-center-ingress-nginx-controller
}

##
# $1: cluster name
# $2: namespace
createCluster() {
  kind get clusters | grep -q "^$1$" && return 0
  runCmd "$TEST" "Creating KinD cluster: $1" \
   "kind create cluster --name $1" || return 1
  runCmd "$TEST" "Setting default namespace $2" \
   "kubectl config set-context --current --namespace=$2"
}

##
# $1: cluster name
deleteCluster() {
  kind get clusters | grep -q "^$1$" || return 0
  runCmd "$TEST" "Deleting Cluster $1" \
   "kind delete cluster --name $1" || return 1
}







