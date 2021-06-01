#!/bin/bash
kubecfg="--kubeconfig $1"

# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-quickstart.html
wget https://download.elastic.co/downloads/eck/0.8.1/all-in-one.yaml

kubectl $kubecfg apply -f all-in-one.yaml

cat <<EOF > escluster.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1alpha1
kind: Elasticsearch
metadata:
  name: elasticsearch-logging
spec:
  version: 7.1.0
  nodes:
  - nodeCount: 1
    config:
      node.master: true
      node.data: true
      node.ingest: true
EOF

while true; do if [ $(kubectl $kubecfg get crd | grep elasticsearches | wc -l) -eq "1" ]; then break; fi; date; sleep 3; done

kubectl $kubecfg apply -f escluster.yaml

while true; do if [ $(kubectl $kubecfg get elasticsearch | grep green | wc -l) -eq "1" ]; then break; fi; date; sleep 3; done

PASSWORD=$(kubectl $kubecfg get secret elasticsearch-logging-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode)

cat <<EOF > kibana.yaml
apiVersion: kibana.k8s.elastic.co/v1alpha1
kind: Kibana
metadata:
  name: elasticsearch-logging
spec:
  version: 7.1.0
  nodeCount: 1
  elasticsearchRef:
    name: elasticsearch-logging
EOF

kubectl $kubecfg apply -f kibana.yaml

git clone https://github.com/fluent/fluentd-kubernetes-daemonset
cd fluentd-kubernetes-daemonset/
git checkout -b v1 af32a7336e99df5188ac79541074b8ba357025c5
sed "s|fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch|fluent/fluentd-kubernetes-daemonset:v1.12-debian-elasticsearch7-1|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "s|elasticsearch-logging|elasticsearch-logging-es.default|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "s|changeme|$PASSWORD|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "/.*ELASTICSEARCH_SCHEME/ { n; s/http/https/ }" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "/.*SSL_VERIFY/ { n; s/true/false/ }" -i fluentd-daemonset-elasticsearch-rbac.yaml

kubectl $kubecfg apply -f fluentd-daemonset-elasticsearch-rbac.yaml

# kc get secret elasticsearch-logging-elastic-user -o yaml | grep -C 1 ^data: | grep elastic | awk '{print $2}' | base64 -d
# kc port-forward svc/elasticsearch-logging-kibana --address 0.0.0.0 5601:5601
# https://github.com/fluent/fluentd-kubernetes-daemonset/issues/434#issuecomment-831801690
