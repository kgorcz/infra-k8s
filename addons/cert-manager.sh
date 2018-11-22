#!/bin/bash 
kubecfg="--kubeconfig $1"

git clone https://github.com/jetstack/cert-manager
pushd cert-manager
git checkout -b v03 v0.3.2
kubectl $kubecfg apply -f contrib/manifests/cert-manager/with-rbac.yaml
popd

cat <<EOF > letsencrypt-staging.yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    email: ${EMAIL}
    http01: {}
    privateKeySecretRef:
      name: letsencrypt-staging
    server: https://acme-staging-v02.api.letsencrypt.org/directory
EOF

kubectl $kubecfg apply -f letsencrypt-staging.yaml

