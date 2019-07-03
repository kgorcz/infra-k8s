#!/bin/bash
kubecfg="--kubeconfig $1"

wget https://download.elastic.co/downloads/eck/0.8.1/all-in-one.yaml

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

# v1.4.2-debian-elasticsearch-1.0

git clone https://github.com/fluent/fluentd-kubernetes-daemonset
cd fluentd-kubernetes-daemonset/
sed "s|fluentd-kubernetes-daemonset:elasticsearch|fluentd-kubernetes-daemonset:v1.4.2-debian-elasticsearch-1.0|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "s|elasticsearch-logging|elasticsearch-logging-es.default|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "s|http|https|" -i fluentd-daemonset-elasticsearch-rbac.yaml
sed "s|changeme\"|$PASSWORD\"\n          - name: FLUENT_ELASTICSEARCH_SSL_VERIFY\n            value: \"false\"\n          - name: FLUENT_ELASTICSEARCH_SSL_VERSION\n            value: \"TLSv1_2\"|" -i fluentd-daemonset-elasticsearch-rbac.yaml