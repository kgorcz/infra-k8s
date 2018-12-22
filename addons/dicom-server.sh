#!/bin/bash
kubecfg="--kubeconfig $1"


cat <<EOF > dicom-cert.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dicom-cert
  labels:
    app: dicom-cert
spec:
  containers:
  - name: dicom-cert
    image: gcr.io/google_containers/echoserver:1.4
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: dicom-cert
spec:
  selector:
    app: dicom-cert
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: dicom-cert
 labels:
   app: dicom-cert
 annotations:
   kubernetes.io/tls-acme: "true"
   certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
   ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
 tls:
 - secretName: dicom-cert
   hosts:
   - dicom.kgorcz.net
 rules:
 - host: dicom.kgorcz.net
   http:
     paths:
     - path: /
       backend:
         serviceName: dicom-cert
         servicePort: 80
EOF

kubectl $kubecfg apply -f dicom-cert.yaml

while [ $(kubectl $kubecfg get secret dicom-cert | grep dicom-cert | wc -l) -lt 1 ]
do
    echo Waiting for dicom-cert...
    sleep 5
done

kubectl $kubecfg delete ing dicom-cert

cat <<EOF > dicom-server.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: dicom-server
  labels:
    app: dicom-server
spec:
  replicas: 3
  template:
    metadata:
      name: dicom-server
      labels:
        app: dicom-server
    spec:
      containers:
      - name: dicom-server
        image: quay.io/kgorcz/dcmsvr:2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 104
---
apiVersion: v1
kind: Service
metadata:
  name: dicom-server
spec:
  selector:
    app: dicom-server
  ports:
  - protocol: TCP
    port: 104
    targetPort: 104
---
apiVersion: contour.heptio.com/v1beta1
kind: IngressRoute
metadata: 
  name: dicom-server
  namespace: default
spec: 
  virtualhost:
    fqdn: dicom.kgorcz.net
    port: 104
    tls:
      secretName: dicom-cert
  routes: 
    - match: /
      services: 
      - name: dicom-server
        port: 104
EOF

kubectl $kubecfg apply -f dicom-server.yaml
