#!/bin/bash

KUBERNETES_VERSION=1.17.0-00
DOCKER_VERSION=5:18.09.9~3-0~debian-buster
CNI_VERSION=0.7.5-00

sleep 30

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common htop

# Add kubernetes and docker apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

# Install docker and kubernetes
sudo apt-get update
sudo apt-get install -y docker-ce=$DOCKER_VERSION
sudo apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION kubernetes-cni=$CNI_VERSION

sudo systemctl enable docker

sudo kubeadm config images pull

sudo docker pull ceph/ceph:v14.2.1-20190430
