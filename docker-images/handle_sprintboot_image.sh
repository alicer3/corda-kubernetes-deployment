#!/bin/bash

RED='\033[0;31m' # Error color
YELLOW='\033[0;33m' # Warning color
NC='\033[0m' # No Color

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
set -eu

NO_CACHE=
if [ "${1-}" = "no-cache" ]
then
	NO_CACHE=--no-cache
fi 

. $DIR/docker_config.sh

BuildDockerImages () {

  echo "Building Sprintboot Docker image..."
  echo "cp $DIR/bin/sprintboot/$SPRINTBOOT_API_VERSION.jar $DIR/$SPRINTBOOT_PATH/api.jar"
  cp $DIR/bin/sprintboot/$SPRINTBOOT_API_VERSION.jar $DIR/$SPRINTBOOT_PATH/api.jar
  echo "cd $DIR/$SPRINTBOOT_PATH"
  cd $DIR/$SPRINTBOOT_PATH
  echo "$DOCKER_CMD build -t $SPRINTBOOT_PATH:$SPRINTBOOT_IMAGE_VERSION . -f Dockerfile $NO_CACHE"
  $DOCKER_CMD build -t $SPRINTBOOT_PATH:$SPRINTBOOT_IMAGE_VERSION . -f Dockerfile $NO_CACHE
  rm api.jar

	echo "Listing all images starting with name 'sprintboot_' :"
	$DOCKER_CMD images "sprintboot*"
	echo "====== Building Sprintboot Docker images completed. ====== "
}
BuildDockerImages

PushDockerImages () {
	echo "====== Pushing Docker images next ... ====== "
	if [ "$DOCKER_REGISTRY" = "" ]; then
		echo -e "${RED}ERROR${NC}"
		echo "You must specify a valid container registry in the values.yaml file"
		exit 1
	fi

	echo "Logging in to Docker registry..."
	$DOCKER_CMD login $DOCKER_REGISTRY --username $DOCKER_USER --password $DOCKER_PASSWORD

	echo "Tagging Docker images..."
  $DOCKER_CMD tag ${SPRINTBOOT_PATH}:$SPRINTBOOT_IMAGE_VERSION $DOCKER_REGISTRY/${SPRINTBOOT_PATH}_$API_VERSION:$SPRINTBOOT_IMAGE_VERSION

	echo "Pushing Docker images to Docker repository..."
	SPRINTBOOT_DOCKER_REGISTRY=$(echo $DOCKER_REGISTRY/${SPRINTBOOT_PATH}_$API_VERSION:$SPRINTBOOT_IMAGE_VERSION 2>&1 | tr '[:upper:]' '[:lower:]')
	$DOCKER_CMD push $SPRINTBOOT_DOCKER_REGISTRY
	echo "====== Pushing Docker images completed. ====== "
}
PushDockerImages