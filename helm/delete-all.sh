#!/bin/bash

set -eu
DIR="."
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
  RESOURCE_NAME=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)

	kubectl delete jobs,pods,services,deployments,statefulsets,configmaps,svc,pvc,pv -l group=$RESOURCE_NAME --wait=false

	while :; do
		n=$(kubectl get pods -l node=$RESOURCE_NAME | wc -l)
		if [[ n -eq 0 ]]; then
			break
		fi
		sleep 5
	done
	echo "====== Deleting Kubernetes resources in $RESOURCE_NAME completed. ====== "
}

main() {
  DeleteAllKubernetesResources
}

main
