#!/bin/bash

# Create service account and role binding
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: vault
EOF

# Wait for service account to be created
sleep 2

# Get required information
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
SA_JWT_TOKEN=$(kubectl create token vault-auth -n vault)

# Save CA cert to file
echo "$KUBE_CA_CERT" > ca.crt

# Verify Vault status
vault status

# Login to Vault if needed
vault login root

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="$KUBE_HOST" \
    token_reviewer_jwt="$SA_JWT_TOKEN" \
    kubernetes_ca_cert=@ca.crt \
    issuer="https://kubernetes.default.svc.cluster.local"

# Verify the configuration
echo "Verifying configuration..."
vault read auth/kubernetes/config

# Clean up
rm ca.crt