#!/bin/bash

KUBERNETES_VERSION=1.20.15-00
CONTAINERD_VERSION=1.4.13~ds1-1~deb11u2
CNI_VERSION=0.8.7-00

sleep 30

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common htop

# Add kubernetes apt repo
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install containerd
sudo apt-get update
sudo apt-get install -y containerd=$CONTAINERD_VERSION cri-tools

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i -e "s?plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]?plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]\n            SystemdCgroup = true?g" /etc/containerd/config.toml
sudo systemctl restart containerd

sleep 5

sudo crictl -r unix:///var/run/containerd/containerd.sock version
sudo crictl -r unix:///var/run/containerd/containerd.sock info

# Install kubernetes
sudo apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION kubernetes-cni=$CNI_VERSION

sudo kubeadm config images pull

sudo crictl -r unix:///var/run/containerd/containerd.sock pull ceph/ceph:v14.2.1-20190430
