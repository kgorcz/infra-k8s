#!/usr/bin/env bash

KUBERNETES_VERSION=1.11.4-00
DOCKER_VERSION=17.12.1~ce-0~debian

# Add master to list of authorized_keys
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key admin@${master_ip}:/etc/ssh/ssh_host_rsa_key.pub ./master_rsa.pub
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key admin@${master_ip}:/etc/ssh/ssh_host_rsa_key.pub ./master_rsa.pub
done
cat ./master_rsa.pub >> /home/admin/.ssh/authorized_keys

# Add kubernetes apt repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install docker and kubernetes
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce=$DOCKER_VERSION
apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION

systemctl enable docker

# Join the cluster
pushd /home/admin
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key admin@${master_ip}:/home/admin/kube_join.sh .
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /etc/ssh/ssh_host_rsa_key admin@${master_ip}:/home/admin/kube_join.sh .
done
chmod +x kube_join.sh
./kube_join.sh
popd
