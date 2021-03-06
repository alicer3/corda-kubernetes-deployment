#!/bin/bash

RED='\033[0;31m' # Error color
YELLOW='\033[0;33m' # Warning color
NC='\033[0m' # No Color

set -u
DIR="."

GetPathToCurrentlyExecutingScript () {
	SCRIPT_SRC=""
	set +u
	if [ "$BASH_SOURCE" = "" ]; then SCRIPT_SRC=""; else SCRIPT_SRC="${BASH_SOURCE[0]}"; fi
	if [ "$SCRIPT_SRC" = "" ]; then SCRIPT_SRC=$0; fi
	set -u
	
	# Absolute path of this script, e.g. /opt/corda/node/foo.sh
	set +e
	ABS_PATH=$(readlink -f "${SCRIPT_SRC}" 2>&1)
	if [ "$?" -ne "0" ]; then
		echo "Using macOS alternative to readlink -f command..."
		# Unfortunate MacOs issue with readlink functionality, see https://github.com/corda/corda-kubernetes-deployment/issues/4
		TARGET_FILE=$SCRIPT_SRC

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
set -eu

. $DIR/../helm/variables.sh

DOCKER_CMD='docker'
EnsureDockerIsAvailableAndReachable () {
	# Make sure Docker is ready
	set +e
	$DOCKER_CMD ps > /dev/null 2>&1
	status=$?
	if [ $status -eq 0 ]
	then
		echo "Docker is available and reachable..."
	else
		$DOCKER_CMD ps 2>&1 | grep -q "permission denied"
		status=$?
		if [ $status -eq 0 ]; then 
			echo -e "${YELLOW}Warning${NC}"
			echo "Docker requires sudo to execute, trying to substitute using 'sudo docker'"
			DOCKER_CMD='sudo docker'
			$DOCKER_CMD ps 2>&1 | grep -q "permission denied"
			status=$?
			if [ $status -eq 0 ]; then 
				echo -e "${RED}ERROR${NC}"
				echo "Still issues with permissions, try a manual workaround where you set 'alias docker='sudo docker'' then run 'docker ps' to check that there is no 'permission denied' errors."
				exit 1
			else
				echo "Docker now accessible by way of sudo, continuing..."
			fi
		else
			echo -e "${RED}ERROR${NC}"
			echo "!!! Docker engine not available, make sure your Docker is running and responds to command 'docker ps' !!!"
			exit 1
		fi
	fi
	set -e
}
EnsureDockerIsAvailableAndReachable

DOCKER_REGISTRY=$ACR_ADDRESS
DOCKER_USER=$ACR_USERNAME
DOCKER_PASSWORD=$ACR_PASSWORD

VERSION=""
VERSION=$(grep 'cordaVersion:' $DIR/../helm/values/templates/values-template.yml | cut -d '"' -f 2 | tr '[:upper:]' '[:lower:]')
HEALTH_CHECK_VERSION=$VERSION
#API_IMAGE=$(grep -A 10 'apiconfig:' $DIR/../helm/values.yaml | grep 'dockerImagespringboot: "' | cut -d '"' -f 2)


CORDA_VERSION="corda-ent-$VERSION"
CORDA_IMAGE_PATH="corda_image_ent"
CORDA_DOCKER_IMAGE_VERSION="v1.00"

#SPRINGBOOT_API_VERSION="api-$APIVERSION"
SPRINGBOOT_PATH="springboot"
#SPRINGBOOT_IMAGE_VERSION="v1.00"

CORDA_HEALTH_CHECK_VERSION="corda-tools-health-survey-$HEALTH_CHECK_VERSION"
