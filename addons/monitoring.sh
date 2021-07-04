#!/bin/bash
kubecfg="--kubeconfig $1"

git clone https://github.com/coreos/kube-prometheus
pushd kube-prometheus
git checkout -b v07 v0.7.0
kubectl $kubecfg create -f manifests/setup
until kubectl $kubecfg get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl $kubecfg create -f manifests/
popd

cat <<EOF > grafana.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
  annotations:
    kubernetes.io/ingress.class: contour
    cert-manager.io/cluster-issuer: letsencrypt-staging
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: grafana
    hosts:
    - grafana.${DOMAIN}
  rules:
  - host: grafana.${DOMAIN}
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 3000
EOF

kubectl $kubecfg apply -f grafana.yaml
