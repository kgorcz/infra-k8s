#!/bin/bash 
kubecfg="--kubeconfig $1"

cat <<EOF > echoserver.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: echoserver
  labels:
    app: echoserver
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: echoserver
    spec:
      containers:
      - name: echoserver
        image: gcr.io/google_containers/echoserver:1.4
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echoserver
spec:
  selector:
    app: echoserver
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echoserver
  labels:
    app: echoserver
  annotations:
    kubernetes.io/tls-acme: "true"
    certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: echoserver
    hosts:
    - echo.kgorcz.net
  rules:
  - host: echo.kgorcz.net
    http:
      paths:
      - path: /
        backend:
          serviceName: echoserver
          servicePort: 80
EOF

kubectl $kubecfg apply -f echoserver.yaml

