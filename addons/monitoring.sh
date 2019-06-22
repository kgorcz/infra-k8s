#!/bin/bash
kubecfg="--kubeconfig $1"

git clone https://github.com/coreos/kube-prometheus
pushd kube-prometheus
git checkout -b v01 v0.1.0
kubectl $kubecfg create -f manifests/
until kubectl $kubecfg get customresourcedefinitions servicemonitors.monitoring.coreos.com ; do date; sleep 1; echo ""; done
until kubectl $kubecfg get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl $kubecfg apply -f manifests/
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
    kubernetes.io/tls-acme: "true"
    certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: grafana
    hosts:
    - grafana.kgorcz.net
  rules:
  - host: grafana.kgorcz.net
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 3000
EOF

kubectl $kubecfg apply -f grafana.yaml
