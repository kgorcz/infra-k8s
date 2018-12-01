#!/bin/bash
    
KUBERNETES_VERSION=1.9.0-00
CALICO_VERSION=v3.1
POD_CIDR=10.80.0.0/14
SERVICE_CIDR=10.96.0.0/14

# Add kubernetes apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install docker and kubernetes
apt-get update
apt-get install -y docker.io
apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION

IP_ADDR=$(ifconfig | grep "10.0" | awk -F ':' '{ print $2 }' | awk '{ print $1 }')
pushd /home/ubuntu

# Initialize kubernetes control plane
kubeadm init --apiserver-advertise-address=$IP_ADDR --service-cidr=$SERVICE_CIDR --pod-network-cidr=$POD_CIDR 2>&1 | tee kubeinit.log

# Copy kubernetes configuration file
mkdir -p .kube
cp -i /etc/kubernetes/admin.conf .kube/config
chown ubuntu:ubuntu .kube
chown ubuntu:ubuntu .kube/config
kubecfg="/home/ubuntu/.kube/config"

# Install calico for pod networking
wget https://docs.projectcalico.org/$CALICO_VERSION/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml
sed "s|value: \"192.168.0.0/16\"|value: \"$POD_CIDR\"|" -i calico.yaml
kubectl --kubeconfig $kubecfg apply -f calico.yaml

# Update dns (https://stackoverflow.com/questions/51774585/no-outgoing-network-connection-in-kubernetes-cluster/51792099#51792099)
# Is this fixed with an update to ubuntu?
cat <<EOF > dns.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
data:
  upstreamNameservers: |
    ["10.0.0.2"]
EOF
kubectl --kubeconfig $kubecfg apply -f dns.yaml
dns_pod=$(kubectl --kubeconfig $kubecfg get pod -n kube-system | grep dns | awk '{print $1}')
kubectl --kubeconfig $kubecfg delete pod $dns_pod -n kube-system

# Copy the join command to the shared folder for the worker nodes to use
grep "kubeadm join" kubeinit.log > /home/ubuntu/kube_join.sh

popd
