#!/bin/bash

BOOTPORT_KEY=/etc/ssh/id_rsa_bootport

cd /home/admin

cat <<EOF > teleport.yaml
proxy_service:
  kubernetes:
    enabled: yes
    public_addr: ${bastion_public_ip}:3026
    listen_addr: 0.0.0.0:3026
    kubeconfig_file: /home/bootport/sa.kubeconfig
EOF

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTPORT_KEY teleport.yaml bootport@${bastion_private_ip}:/home/bootport

cat <<EOF > teleport-impersonate-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: teleport-impersonation
rules:
- apiGroups:
  - ""
  resources:
  - users
  - groups
  - serviceaccounts
  verbs:
  - impersonate
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: teleport
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: teleport-impersonation
subjects:
- kind: ServiceAccount
  # this should be changed to the name of the Kubernetes ServiceAccount being used
  name: teleport
  namespace: default
EOF

kubecfg="/home/admin/.kube/config"
kubectl --kubeconfig $kubecfg create serviceaccount teleport
kubectl --kubeconfig $kubecfg apply -f teleport-impersonate-rbac.yaml

# your server name goes here
apiserver=$(kubectl --kubeconfig $kubecfg get nodes -o wide | grep master | awk '{print $6}')
# the name of the secret containing the service account token goes here
name=$(kubectl --kubeconfig $kubecfg get secrets | grep teleport | awk '{print $1}')

ca=$(kubectl --kubeconfig $kubecfg get secret/$name -o jsonpath='{.data.ca\.crt}')
token=$(kubectl --kubeconfig $kubecfg get secret/$name -o jsonpath='{.data.token}' | base64 --decode)

echo "
apiVersion: v1
kind: Config
clusters:
- name: default-cluster
  cluster:
    certificate-authority-data: $ca
    server: https://$apiserver:6443
contexts:
- name: default-context
  context:
    cluster: default-cluster
    namespace: default
    user: default-user
current-context: default-context
users:
- name: default-user
  user:
    token: $token
" > sa.kubeconfig

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTPORT_KEY sa.kubeconfig bootport@${bastion_private_ip}:/home/bootport
