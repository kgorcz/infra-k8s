#!/bin/bash 
kubecfg="--kubeconfig $1"

git clone https://github.com/kgorcz/contour
cd contour
git checkout -b integ101 ebdf96bdf057baf579972d51a1dc638ea3dcefb1
cd examples/contour

sed "s|docker.io/projectcontour/contour:v1.0.1|quay.io/kgorcz/contour:v1.0.1|" -i 03-contour.yaml
sed "s|port: 80|port: 80\n    nodePort: 32323|" -i 02-service-envoy.yaml
sed "s|port: 443|port: 443\n    nodePort: 32324|" -i 02-service-envoy.yaml
sed "s|selector:|- port: 104\n    nodePort: 32325\n    name: dicom\n    protocol: TCP\n  selector:|" -i 02-service-envoy.yaml
sed "s|LoadBalancer|NodePort|" -i 02-service-envoy.yaml
cat 03-envoy.yaml | grep -v "hostPort" > 03-envoy-mod.yaml
rm 03-envoy.yaml
mv 03-envoy-mod.yaml 03-envoy.yaml

kubectl $kubecfg apply -f .
