#!/bin/bash 
kubecfg="--kubeconfig $1"

git clone https://github.com/rook/rook
pushd rook
git checkout -b v091 v0.9.1
cd cluster/examples/kubernetes/ceph/
kubectl $kubecfg apply -f operator.yaml
kubectl $kubecfg apply -f cluster.yaml
kubectl $kubecfg apply -f object.yaml
kubectl $kubecfg apply -f object-user.yaml
popd
