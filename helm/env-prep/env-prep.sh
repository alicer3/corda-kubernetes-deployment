#!/bin/bash

set -u
DIR="."

GetPathToCurrentlyExecutingScript () {
	# Absolute path of this script, e.g. /opt/corda/node/foo.sh
	set +e
	ABS_PATH=$(readlink -f "$0" 2>&1)
	if [ "$?" -ne "0" ]; then
		echo "Using macOS alternative to readlink -f command..."
		# Unfortunate MacOs issue with readlink functionality, see https://github.com/corda/corda-kubernetes-deployment/issues/4
		TARGET_FILE=$0

		cd $(dirname $TARGET_FILE)
		TARGET_FILE=$(basename $TARGET_FILE)
		ITERATIONS=0

		# Iterate down a (possible) chain of symlinks
		while [ -L "$TARGET_FILE" ]
		do
			TARGET_FILE=$(readlink $TARGET_FILE)
			cd $(dirname $TARGET_FILE)
			TARGET_FILE=$(basename $TARGET_FILE)
			ITERATIONS=$((ITERATIONS + 1))
			if [ "$ITERATIONS" -gt 1000 ]; then
				echo "symlink loop. Critical exit."
				exit 1
			fi
		done

		# Compute the canonicalized name by finding the physical path
		# for the directory we're in and appending the target file.
		PHYS_DIR=$(pwd -P)
		ABS_PATH=$PHYS_DIR/$TARGET_FILE
	fi

	# Absolute path of the directory this script is in, thus /opt/corda/node/
	DIR=$(dirname "$ABS_PATH")
}
GetPathToCurrentlyExecutingScript

. $DIR/../variables.sh

IngressSetup() {
  # add helm repo
  helm repo add jetstack https://charts.jetstack.io
  helm repo add stable https://kubernetes-charts.storage.googleapis.com/
  helm repo update

  # create public IP address
  createIPIfNotExist "$NAMESPACE-ingress-ip" "$NAMESPACE-ingress" # az network public-ip create -g $NODEPOOL_RG -n "$NAMESPACE-ingress-ip" --allocation-method Static --sku Standard
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
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$NAMESPACE-ingress"

  # install cert manager

  kubectl label namespace $CERT_NS cert-manager.io/disable-validation=true --overwrite=true
  # kill the process after 10min
  timeout -k 10 600 kubectl apply --validate=false -f $DIR/ingress/ #https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.crds.yaml

  helm install \
  --name cert-manager \
  --namespace $CERT_NS \
  --version v0.16.0 \
  jetstack/cert-manager

  # back to deployment namespace
  kubectl config set-context --current --namespace=$NAMESPACE

}

createIPIfNotExist() {
  IP_NAME=$1
  DNS_NAME=$2
  RESULT=$(az network public-ip list -g $NODEPOOL_RG --query "[?name=='$IP_NAME']")
  if [ $RESULT == "[]" ]; then
      az network public-ip create -g $NODEPOOL_RG -n $IP_NAME --dns-name $DNS_NAME --allocation-method Static --sku Standard
  fi
}

ELKSetup() {
  # create public IP for elasticsearch engine and Kibana.
  createIPIfNotExist "$NAMESPACE-elasticsearch-ip" "$NAMESPACE-elasticsearch"
  createIPIfNotExist "$NAMESPACE-kibana-ip" "$NAMESPACE-kibana"

  ES_IP=$(az network public-ip show -g $NODEPOOL_RG -n "$NAMESPACE-elasticsearch-ip" |grep ipAddress |cut -d '"' -f 4)
  KI_IP=$(az network public-ip show -g $NODEPOOL_RG -n "$NAMESPACE-kibana-ip" |grep ipAddress |cut -d '"' -f 4)

  kubectl create namespace $LOG_NS
  echo "  elasticsearchIP: \"$ES_IP\"
  kibanaIP: \"$KI_IP\"
  loggingNS: \"$LOG_NS\"
  " > $DIR/input.yaml

  helm template $DIR -f $DIR/input.yaml --output-dir $DIR/output
  rm $DIR/input.yaml
  kubectl apply -f $DIR/output/ELK/templates/ --namespace=$LOG_NS

}

createDockerSecret() {
    SERVER="{{.Values.config.containerRegistry.serverAddress}}"
    USERNAME="{{ .Values.config.containerRegistry.username }}"
    PASSWORD="{{ .Values.config.containerRegistry.password }}"
    EMAIL="{{ .Values.config.containerRegistry.email }}"

    kubectl create secret docker-registry --dry-run=true container-registry-secret \
    --docker-server=$SERVER \
    --docker-username=$USERNAME \
    --docker-password=$PASSWORD \
    --docker-email=$EMAIL \
    -o yaml > $DIR/docker-secret.yml

    kubectl apply -f $DIR/docker-secret.yml
}

main() {
read -p "Select the deployment:
  1) Ingress Setup
  2) ELK Setup
  3) Docker Secret Setup
  " selection
  echo $selection

  case $selection in
    "1") printf "Setting up Ingress..\n"
         IngressSetup
         ;;
    "2") printf "Setting up ELK..\n"
         ELKSetup
         ;;
    "3") printf "Create Docker Secret..\n"
         createDockerSecret
         ;;
    *) printf "illegal option"
        ;;
  esac
  exit 0
}

main