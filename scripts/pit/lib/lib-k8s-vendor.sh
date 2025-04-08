. `dirname $0`/lib/lib-utils.sh

C_KIND_PREFIX=kind-
C_DO_REG=fra1
C_DO_PREFIX=do-${C_DO_REG}-

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
  isWindows && echo "$1" && return 0
  T=/tmp/$1
  for W in "$T" `which "$1"`; do
    hasSUID "$W" && echo "$W" && return 0
  done
  R=`realpath $W` || return 1

  sudo -n true >/dev/null 2>&1 || log "It's necessary to provide sudo password to run '$1' as root"
  sudo -B true || return 1

  runCmd "Changing owner to root to: $R" "sudo chown root $R" \
    && runCmd "Changing set-uid to: $R" "sudo chmod u+s $R" && echo "kubectl" && return 0

  runCmd "Coping $R" "sudo cp $R $T" \
    && runCmd "Changing owner to root to: $T" "sudo chown root $T" \
    && runCmd "Changing set-uid to: $R" "sudo chmod u+s $T" && echo "$T" && return 0
}

##
# $1: namespace
# $2: service
# $3: port in guest
# $4: target port in host
startPortForward() {
  [ -z "$TEST" ] && checkPort "$4" && err "Port $4 is already in use" && return 1
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && log "Already running k8s port-forward $1 $2 $3 -> $4 with pid $H" && return 0
  [ -z "$TEST" ] && log "Starting k8s port-forward $1 $2 $3 -> $4"
  [ "$4" -le 1024 ] && K=`setSuid kubectl` || return 1
  bgf="k8s-port-forward-$3-$4.log"
  rm -f "$bgf"
  runInBackgroundToFile "$K port-forward $2 $4:$3 -n $1" "$bgf"
  [ -n "$TEST" ] && return 0
  sleep 2
  [ -n "$VERBOSE" ] && tail "$bgf"
  egrep -q 'Forwarding from' "$bgf"
}

##
# $1: service
stopPortForward() {
  H=`getPids kubectl "port-forward service/$1"`
  [ -z "$H" ] && return 0
  runCmd -q "Stoping k8s port-forward $1" "kill -TERM $H" || return 1
}

forwardIngress() {
  startPortForward ${1:-$CC_NS} service/control-center-ingress-nginx-controller 443 443 || return 1
}

stopForwardIngress() {
  stopPortForward control-center-ingress-nginx-controller
}

##
# $1: cluster name
createKindCluster() {
  checkCommands kind || return 1
  kind get clusters 2>/dev/null | grep -q "^$1$" && log "Reusing Kind cluster: '$1'" && return 0
  runCmd -qf "Creating KinD cluster: $1" \
   "kind create cluster --name $1" || return 1
}

##
# $1: cluster name
deleteKindCluster() {
  checkCommands kind || return 1
  kind get clusters | grep -q "^$1$" || return 0
  runCmd -q "Deleting Cluster $1" "kind delete cluster --name $1" || return 1
}

createDOCluster() {
  size=${2:-s-4vcpu-8gb}
  nodes=1
  checkCommands doctl || return 1
  doctl kubernetes cluster get "$1" >/dev/null 2>&1 && log "Reusing DO cluster: '$1'" && return 0
  runCmd -qf "Create Cluster in DO $1" doctl kubernetes cluster create $1 --region fra1 --node-pool "'name=$1;size=$size;count=$nodes'"
}

deleteDOCluster() {
  checkCommands doctl || return 1
  runCmd -q "Delete Cluster in DO $name" "doctl kubernetes cluster delete $1 --force --dangerous" 
}

createCluster() {
  name=${1:-$CLUSTER}
  case "$2" in
    kind) createKindCluster $name ;;
    do)   createDOCluster $name ;;
    *)    :;;
  esac
}

deleteCluster() {
  name=${1:-$CLUSTER}
  type=$2
  case "$name" in
    $C_KIND_PREFIX*) type=kind ;;
    $C_DO_PREFIX*) type=do ;;
  esac
  name=`echo "$name" | sed -e "s|^$C_KIND_PREFIX||" -e "s|^$C_DO_PREFIX||"`
  case "$type" in
    kind) deleteKindCluster $name ;;
    do)   deleteDOCluster $name ;;
    *)    :;;
  esac
}

setClusterContext() {
  ns=$2
  case $3 in
    kind) current=kind-$1 ;;
    do)   current=do-fra1-$1 ;;
    *)    current=$1
  esac
  H=`kubectl config get-contexts  | tr '*' ' ' | awk '{print $1}' `
  [ -z "$H" ] && log "Cluster $current not found in kubectl contexts" && return 1
  runCmd -q "Setting context to $current" "kubectl config use-context $current" || return 1
  H=`kubectl config current-context`
  [ "$H" != "$current" ] && log "Current context is not $current" && return 1
  runCmd -q "Setting default namespace to $ns" "kubectl config set-context --current --namespace=$ns" || return 1
  kubectl get ns >/dev/null 2>&1 || return 1
}

