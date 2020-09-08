#!/bin/bash

set -eu
DIR="."

. ./helm_libs.sh


GetPathToCurrentlyExecutingScript


updateNodeByDate() {
  DATE=$1
  NODE=$2

  DeploymentPrerequisites $NODE
  updateCordaNodeByDate $DATE $NODE
  updateSpringbootByDate $DATE $NODE

}

main() {
  DATE=$1

  SPRINGBOOT_APP_FOLDER=$DIR/../docker-images/bin/springboot/$DATE
  CORDAPP_FOLDER=$DIR/files/cordapps/$DATE

  # nodePrefix=("node-1" "node-2" "node-3" "node-4" "node-5")
  nodePrefix=("node1" "node2")
  len=${#nodePrefix[@]}

  # update node one by one
  echo "Scheduled job started."
  for (( i=0; i<$len; i++ )); do
    echo "${nodePrefix[$i]}: Updating starts..."
    updateNodeByDate $DATE ${nodePrefix[$i]}

    sleep 60
    echo "${nodePrefix[$i]}: Perform basic sanity check."
    . $DIR/sanity-check.sh

    echo "${nodePrefix[$i]}: Done"
  done

  echo "Scheduled job completed."
  exit 0
}
main $1