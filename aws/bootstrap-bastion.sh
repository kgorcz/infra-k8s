#!/bin/bash

TELEPORT_VERSION=v3.2.4

pushd /home/admin

wget https://get.gravitational.com/teleport-$TELEPORT_VERSION-linux-amd64-bin.tar.gz
tar -xzf teleport-$TELEPORT_VERSION-linux-amd64-bin.tar.gz

pushd teleport/
./install
mkdir -p /var/lib/teleport
popd

cp teleport/examples/systemd/teleport.service /etc/systemd/system
systemctl daemon-reload
systemctl enable teleport
systemctl start teleport

sleep 15

tctl nodes add > teleport_add.sh
cat teleport_add.sh | grep "start\|\-\-" | cut -b 1 --complement > teleport_join.sh
cp teleport_join.sh /home/bootport/teleport_join.sh
chown bootport:bootport /home/bootport/*

# sudo tctl users add $USER
