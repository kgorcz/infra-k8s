#!/usr/bin/env bash

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key ubuntu@${master_ip}:/etc/ssh/ssh_host_rsa_key.pub ./master_rsa.pub
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key ubuntu@${master_ip}:/etc/ssh/ssh_host_rsa_key.pub ./master_rsa.pub
done
cat ./master_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

KUBERNETES_VERSION=1.9.0-00

# Add kubernetes apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install docker and kubernetes
apt-get update
apt-get install -y docker.io
apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION

# Join the cluster
pushd /home/ubuntu
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key ubuntu@${master_ip}:/home/ubuntu/kube_join.sh .
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key ubuntu@${master_ip}:/home/ubuntu/kube_join.sh .
done
chmod +x kube_join.sh
./kube_join.sh
popd
