#!/bin/bash

set -eu
DIR="."

PREFIX="alice-guo-node-4"
X500NAME="O=K8s Alice Node4,L=London,C=GB"

# node static IP and DB static IP will be automatically retrieved after public IP addresses created
NODEIP=""
DBIP=""

# the resource group of kubenetes node pool
RESOURCE_GROUP="KubernetesPlayground-NodePool"

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

prepareFileShareAndPublicIP() {
  ACCOUNT_KEY=$(grep -A 100 'config:' $DIR/templates/values-template.yml | grep 'azureStorageAccountKey: "' | cut -d '"' -f 2)
  ACCOUNT_NAME=$(grep -A 100 'config:' $DIR/templates/values-template.yml | grep 'azureStorageAccountName: "' | cut -d '"' -f 2)
  FILESHARE=$PREFIX

  echo "Creating fileshare..."
  az storage share create \
      --account-name $ACCOUNT_NAME \
      --account-key $ACCOUNT_KEY \
      --name $FILESHARE \
      --quota 2 --output none

  echo "Creating drivers directory in fileshare..."
  az storage directory create \
  --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME\
  --share-name $FILESHARE \
  --name "drivers" \
  --output none

  echo "Uploading drivers..."
  az storage file upload --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --path drivers --share-name $FILESHARE --source $DIR/../../docker-images/bin/db_drivers/postgresql-42.2.14.jar

  echo "Creating cordapp directory in fileshare..."
  az storage directory create \
  --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME\
  --share-name $FILESHARE \
  --name "cordapps" \
  --output none

  echo "Uploading cordapps..."
  az storage file upload-batch --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME \
  --destination "https://$ACCOUNT_NAME.file.core.windows.net/$FILESHARE" --source $DIR/../files/cordapps/ \
  --destination-path cordapps --pattern '*.jar'


  echo "Creating public IP for node and DB..."
  az network public-ip create -g $RESOURCE_GROUP -n "$PREFIX-ip" --dns-name "$PREFIX-ip" --allocation-method Static --sku Basic
  az network public-ip create -g $RESOURCE_GROUP -n "$PREFIX-database-ip" --dns-name "$PREFIX-database-ip" --allocation-method Static --sku Basic

}

prepareFileShareAndPublicIP

# define variables -> create azure resources -> retrieve IPs -> generate values.yaml
generateValuesYml() {

  NODEIP=$(az network public-ip show -g $RESOURCE_GROUP -n "$PREFIX-ip" |grep ipAddress |cut -d '"' -f 4)
  DBIP=$(az network public-ip show -g $RESOURCE_GROUP -n "$PREFIX-database-ip" |grep ipAddress |cut -d '"' -f 4)
  echo "node public IP = $NODEIP"
  echo "node db public IP = $DBIP"

  echo "  fileshare: \"$PREFIX\"
  nodePublicIP: \"$NODEIP\"
  databasePublicIP: \"$DBIP\"
  resourceName: \"$PREFIX\"
  storageResourceName: \"$PREFIX-storage\"
  p2paddress: \"$PREFIX-ip.uksouth.cloudapp.azure.com\"
  dbaddress: \"$PREFIX-database-ip.uksouth.cloudapp.azure.com\"
  x500Name: \"$X500NAME\"" > $DIR/input.yaml

  helm template $DIR -f $DIR/input.yaml --output-dir $DIR/output

  cp $DIR/output/corda/templates/values-template.yml $DIR/../files/values/$PREFIX.yaml
  cp $DIR/output/corda/templates/values-template.yml $DIR/../values.yaml
}

generateValuesYml
