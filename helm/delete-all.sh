#!/bin/bash

set -eu
DIR="."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
Purple='\033[0;35m'
NC='\033[0m'

. $DIR/variables.sh

DeleteAllKubernetesResources () {
	echo "====== Deleting all Kubernetes resources next ... ====== "
	kubectl delete --all jobs --wait=false
	kubectl delete --all pods --wait=false
	kubectl delete --all services --wait=false
	kubectl delete --all deployments --wait=false
	kubectl delete --all statefulsets --wait=false
	kubectl delete --all configmaps --wait=false
	kubectl delete --all svc --wait=false
	kubectl delete --all pvc --wait=false
	kubectl delete --all pv --wait=false
	kubectl delete --all secrets --wait=false
	kubectl delete --all storageclass --wait=false
	kubectl delete --all ingress --wait=false

	while :; do
		n=$(kubectl get pods | wc -l)
		if [[ n -eq 0 ]]; then
			break
		fi
		sleep 5
	done
	echo "====== Deleting all Kubernetes resources completed. ====== "
}

DeleteResourceNameKubernetesResources () {
  # seperate node, db, springboot
  RESOURCE_NAME=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)

	kubectl delete jobs,pods,services,deployments,statefulsets,configmaps,svc,pvc,pv,secrets,storageclass,ingress -l group=$RESOURCE_NAME --wait=false

	while :; do
		n=$(kubectl get pods -l node=$RESOURCE_NAME | wc -l)
		if [[ n -eq 0 ]]; then
			break
		fi
		sleep 5
	done
	echo "====== Deleting Kubernetes resources in $RESOURCE_NAME completed. ====== "
}

DeleteAzureResources() {
  # delete fileshare!!!, public IP
  FILESHARE=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)
  ACCOUNT_KEY=$(grep -A 100 'config:' $DIR/values.yaml | grep 'azureStorageAccountKey: "' | cut -d '"' -f 2)
  ACCOUNT_NAME=$(grep -A 100 'config:' $DIR/values.yaml | grep 'azureStorageAccountName: "' | cut -d '"' -f 2)
  RESOURCE_GROUP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'nodepoolResourceGroup: "' | cut -d '"' -f 2)

  az storage share delete --account-name $ACCOUNT_NAME \
      --account-key $ACCOUNT_KEY \
      --name $FILESHARE

  az network public-ip delete -g $RESOURCE_GROUP -n "$FILESHARE-$ENV-ip"
  az network public-ip delete -g $RESOURCE_GROUP -n "$FILESHARE-$ENV-database-ip"
  echo "====== Deleting Azure resources in $FILESHARE completed. ======"
}

DeleteIngressResource() {
  helm del --purge nginx-ingress
  helm del --purge cert-manager

  # kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.crds.yaml --namespace $CERT_NS
  kubectl delete -f $DIR/env-prep/ingress/cert-manager.crds.yaml --namespace $CERT_NS
  kubectl delete namespace $CERT_NS
  az network public-ip delete -g $NODEPOOL_RG -n "$NAMESPACE-ingress-ip"

}

DeleteELKResource() {
  kubectl delete --all pods,deployments,services --namespace $LOG_NS
  kubectl delete namespace $LOG_NS
#  az network public-ip delete -g $NODEPOOL_RG -n "$NAMESPACE-elasticsearch-ip"
#  az network public-ip delete -g $NODEPOOL_RG -n "$NAMESPACE-kibana-ip"

}

main() {
  RESOURCE_NAME=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)
  printf "${RED}!!!NOTE: the deletion cannot be undone!!!${NC}\n"
  read -p "Select the resources you want to delete:
  1) kubernetes resources for $RESOURCE_NAME in $NAMESPACE
  2) Azure resources for $RESOURCE_NAME in $NAMESPACE
  3) 1+2
  4) Ingress kubernetes and Azure resources
  5) ELK kubernetes and Azure resources
  6) all kubernetes resources in the $NAMESPACE
  " selection
  echo $selection

  read -p  "Please repeat the choice to confirm: " choice
  echo $choice

  if [ $selection != $choice ]; then
    printf "${RED}Choice Mismatch. Exiting...${NC}\n"
    exit 1
  fi

  case $selection in
    "1") printf "${YELLOW}Deleting kubernetes resources for $RESOURCE_NAME in $NAMESPACE..${NC}\n"
         DeleteResourceNameKubernetesResources
         ;;
    "2") printf "${YELLOW}Deleting Azure resources for $RESOURCE_NAME in $NAMESPACE..${NC}\n"
         DeleteAzureResources
         ;;
    "3") printf "${YELLOW}Deleting Azure resources for $RESOURCE_NAME in $NAMESPACE..${NC}\n"
         DeleteResourceNameKubernetesResources
         Sleep 30
         DeleteAzureResources
         ;;
    "4") printf "${YELLOW}Deleting Ingress kubernetes resources..${NC}\n"
         DeleteIngressResource
         ;;
    "5") printf "${YELLOW}Deleting ELK kubernetes resources ..${NC}\n"
         DeleteELKResource
         ;;
    "6") printf "${YELLOW}Deleting all kubernetes resources in $NAMESPACE..${NC}\n"
         DeleteAllKubernetesResources
         ;;
    *) printf "illegal option"
        ;;
  esac
  exit 0
}
main