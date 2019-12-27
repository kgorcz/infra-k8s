#!/bin/bash 
kubecfg="--kubeconfig $1"

cat <<EOF > kuard.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuard
  labels:
    app: kuard
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kuard
  template:
    metadata:
      labels:
        app: kuard
    spec:
      containers:
      - name: kuard
        image: gcr.io/kuar-demo/kuard-amd64:1
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kuard
spec:
  selector:
    app: kuard
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kuard
  labels:
    app: kuard
  annotations:
    kubernetes.io/ingress.class: contour
    cert-manager.io/issuer: letsencrypt-staging
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: kuard
    hosts:
    - kuard.${DOMAIN}
  rules:
  - host: kuard.${DOMAIN}
    http:
      paths:
      - path: /
        backend:
          serviceName: kuard
          servicePort: 80
EOF

kubectl $kubecfg apply -f kuard.yaml
