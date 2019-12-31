#!/bin/bash 
kubecfg="--kubeconfig $1"

git clone https://github.com/rook/rook
pushd rook
git checkout -b v106 v1.0.6
cd cluster/examples/kubernetes/ceph/
kubectl $kubecfg apply -f common.yaml
kubectl $kubecfg apply -f operator.yaml
sed "s|#directories|directories|" -i cluster.yaml
sed "s|#- path: /var/lib/rook|- path: /var/lib/rook|" -i cluster.yaml
sed "s|# databaseSizeMB|databaseSizeMB|" -i cluster.yaml
sed "s|# journalSizeMB|journalSizeMB|" -i cluster.yaml
sed "s|# osdsPerDevice|osdsPerDevice|" -i cluster.yaml
kubectl $kubecfg apply -f cluster.yaml
kubectl $kubecfg apply -f object.yaml

# Wait for the rgw pod before creating object user
while [ $(kubectl $kubecfg -n rook-ceph get po | grep rook-ceph-rgw | grep Running | wc -l) -lt 1 ]
do
    echo "Waiting for rook-ceph-rgw pod..."
    sleep 5
done

kubectl $kubecfg apply -f object-user.yaml

while [ $(kubectl $kubecfg -n rook-ceph get secret rook-ceph-object-user-my-store-my-user | grep my-store-my-user | wc -l) -lt 1 ]
do
    echo "Waiting for the object user secret..." 
    sleep 5
done

# Copy the object store user secret into the default namespace
akey=$(kubectl $kubecfg -n rook-ceph get secret rook-ceph-object-user-my-store-my-user -o yaml | grep AccessKey | awk '{print $2}' | base64 --decode)
skey=$(kubectl $kubecfg -n rook-ceph get secret rook-ceph-object-user-my-store-my-user -o yaml | grep SecretKey | awk '{print $2}' | base64 --decode)
kubectl $kubecfg create secret generic rook-ceph-object-user-my-store-my-user --from-literal=AccessKey=${akey} --from-literal=SecretKey=${skey}

popd
