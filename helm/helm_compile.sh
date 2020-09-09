#!/bin/bash

RED='\033[0;31m' # Error color
YELLOW='\033[0;33m' # Warning color
NC='\033[0m' # No Color

set -eu
DIR="."

. ./helm_libs.sh

GetPathToCurrentlyExecutingScript

main() {
  NODE=$1
  read -p "For $NODE, the action you want to take:
  1) display current setting
  2) update cordapp with specific date
  3) update springboot with specific date
  4) reset database
  5) delete node deployment
  6) reset/deploy node (database + node + springboot)
  7) sanity check
  " selection
  echo $selection

  read -p  "Please repeat the choice to confirm: " choice
  echo $choice

  if [ $selection != $choice ]; then
    printf "${RED}Choice Mismatch. Exiting...${NC}\n"
    exit 1
  fi


  # todo: check deployment status

  # check on values, certs
  if [ $selection -ne 6 ]; then DeploymentPrerequisites $NODE; fi

  case $selection in
    "1") printf "${YELLOW}Display current setting for $NODE${NC}\n"
         DisplayNodeSetting $NODE
         ;;
    "2") printf "${YELLOW}Update CorDapp version in $NODE..${NC}\n"
         read -p  "Input the CorDapp version you want to update in $NODE: " date
         updateCordaNodeByDate $date $NODE
         ;;
    "3") printf "${YELLOW}Update Springboot version in $NODE..${NC}\n"
         read -p  "Input the Springboot version you want to update in $NODE: " date
         updateSpringbootByDate $date $NODE
         ;;
    "4") printf "${YELLOW}Reset database for $NODE..${NC}\n"
         ResetDatabase $NODE
         ;;
    "5") printf "${YELLOW}Deleting all kubernetes resources for $NODE..${NC}\n"
         kubectl delete jobs,pods,services,deployments,statefulsets,configmaps,svc,pvc,pv,secrets,storageclass,ingress -l group=$NODE --wait=false
         ;;
    "6") printf "${YELLOW} Re-deploying all kubernetes resources (including database) for $NODE..${NC}"
         ResetDeployment $NODE
         ;;
    "7") printf "${YELLOW} Running sanity check for $NODE..${NC}\n"
         handleValues $NODE "" ""
         . $DIR/sanity-check.sh
         ;;
    *) printf "illegal option"
        ;;
  esac
  exit 0
}

main $1