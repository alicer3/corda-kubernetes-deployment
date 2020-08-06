#!/bin/bash

set -u
DIR="."

. $DIR/variables.sh

IngressSetup() {
  # add helm repo
  helm repo add jetstack https://charts.jetstack.io
  helm repo add stable https://kubernetes-charts.storage.googleapis.com/
  helm repo update

  # create public IP address
  az network public-ip create -g $NODEPOOL_RG -n "$NAMESPACE-ingress-ip" --allocation-method Static --sku Standard
  LBIP=$(az network public-ip show -g $NODEPOOL_RG -n "$NAMESPACE-ingress-ip" |grep ipAddress |cut -d '"' -f 4)
  kubectl create namespace $CERT_NS
  kubectl config set-context --current --namespace=$CERT_NS

  # install nginx ingress controller (per app)
  helm install --name nginx-ingress stable/nginx-ingress \
    --namespace $CERT_NS \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.service.loadBalancerIP="$LBIP" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$NAMESPACE-ip"

  # install cert manager

  kubectl label namespace $CERT_NS cert-manager.io/disable-validation=true
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.crds.yaml

  helm install \
  --name cert-manager \
  --namespace $CERT_NS \
  --version v0.16.0 \
  jetstack/cert-manager

  # back to deployment namespace
  kubectl config set-context --current --namespace=$NAMESPACE

}

IngressSetup