#!/usr/bin/env bash

BOOTK8S_KEY=/etc/ssh/id_rsa_bootk8s

apt-get update

# Add master to list of authorized_keys
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTK8S_KEY bootk8s@${master_ip}:/home/bootk8s/ssh_host_rsa_key.pub ./master_rsa.pub
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTK8S_KEY bootk8s@${master_ip}:/home/bootk8s/ssh_host_rsa_key.pub ./master_rsa.pub
done
cat ./master_rsa.pub >> /home/admin/.ssh/authorized_keys

# Join the cluster
pushd /home/admin
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTK8S_KEY bootk8s@${master_ip}:/home/bootk8s/kube_join.sh .
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTK8S_KEY bootk8s@${master_ip}:/home/bootk8s/kube_join.sh .
done
chmod +x kube_join.sh
./kube_join.sh
popd
