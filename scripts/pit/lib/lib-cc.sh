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

getPids() {
  H=`grep -a "" /proc/*/cmdline 2>/dev/null | xargs -0 | grep -v grep | perl -pe 's|/proc/(.*?)/cmdline:|$1 |g'`
  if [ -n "$H" ]
  then
    _P=`echo "$H" | grep "$1" | awk '{print $1}'`
  else   
    _P=`ps -feaw | grep "$1" | grep -v grep | awk '{print $2}'`
  fi
  [ -n "$_P" ] && echo "$_P" && return 0 || return 1
}

startCloudProvider() {
   docker container inspect kind-cloud-provider >/dev/null 2>&1 && log "Docker Kind Cloud Provider already running" && return
   log "Starting Docker KinD Cloud Provider"
   cmd="docker run --name kind-cloud-provider --rm  -d --network kind \
     -v /var/run/docker.sock:/var/run/docker.sock \
     rophy/cloud-provider-kind:0.4.0-20241026-r1"
   echo "#" $cmd
   eval "$cmd"
}

stopCloudProvider() {
  docker kill kind-cloud-provider 2>/dev/null || return
  log "Stoped Docker KinD Cloud Provider"
}

startPortForward() {
  [ -z "$3" ] && echo "startPortForward name-space service port" && return 1
  H=`getPids "kubectl port-forward $2"`
  [ -n "$H" ] && return 0

  log "Starting k8s port-forward $1 $2 $3 -> $4"
  if isLinux || isMac ; then
    sudo KUBECONFIG="$HOME/.kube/config" kubectl port-forward $2 $4:$3 -n $1 &
  else
    kubectl port-forward $2 $4:$3 -n $1 &
  fi
}

stopPortForward() {
  set -x
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
  log "Creating cluster"
  echo "# kind create cluster --name $CC_CLUSTER"
  kind create cluster --name $CC_CLUSTER || return 1
  kubectl config use-context kind-$CC_CLUSTER
  kubectl config set-context --current --namespace=$CC_NS
}

deleteCluster() {
  log "Deleting cluster"
  kind delete cluster --name $CC_CLUSTER
}

installCC() {
  log "Installing Control Center"
  [ -n "$DEBUG" ] && D=--debug
  cmd="helm install control-center oci://docker.io/vaadin/control-center \
    -n $CC_NS --create-namespace \
    --set domain=$CC_DOMAIN \
    --set user.email=$CC_EMAIL \
    --set app.host=$CC_CONTROL \
    --set app.tlsSecret=$CC_TLS \
    --set keycloak.host=$CC_AUTH \
    --set keycloak.tlsSecret=$CC_TLS \
    --set livenessProbe.failureThreshold=10 \
    --wait $D"
  echo "#" $cmd
  eval $cmd || return 1
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

installDashBoard() {
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    --create-namespace --namespace kubernetes-dashboard || return 1
  
  cat << EOF | kubectl create -n kubernetes-dashboard -f - >/dev/null 2>&1
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
cc_auth=`kubectl -n kubernetes-dashboard create token admin-user` 
[ -z "$cc_auth" ] && return 1
startPortForward kubernetes-dashboard service/kubernetes-dashboard-kong-proxy 443 8443
log "Login into dashboard with this token: $cc_auth"
}

uninstallDashBoard() {
  stopPortForward kubernetes-dashboard
  kubectl delete ns kubernetes-dashboard
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
  kubectl -n $CC_NS create secret tls $CC_TLS --key "$f2" --cert "$f1"
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








