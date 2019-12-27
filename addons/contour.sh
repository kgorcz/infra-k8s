#!/bin/bash 
kubecfg="--kubeconfig $1"

git clone https://github.com/kgorcz/contour
cd contour
git checkout layer-4-ingress
cd deployment/deployment-grpc-v2

sed "s|extensions/v1beta1|apps/v1|" -i 02-contour.yaml
sed "s|mycontour:5|quay.io/kgorcz/contour:1|" -i 02-contour.yaml
sed "s|targetPort: 8080|targetPort: 8080\n   nodePort: 32323|" -i 02-service.yaml
sed "s|targetPort: 8443|targetPort: 8443\n   nodePort: 32324|" -i 02-service.yaml
sed "s|targetPort: 104|targetPort: 104\n   nodePort: 32325|" -i 02-service.yaml
sed "s|type: NodePort|type: NodePort\n externalTrafficPolicy: Local|" -i 02-service.yaml
sed "s|replicas: 1|replicas: 4|" -i 02-contour.yaml

kubectl $kubecfg apply -f .
