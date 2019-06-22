#!/bin/bash

# Run a background script which waits for the worker nodes to join then installs addons
kubecfg="/home/admin/.kube/config"
num_nodes=${node_count}
work_dir="/home/admin"

pushd $work_dir

cat <<EOF > install-addons.sh
#!/bin/bash

while [ \$(kubectl --kubeconfig $kubecfg get nodes | grep -v NotReady | grep Ready | wc -l) -lt $num_nodes ]
do
    echo Waiting for worker nodes...
    sleep 5
done

pushd $work_dir
git clone https://github.com/kgorcz/infra-k8s
cd infra-k8s
git checkout debian
cd addons

export EMAIL="${letsencrypt_email}"

for i in \$(ls *sh)
do
    addon_name=\$(echo \$i | awk -F '.' '{print \$1}')
    mkdir \$addon_name; mv \$i \$addon_name; chmod -R 777 \$addon_name; pushd \$addon_name
    ./\$i $kubecfg 2>&1 | tee \$addon_name.log
    popd
done

EOF

chmod +x install-addons.sh
./install-addons.sh > install-addons.log &

popd
