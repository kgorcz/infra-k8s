#!/bin/bash

CALICO_VERSION=v3.11
POD_CIDR=10.80.0.0/14
SERVICE_CIDR=10.96.0.0/14

apt-get update

IP_ADDR=$(ip addr | grep inet | grep eth0 | awk '{ print $2 }' | awk -F '/' '{ print $1 }')
pushd /home/admin

# Initialize kubernetes control plane
kubeadm init --apiserver-advertise-address=$IP_ADDR --service-cidr=$SERVICE_CIDR --pod-network-cidr=$POD_CIDR 2>&1 | tee kubeinit.log

# Copy kubernetes configuration file
mkdir -p .kube
cp -i /etc/kubernetes/admin.conf .kube/config
chown admin:admin .kube
chown admin:admin .kube/config
kubecfg="/home/admin/.kube/config"

# Copy the join command for the worker nodes to use
grep -C1 "kubeadm join" kubeinit.log > /home/bootk8s/kube_join.sh
cp /etc/ssh/ssh_host_rsa_key.pub /home/bootk8s/ssh_host_rsa_key.pub
chown bootk8s:bootk8s /home/bootk8s/*

wget https://docs.projectcalico.org/${CALICO_VERSION}/manifests/calico.yaml
sed -i -e "s?192.168.0.0/16\"?$POD_CIDR\"\n            - name: FELIX_IPTABLESBACKEND\n              value: \"NFT\"?g" calico.yaml
kubectl --kubeconfig $kubecfg apply -f calico.yaml

popd
