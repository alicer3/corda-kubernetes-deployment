#!/bin/bash

set -eu
DIR="."

. ./helm_libs.sh


GetPathToCurrentlyExecutingScript

#today=`date "+%Y%m%d"`


updateNodeByDate() {
  DATE=$1
  NODE=$2
  UPDATENODE=$3
  UPDATESPRINGBOOT=$4

  DeploymentPrerequisites $NODE
  handleValues $NODE
  if [ $UPDATENODE -eq 1 -a $UPDATESPRINGBOOT -eq 1 ]; then
    echo "No update will be performed."
  else
    handleValues $NODE $DATE
    if [ $UPDATENODE -eq 0 ]; then updateCordaNodeByDate $DATE $NODE; fi
    if [ $UPDATESPRINGBOOT -eq 0 ]; then updateSpringBootByDate $DATE $NODE; fi
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
  if [ $result2 -eq 0 ]; then checkDockerImageStatus $DATE; fi

  # update node one by one
  echo "Scheduled job started."
  for (( i=0; i<$len; i++ )); do
    echo "${nodePrefix[$i]}: Updating starts..."
    updateNodeByDate $DATE ${nodePrefix[$i]} $result1 $result2

    sleep 60
    echo "${nodePrefix[$i]}: Perform basic sanity check."
    . $DIR/sanity-check.sh

    echo "${nodePrefix[$i]}: Done"
  done

  echo "Scheduled job completed."
  exit 0
}
main $1