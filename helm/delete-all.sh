#!/bin/bash

set -eu
DIR="."
RESOURCE_GROUP="KubernetesPlayground-NodePool"
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
  # seperate node, db, sprintboot
  RESOURCE_NAME=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)

	kubectl delete jobs,pods,services,deployments,statefulsets,configmaps,svc,pvc,pv,secrets,storageclass -l group=$RESOURCE_NAME --wait=false

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

#  echo "!!! Deleting fileshare will delete all the logs
#  If you are sure to delete the fileshare, please type 'yes' and press enter."
#  read -p "Enter 'yes' to continue: " confirm
#  echo $confirm
#  if [ "$confirm" = "yes" ]; then
    az storage share delete --account-name $ACCOUNT_NAME \
        --account-key $ACCOUNT_KEY \
        --name $FILESHARE
#  fi

  az network public-ip delete -g $RESOURCE_GROUP -n "$FILESHARE-ip"
  az network public-ip delete -g $RESOURCE_GROUP -n "$FILESHARE-database-ip"
  echo "====== Deleting Azure resources in $FILESHARE completed. ======"
}

main() {
  DeleteResourceNameKubernetesResources
  sleep 30
  DeleteAzureResources
}

main
