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
log "Login into dashboard with this token: $cc_auth"
}

uninstallDashBoard() {
  kubectl delete ns kubernetes-dashboard
}








