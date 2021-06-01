#!/bin/bash

CALICO_VERSION=v3.11
POD_CIDR=10.80.0.0/14
SERVICE_CIDR=10.96.0.0/14

pushd /home/admin

KUBERNETES_VERSION=$(dpkg -l | grep kubelet | awk '{print $3}' | awk -F - '{print $1}')

cat <<EOF | tee kubeadm-init-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: $KUBERNETES_VERSION
networking:
  serviceSubnet: $SERVICE_CIDR
  podSubnet: $POD_CIDR
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF


# Initialize kubernetes control plane
kubeadm init --config kubeadm-init-config.yaml 2>&1 | tee kubeinit.log

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
