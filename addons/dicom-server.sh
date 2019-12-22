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
   kubernetes.io/ingress.class: contour
   cert-manager.io/issuer: letsencrypt-staging
   ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
 tls:
 - secretName: dicom-cert
   hosts:
   - dicom.${DOMAIN}
 rules:
 - host: dicom.${DOMAIN}
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
        image: quay.io/kgorcz/dcmsvr:3
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 104
        env:
        - name: AWS_HOST
          value: "rook-ceph-rgw-my-store.rook-ceph"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: rook-ceph-object-user-my-store-my-user
              key: AccessKey
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: rook-ceph-object-user-my-store-my-user
              key: SecretKey
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
    fqdn: dicom.${DOMAIN}
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

cat <<EOF > web-api.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: web-api
  labels:
    app: web-api
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: web-api
    spec:
      containers:
      - name: web-api
        image: quay.io/kgorcz/web-api:1
        ports:
        - containerPort: 8080
        env:
        - name: AWS_HOST
          value: "rook-ceph-rgw-my-store.rook-ceph"
        - name: AWS_ENDPOINT
          value: "rook-ceph-rgw-my-store.rook-ceph:80"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: rook-ceph-object-user-my-store-my-user
              key: AccessKey
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: rook-ceph-object-user-my-store-my-user
              key: SecretKey
---
apiVersion: v1
kind: Service
metadata:
  name: web-api
spec:
  selector:
    app: web-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: web-api
  labels:
    app: web-api
  annotations:
    kubernetes.io/ingress.class: contour
    cert-manager.io/issuer: letsencrypt-staging
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: web-api
    hosts:
    - api.${DOMAIN}
  rules:
  - host: api.${DOMAIN}
    http:
      paths:
      - path: /
        backend:
          serviceName: web-api
          servicePort: 80
EOF

kubectl $kubecfg apply -f web-api.yaml


cat <<EOF > www.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: www
  labels:
    app: www
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: www
    spec:
      containers:
      - name: www
        image: quay.io/kgorcz/frontend:1
        ports:
        - containerPort: 3000
        env:
        - name: APIURL
          value: "https://api.${DOMAIN}/api"
---
apiVersion: v1
kind: Service
metadata:
  name: www
spec:
  selector:
    app: www
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: www
  labels:
    app: www
  annotations:
    kubernetes.io/ingress.class: contour
    cert-manager.io/issuer: letsencrypt-staging
    ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - secretName: www
    hosts:
    - www.${DOMAIN}
  rules:
  - host: www.${DOMAIN}
    http:
      paths:
      - path: /
        backend:
          serviceName: www
          servicePort: 80
EOF

kubectl $kubecfg apply -f www.yaml
