#!/bin/bash
set -ex
kubectl delete po --ignore-not-found=true fleetcommand-agent-install
kubectl create secret \
  docker-registry \
  -o yaml --dry-run \
  --docker-server=quay.io \
  --docker-username="domino+netapp_fsx" \
  --docker-password="DC675XRVV3RRK5D71LFCAD83E25T3ZXX16OCASH70MH604N2NCES0A85IS88R9QF" \
  --docker-email=. domino-quay-repos | kubectl apply -f -
kubectl create configmap \
  fleetcommand-agent-config \
  -o yaml --dry-run \
  --from-file=domino-new.yml | kubectl apply -f -
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: fleetcommand-agent-install
spec:
  serviceAccountName: admin
  imagePullSecrets:
    - name: domino-quay-repos
  restartPolicy: Never
  containers:
  - name: fleetcommand-agent
    image: quay.io/domino/fleetcommand-agent:v56
    args: ["run", "-f", "/app/install/domino-new.yml", "-v"]
    imagePullPolicy: Always
    volumeMounts:
    - name: install-config
      mountPath: /app/install/
  volumes:
  - name: install-config
    configMap:
      name: fleetcommand-agent-config
EOF
set +e
while true; do
  sleep 5
  if kubectl logs -f fleetcommand-agent-install; then
break fi
done