#!/bin/bash 
kubecfg="--kubeconfig $1"
CONTOUR_VERSION=v0.5.0

wget https://github.com/heptio/contour/raw/$CONTOUR_VERSION/deployment/common/common.yaml
wget https://github.com/heptio/contour/raw/$CONTOUR_VERSION/deployment/deployment-grpc-v2/02-contour.yaml
wget https://github.com/heptio/contour/raw/$CONTOUR_VERSION/deployment/common/rbac.yaml
wget https://github.com/heptio/contour/raw/$CONTOUR_VERSION/deployment/common/service.yaml

sed "s|LoadBalancer|NodePort|" -i service.yaml
sed "s|targetPort: 8080|targetPort: 8080\n   nodePort: 32323|" -i service.yaml
sed "s|targetPort: 8443|targetPort: 8443\n   nodePort: 32324|" -i service.yaml

kubectl $kubecfg apply -f common.yaml
kubectl $kubecfg apply -f rbac.yaml
kubectl $kubecfg apply -f service.yaml
kubectl $kubecfg apply -f 02-contour.yaml

