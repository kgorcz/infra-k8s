#!/bin/bash 
kubecfg="--kubeconfig $1"

wget https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml
kubectl $kubecfg apply -f cert-manager.yaml

cat <<EOF > letsencrypt-staging.yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
   acme:
     # The ACME server URL
     server: https://acme-staging-v02.api.letsencrypt.org/directory
     # Email address used for ACME registration
     email: ${EMAIL}
     # Name of a secret used to store the ACME account private key
     privateKeySecretRef:
       name: letsencrypt-staging
     # Enable the HTTP-01 challenge provider
     solvers:
     - http01:
        ingress:
          class: contour
EOF

kubectl $kubecfg apply -f letsencrypt-staging.yaml
while [ $? -ne 0 ]
do
    sleep 20
    echo "Retrying lets encrypt staging issuer..."
    kubectl $kubecfg apply -f letsencrypt-staging.yaml
done

cat <<EOF > letsencrypt-prod.yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: ${EMAIL}
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    # An empty 'selector' means that this solver matches all domains
    - http01:
       ingress:
         class: contour
EOF

