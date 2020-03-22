#!/bin/bash

KUBERNETES_VERSION=1.17.0-00
DOCKER_VERSION=5:18.09.9~3-0~debian-buster
CNI_VERSION=0.7.5-00
CALICO_VERSION=v3.11
POD_CIDR=10.80.0.0/14
SERVICE_CIDR=10.96.0.0/14

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common

# Add kubernetes and docker apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

# Install docker and kubernetes
apt-get update
apt-get install -y docker-ce=$DOCKER_VERSION
apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION kubernetes-cni=$CNI_VERSION

systemctl enable docker

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
