#!/bin/bash

set -eu
DIR="."

# node static IP and DB static IP will be automatically retrieved after public IP addresses created
NODEIP=""
DBIP=""

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

prepareFileShareAndPublicIP() {
  FILESHARE=$PREFIX

  echo "Creating fileshare..."
  az storage share create \
      --account-name $ASA_NAME \
      --account-key $ASA_KEY \
      --name $FILESHARE \
      --quota 2 --output none

  echo "Creating drivers directory in fileshare..."
  az storage directory create \
  --account-key $ASA_KEY --account-name $ASA_NAME\
  --share-name $FILESHARE \
  --name "drivers" \
  --output none

  echo "Uploading drivers..."
  az storage file upload --account-key $ASA_KEY --account-name $ASA_NAME --path drivers --share-name $FILESHARE --source $DIR/../../docker-images/bin/db_drivers/postgresql-42.2.14.jar

  echo "Creating cordapp directory in fileshare..."
  az storage directory create \
  --account-key $ASA_KEY --account-name $ASA_NAME\
  --share-name $FILESHARE \
  --name "cordapps" \
  --output none

    az storage directory create \
  --account-key $ASA_KEY --account-name $ASA_NAME\
  --share-name $FILESHARE \
  --name "cordapps/config" \
  --output none

  echo "Creating public IP for node, DB..."
  az network public-ip create -g $NODEPOOL_RG -n "$PREFIX-$ENV-ip" --dns-name "$PREFIX-$ENV-ip" --allocation-method Static --sku Standard
  az network public-ip create -g $NODEPOOL_RG -n "$PREFIX-$ENV-database-ip" --dns-name "$PREFIX-$ENV-database-ip" --allocation-method Static --sku Standard

}

prepareFileShareAndPublicIP

# define variables -> create azure resources -> retrieve IPs -> generate values.yaml
generateValuesYml() {

  NODEIP=$(az network public-ip show -g $NODEPOOL_RG -n "$PREFIX-$ENV-ip" |grep ipAddress |cut -d '"' -f 4)
  DBIP=$(az network public-ip show -g $NODEPOOL_RG -n "$PREFIX-$ENV-database-ip" |grep ipAddress |cut -d '"' -f 4)
  INGRESS_IP=$(az network public-ip show -g $NODEPOOL_RG -n "$NAMESPACE-ingress-ip" |grep ipAddress |cut -d '"' -f 4)
  echo "node public IP = $NODEIP"
  echo "node db public IP = $DBIP"
  echo "ingress public IP = $INGRESS_IP"

  echo "  fileshare: \"$PREFIX\"
  nodePublicIP: \"$NODEIP\"
  databasePublicIP: \"$DBIP\"
  sbPublicIP: \"$INGRESS_IP\"
  sbaddress: \"$NAMESPACE-ingress.uksouth.cloudapp.azure.com\"
  resourceName: \"$PREFIX\"
  storageResourceName: \"$PREFIX-storage\"
  p2paddress: \"$PREFIX-$ENV-ip.uksouth.cloudapp.azure.com\"
  dbaddress: \"$PREFIX-$ENV-database-ip.uksouth.cloudapp.azure.com\"
  x500Name: \"$X500NAME\"
  cordappVersion: \"$CORDAPP_VERSION\"
  apiVersion: \"$APIVERSION\"
  namespace: \"$NAMESPACE\"
  env: \"$ENV\"
  acraddress: \"$ACR_ADDRESS\"
  acrusername: \"$ACR_USERNAME\"
  acrpassword: \"$ACR_USERNAME\"
  nodepoolrg: \"$NODEPOOL_RG\"
  storageAccountName: \"$ASA_NAME\"
  storageAccountKey: \"$ASA_KEY\"
  identityManagerURL: \"$IM_ADDRESS\"
  networkMapURL: \"$NM_ADDRESS\"
  networkTruststorePass: \"$NETWORK_TRUSTSTORE_PASSWORD\"
  " > $DIR/input.yaml

  helm template $DIR -f $DIR/input.yaml --output-dir $DIR/output

  cp $DIR/output/corda/templates/values-template.yml $DIR/../files/values/$PREFIX.yaml
  cp $DIR/output/corda/templates/values-template.yml $DIR/../values.yaml

  rm $DIR/input.yaml
}

generateValuesYml
