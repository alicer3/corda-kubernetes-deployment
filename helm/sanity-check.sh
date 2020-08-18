#!/bin/bash

set -u
DIR="."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
Purple='\033[0;35m'
NC='\033[0m'

NODE=$(grep -A 10 'config:' $DIR/values.yaml | grep 'resourceName: "' | cut -d '"' -f 2)
LOG_FILE="sanitycheck.log"

exec 3>&1 1>>${LOG_FILE} 2>&1

portConnCheck() {
  IP=$1
  PORT_NO=$2
  MESSAGE=$3
  echo "Checking $MESSAGE at $IP:$PORT_NO..." | tee /dev/fd/3
  nc -zv -w5 $IP $PORT_NO
  if [ "$?" -eq 1 ]; then
    echo -e "${RED}$MESSAGE check at $IP:$PORT_NO FAILED!${NC}" 1>&3
  else
    echo -e "${GREEN}$MESSAGE check at $IP:$PORT_NO PASS!${NC}" 1>&3
  fi
}

deploymentStatusCheck() {
  echo "===================== Kubernetes Deployment Check =====================" | tee /dev/fd/3
  kubectl get pods -l group=$NODE
  POD_NUM=$(kubectl get pods -l group=$NODE --no-headers |wc -l | sed -e 's/^[[:space:]]*//')
  RUNNING_POD_NUM=$(kubectl get pods -l group=$NODE --no-headers | grep Running |wc -l | sed -e 's/^[[:space:]]*//')
  EXPECTED_POD_NUM=3
  echo "Number of Pods: $POD_NUM" | tee /dev/fd/3
  echo "Number of Running Pods: $RUNNING_POD_NUM" | tee /dev/fd/3
  if [ "$POD_NUM" -eq "$EXPECTED_POD_NUM" ]; then
    echo -e "${GREEN}Number of Pods checked!${NC}" 1>&3
  else
    echo -e "${RED}Number of Pods is abnormal! \nExpected pods: $EXPECTED_POD_NUM\nActual pods: $POD_NUM${NC}" 1>&3
  fi

  if [ "$POD_NUM" -gt 0 && "$POD_NUM" -eq "$RUNNING_POD_NUM" ]; then
    echo -e "${GREEN}All pods are running!${NC}" 1>&3
  else
    echo -e "${RED}Some pods are not running!${NC}\n" 1>&3
    kubectl get pods -l group=$NODE --no-headers | grep -v Running | tee /dev/fd/3
  fi
  echo "===================== Kubernetes Deployment Check =====================" | tee /dev/fd/3
}

runHealthSurvey() {
#   health survey regular check would cover a lot of checks, including:
#    - node status check
#    - local RPC conn check
#    - local SSH conn check
#    health survey ping notary check would cover:
#    - 2-way p2p conn check
#    - notary conn check
  echo "===================== Health Survey Check Start ====================="
  POD=$(kubectl get pods -l app=$NODE-node -o jsonpath="{.items[0].metadata.name}")
  echo "POD=$POD"
  echo "Health survey Check - Regular Check" | tee /dev/fd/3
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace | tee /dev/fd/3
  echo "Health Survey Check - Ping Notary" | tee /dev/fd/3
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace -n | tee /dev/fd/3
  echo "===================== Health Survey Check End ====================="
}

curlWeb() {
  echo "===================== Web Check Start =====================" | tee /dev/fd/3
  LINK=$(grep -A 10 'apiconfig:' $DIR/values.yaml | grep 'sprintbootDNS: "' | cut -d '"' -f 2)
  echo "Checking https://$LINK/$NODE" | tee /dev/fd/3
  RESULT=$(curl -Is https://$LINK/$NODE | head -1)
  echo $RESULT | tee /dev/fd/3
  if [[ $RESULT == *"HTTP/2 200"* ]]; then
    echo -e "${GREEN}Web Check PASS!${NC}" 1>&3
  else
    echo -e "${RED}Web Check FAILED!${NC}" 1>&3
  fi
  echo "===================== Web Check End =====================" | tee /dev/fd/3
}

main() {
  deploymentStatusCheck
  echo "===================== Port Connection Check Start =====================" | tee /dev/fd/3
  NODEDB_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'databaseLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'nodeLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_P2P=$(grep -A 20 'corda:' $DIR/values.yaml | grep 'p2pPort: ' | cut -d ':' -f 2)
  NODE_SSH=$(grep -A 50 'corda:' $DIR/values.yaml | grep 'sshdPort: ' | cut -d ':' -f 2)
  NODE_RPC=$(grep -A 50 'corda:' $DIR/values.yaml | grep -A -3 'rpc:' | grep 'port: ' | cut -d ":" -f 2)
  portConnCheck $NODEDB_IP 5432 "DB connection"
  portConnCheck $NODE_IP $NODE_P2P "Node p2p connection"
  portConnCheck $NODE_IP $NODE_SSH "Node SSH connection"
  portConnCheck $NODE_IP $NODE_RPC "Node RPC connection"
  echo "===================== Port Connection Check End =====================" | tee /dev/fd/3

  runHealthSurvey
  curlWeb

  DT=`date +"%Y%m%d%H%M%S"`
  mv $LOG_FILE "$NODE-sanitycheck-$DT.log"
}
main