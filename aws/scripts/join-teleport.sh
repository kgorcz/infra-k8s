#!/bin/bash

TELEPORT_VERSION=v3.2.4

pushd /home/admin

wget -nv https://get.gravitational.com/teleport-$TELEPORT_VERSION-linux-amd64-bin.tar.gz
tar -xzf teleport-$TELEPORT_VERSION-linux-amd64-bin.tar.gz

pushd teleport/
./install
mkdir -p /var/lib/teleport
popd

BOOTPORT_KEY=/etc/ssh/id_rsa_bootport

# Join the teleport cluster
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTPORT_KEY bootport@${bastion_ip}:/home/bootport/teleport_join.sh .
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying first contact with master..."
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $BOOTPORT_KEY bootport@${bastion_ip}:/home/bootport/teleport_join.sh .
done
chmod +x teleport_join.sh
./teleport_join.sh &

popd