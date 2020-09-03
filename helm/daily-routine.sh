#!/bin/bash

set -eu
DIR="."

. ./helm_libs.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
Purple='\033[0;35m'
NC='\033[0m'

GetPathToCurrentlyExecutingScript

today=`date "+%Y%m%d"`
LOG_PATH="$DIR/logs/daily-routine/$today.log"

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

# update the Corda node to the cordapp release of certain day
updateCordaNodeByDate() {
  DATE=$1
  NODE=$2
  CORDAPP_FOLDER=$DIR/files/cordapps/$DATE

  # delete existing node deployment
  log "Deleting node deployment..." $LOG_PATH
  kubectl delete pods,deployments,services,pvc,pv,secrets,storageclass -l group=$NODE,comp=node

  # replace the cordapps in fileshare
  ReuploadCorDappsInFileShare $CORDAPP_FOLDER

  log "Applying Corda node templates to Kubernetes cluster:" $LOG_PATH
  kubectl apply -f $DIR/output/corda/templates/deployment-CordaNode.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/secret-CordaNodeAzureFile.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/StorageClass.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/volume-CordaNode.yml --namespace=$TEMPLATE_NAMESPACE

}

# check whether springboot docker image of specific day exists. if not, build and push the iamge
checkDockerImageStatus() {
  DATE=$1

  ACR_NAME=$(grep -A 50 'config:' $DIR/values.yaml |grep -A 10 'containerRegistry:' |grep 'serverAddress:'| cut -d '"' -f 2 | cut -d '.' -f 1)
  RESULT=$(az acr repository show-tags -n $ACR_NAME --repository springboot --orderby time_desc --output table | grep $DATE)
  echo $RESULT
  if [ "$RESULT" = "" ]; then
    log "Building springboot Image for $DATE..." $LOG_PATH
    . $DIR/../docker-images/handle_springboot_image.sh $DATE
    GetPathToCurrentlyExecutingScript
  else
    log "springboot image :$DATE is available. Skipping image building." $LOG_PATH
  fi
}

updateSpringBootByDate() {
  DATE=$1
  NODE=$2

  # delete existing springboot deployment
  log "Deleting existing springboot deployment..." $LOG_PATH
  kubectl delete pods,deployments,services,ingress -l group=$NODE,comp=springboot

  log "Applying springboot templates to Kubernetes cluster:" $LOG_PATH
  kubectl apply -f $DIR/output/corda/templates/deployment-springboot.yml --namespace=$TEMPLATE_NAMESPACE
  kubectl apply -f $DIR/output/corda/templates/Ingress.yml --namespace=$TEMPLATE_NAMESPACE

}

updateNodeByDate() {
  DATE=$1
  NODE=$2
  UPDATENODE=$3
  UPDATESPRINGBOOT=$4

  if [ $UPDATENODE -eq 1 -a $UPDATESPRINGBOOT -eq 1 ]; then
    log "No update will be performed." $LOG_PATH
  else
    # fetch the values.yaml from backup
    log "Handling values.yaml..." $LOG_PATH
    VALUES=$DIR/files/values/$NODE.yaml
    if [ -f "$VALUES" ]; then
      cp $VALUES $DIR/values.yaml
      HelmCompilePrerequisites
      # update apiVersion/date in values.yaml and backup
      sed -i -e "s/.*apiVersion.*/  apiVersion: \"$DATE\"/" ./values.yaml
      cp $DIR/values.yaml $VALUES

      # compile template based on updated values.yaml
      helm template $DIR --name $TEMPLATE_NAMESPACE --namespace $TEMPLATE_NAMESPACE --output-dir $DIR/output
      if [ $UPDATENODE -eq 0 ]; then updateCordaNodeByDate $DATE $NODE; fi
      if [ $UPDATESPRINGBOOT -eq 0 ]; then updateSpringBootByDate $DATE $NODE; fi
    else
      log "Cannot find $VALUES for deployment!" $LOG_PATH
    fi

  fi
}

main() {
  DATE=$1

  SPRINGBOOT_APP_FOLDER=$DIR/../docker-images/bin/springboot/$DATE
  CORDAPP_FOLDER=$DIR/files/cordapps/$DATE

  # nodePrefix=("node-1" "node-2" "node-3" "node-4" "node-5")
  nodePrefix=("node1" "node2")
  len=${#nodePrefix[@]}

  # check whether the release for given day is present. If not, no update will be performed.
  checkFolderStatus $CORDAPP_FOLDER
  result1=$?
  checkFolderStatus $SPRINGBOOT_APP_FOLDER
  result2=$?

  # check whether springboot docker image for this day is present. if not, build such image
  if [ $result2 -eq 0 ]; then checkDockerImageStatus $DATE; GetPathToCurrentlyExecutingScript; fi

  # update node one by one
  log "Scheduled job started." $LOG_PATH
  for (( i=0; i<$len; i++ )); do
    log "${nodePrefix[$i]}: Updating starts..." $LOG_PATH
    updateNodeByDate $DATE ${nodePrefix[$i]} $result1 $result2

    sleep 60
    log "${nodePrefix[$i]}: Perform basic sanity check." $LOG_PATH
    . $DIR/sanity-check.sh

    # todo: consolidate sanity check result and put to a public place for verification.
  done

  log "Scheduled job completed." $LOG_PATH
  exit 0
}
main $1