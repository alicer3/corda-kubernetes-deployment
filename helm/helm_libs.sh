#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
Purple='\033[0;35m'
NC='\033[0m'

set -u

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

InitialRegistration() {
  INITIAL_REGISTRATION=""
	INITIAL_REGISTRATION=$(grep -A 3 'initialRegistration:' $DIR/values.yaml | grep 'enabled: ' | cut -d ':' -f 2 | xargs)

	if [ "$INITIAL_REGISTRATION" = "true" ]; then
		$DIR/initial_registration/initial_registration.sh
	else
		echo -e "${YELLOW}Warning${NC}"
		echo "Skipping initial registration step. (disabled in values.yaml)"
	fi
}

HelmCompilePrerequisites () {
	helm version | grep "v2." > /dev/null 2>&1
	if [ "$?" -ne "0" ] ; then
		echo -e "${RED}ERROR${NC}"
		echo "Helm version 2 has to be used for compiling these scripts. Please install it from https://github.com/helm/helm/releases"
		exit 1
	fi

	kubectl cluster-info > /dev/null 2>&1
	if [ "$?" -ne "0" ] ; then
		echo -e "${RED}ERROR${NC}"
		echo "kubectl must be connected to the Kubernetes cluster in order to continue. Please see https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/"
		exit 1
	fi

	set -eu

	if [ ! -f $DIR/files/network/networkRootTrustStore.jks ]; then
		echo -e "${RED}ERROR${NC}"
		echo "$DIR/files/networkRootTrustStore.jks missing, this should have been copied to this folder before running this script."
		exit 1
	fi

}

DeploymentPrerequisites() {
  RESOURCE_NAME=$1

  set -eu

	if [ ! -f $DIR/files/network/network-parameters.file ]; then
		echo -e "${RED}ERROR${NC}"
		echo "$DIR/files/network-parameters.file missing, this should have been created by InitialRegistration in helm_compile.sh."
		exit 1
	fi

	if [ ! -f $DIR/files/values/$RESOURCE_NAME.yaml ]; then
		echo -e "${RED}ERROR${NC}"
		echo "$DIR/files/values/$RESOURCE_NAME.yaml missing. It should have been created when deploying $RESOURCE_NAME for the first time."
		exit 1
	fi

	if [ ! -f $DIR/files/certificates/node/$RESOURCE_NAME/nodekeystore.jks -o ! -f $DIR/files/certificates/node/$RESOURCE_NAME/sslkeystore.jks -o ! -f $DIR/files/certificates/node/$RESOURCE_NAME/truststore.jks ]; then
		echo -e "${RED}ERROR${NC}"
		echo "$DIR/files/certificates/node/$RESOURCE_NAME missing certificates, expecting to see nodekeystore.jks, sslkeystore.jks and truststore.jks, these files should have been created by InitialRegistration in helm_compile.sh."
		echo "Files in folder $DIR/files/certificates/node:"
		ls -al $DIR/files/certificates/node/$RESOURCE_NAME
		exit 1
	fi

}

# check whether a folder exists with content
checkFolderStatus() {
  FOLDER=$1
  if [ -d $FOLDER ]; then
    if [ "$(ls -A $FOLDER)" ]; then
      return 0
    else
      echo -e "${YELLOW}WARNING${NC}"
      echo "$FOLDER is Empty!"
      return 1
    fi
  else
    echo -e "${YELLOW}WARNING${NC}"
    echo "$FOLDER does not exist!"
    return 1
  fi
}

# check whether springboot docker image of specific day exists. if not, build and push the iamge
checkDockerImageStatus() {
  DATE=$1

  ACR_NAME=$(grep -A 50 'config:' $DIR/values.yaml |grep -A 10 'containerRegistry:' |grep 'serverAddress:'| cut -d '"' -f 2 | cut -d '.' -f 1)
  RESULT=$(az acr repository show-tags -n $ACR_NAME --repository springboot --orderby time_desc --output table | grep $DATE)
  echo $RESULT
  if [ "$RESULT" = "" ]; then
    echo "Building springboot Image for $DATE..."
    . $DIR/../docker-images/handle_springboot_image.sh $DATE
  else
    echo "Springboot image :$DATE is available. Skipping image building."
  fi
}

# fetch node values and update the apiVersion and cordappVersion if a date argument is present
# handleValues $NODE $DATE(opt)
handleValues() {
  NODE=$1

  echo "$NODE: Handling values.yaml..."
  VALUES=$DIR/values.yaml
  BACKUP_VALUES=$DIR/files/values/$NODE.yaml
  if [ $# -eq 2 ]; then
    DATE=$2
    sed -i '' -e "s/.*apiVersion.*/  apiVersion: \"$DATE\"/" $BACKUP_VALUES
    sed -i '' -e "s/.*cordappVersion.*/  cordappVersion: \"$DATE\"/" $BACKUP_VALUES
  fi
  cp $BACKUP_VALUES $VALUES

  # compile template based on updated values.yaml
  echo "$NODE: Compiling helm templates..."
  TEMPLATE_NAMESPACE=$(grep -A 3 'config:' $VALUES | grep 'namespace: "' | cut -d '"' -f 2)
  helm template $DIR --name $TEMPLATE_NAMESPACE --namespace $TEMPLATE_NAMESPACE --output-dir $DIR/output

}

# upload cordapps and config in Azure fileshare
ReuploadCorDappsInFileShare () {
    SOURCE=$1

    ACCOUNT_KEY=$(grep -A 100 'config:' $DIR/values.yaml | grep 'azureStorageAccountKey: "' | cut -d '"' -f 2)
    ACCOUNT_NAME=$(grep -A 100 'config:' $DIR/values.yaml | grep 'azureStorageAccountName: "' | cut -d '"' -f 2)
    FILESHARE=$( grep -A 100 'config:' $DIR/values.yaml |grep -A 100 'storage:' |grep -A 10 'node:' |grep 'fileShareName: "' | cut -d '"' -f 2)
    az storage file delete-batch --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --pattern "cordapps/*.jar" --source $FILESHARE --dryrun

    echo "Clearing cordapps..."
    az storage file delete-batch --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --pattern "cordapps/*.jar" --source $FILESHARE
    echo "Done clearing cordapps"

    echo "Uploading cordapps..."
    az storage file upload-batch --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME \
    --destination "https://$ACCOUNT_NAME.file.core.windows.net/$FILESHARE" --source $SOURCE \
    --destination-path cordapps --pattern '*.jar'
    echo "Done uploading cordapps"

    if [ -d $SOURCE/config ]; then
      echo "Uploading cordapps config..."
      az storage file upload-batch --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME \
      --destination "https://$ACCOUNT_NAME.file.core.windows.net/$FILESHARE" --source $SOURCE/config \
      --destination-path cordapps/config --pattern '*'
      echo "Done uploading cordapps config"
    fi
}

# update the Corda node to the cordapp release of certain day
updateCordaNodeByDate() {
  DATE=$1
  NODE=$2
  CORDAPP_FOLDER=$DIR/files/cordapps/$DATE

  # delete existing node deployment
  echo "$NODE: Deleting node deployment..."
  kubectl delete pods,deployments,services,pvc,pv,secrets,storageclass -l group=$NODE,comp=node

  # replace the cordapps in fileshare
  ReuploadCorDappsInFileShare $CORDAPP_FOLDER

  echo "$NODE: Applying Corda node templates to Kubernetes cluster..."
  kubectl apply -f $DIR/output/corda/templates/deployment-CordaNode.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/secret-CordaNodeAzureFile.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/StorageClass.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/volume-CordaNode.yml --namespace=$TEMPLATE_NAMESPACE

}

updateSpringBootByDate() {
  DATE=$1
  NODE=$2

  # delete existing springboot deployment
  echo "$NODE: Deleting existing springboot deployment..."
  kubectl delete pods,deployments,services,ingress -l group=$NODE,comp=springboot

  echo "$NODE: Applying springboot templates to Kubernetes cluster..."
  kubectl apply -f $DIR/output/corda/templates/deployment-springboot.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/Ingress.yml --namespace=$TEMPLATE_NAMESPACE

}
