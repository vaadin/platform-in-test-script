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








