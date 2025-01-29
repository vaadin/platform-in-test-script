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

## Check that the command has SUID bit set
# $1: command
hasSUID() {
  [ ! -x "$1" ] && return 1
  R=`realpath "$1"` || return 1
  O=`ls -l "$R" | awk '{print $3}'`
  P=`ls -l "$R" | awk '{print $1}'`
  [ "$O" = "root" ] && expr "$P" : "^-..s" >/dev/null && return 0 || return 1
}

## Set SUID bit to the command
# $1: command
setSuid() {
  isWindows && return 0
  T=/tmp/$1
  for W in "$T" `which "$1"`; do
    hasSUID "$W" && echo "$W" && return 0
  done
  R=`realpath $W` || return 1

  sudo -n true >/dev/null 2>&1 || log "It's necessary to provide sudo password to run '$1' as root"
  sudo -B true || return 1

  runCmd "$TEST" "Changing owner to root to: $R" "sudo chown root $R" \
    && runCmd "$TEST" "Changing set-uid to: $R" "sudo chmod u+s $R" && echo "kubectl" && return 0

  runCmd "$TEST" "Coping $R" "sudo cp $R $T" \
    && runCmd "$TEST" "Changing owner to root to: $T" "sudo chown root $T" \
    && runCmd "$TEST" "Changing set-uid to: $R" "sudo chmod u+s $T" && echo "$T" && return 0
}

##
# $1: namespace
# $2: service
# $3: port in guest
# $4: target port in host
startPortForward() {
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && log "Already running k8s port-forward $1 $2 $3 -> $4 with pid $H" && return 0
  [ -z "$TEST" ] && log "Starting k8s port-forward $1 $2 $3 -> $4"
  [ "$4" -le 1024 ] && K=`setSuid kubectl` || return 1
  bgf="k8s-port-forward-$3-$4.log"
  rm -f "$bgf"
  runInBackgroundToFile "$K port-forward $2 $4:$3 -n $1" "$bgf"
  sleep 2
  egrep 'Forwarding from' "$bgf"
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







