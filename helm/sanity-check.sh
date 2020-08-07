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
    printf "${RED}$MESSAGE check at $IP:$PORT_NO FAILED!${NC}\n" 1>&3
    echo "$MESSAGE check at $IP:$PORT_NO FAILED!" 1>&2
  else
    printf "${GREEN}$MESSAGE check at $IP:$PORT_NO PASS!${NC}\n" 1>&3
    echo "$MESSAGE check at $IP:$PORT_NO PASS!" 1>&2
  fi
}

runHealthSurvey() {
#   health survey regular check would cover a lot of checks, including:
#    - node status check
#    - local RPC conn check
#    - local SSH conn check
#    health survey ping notary check would cover:
#    - 2-way p2p conn check
#    - notary conn check

  POD=$(kubectl get pods -l app=$NODE-node -o jsonpath="{.items[0].metadata.name}")
  echo "Health survey Check - Regular Check"
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace | tee /dev/fd/3
  echo "Health Survey Check - Ping Notary"
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace -n | tee /dev/fd/3
}

curlWeb() {
  echo "===================== Web Check Start ====================="
  LINK=$(grep -A 10 'apiconfig:' $DIR/values.yaml | grep 'sprintbootDNS: "' | cut -d '"' -f 2)
  echo "Checking $LINK/$NODE"
  RESULT=$(curl -Is $LINK/$NODE | head -1)
  echo $RESULT
  echo "===================== Web Check End ====================="
}

main() {
  echo "===================== Port Connection Check Start ====================="
  NODEDB_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'databaseLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'nodeLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_P2P=$(grep -A 20 'corda:' $DIR/values.yaml | grep 'p2pPort: ' | cut -d ':' -f 2)
  NODE_SSH=$(grep -A 50 'corda:' $DIR/values.yaml | grep 'sshdPort: ' | cut -d ':' -f 2)
  NODE_RPC=$(grep -A 50 'corda:' $DIR/values.yaml | grep -A -3 'rpc:' | grep 'port: ' | cut -d ":" -f 2)
  portConnCheck $NODEDB_IP 5432 "DB connection"
  portConnCheck $NODE_IP $NODE_P2P "Node p2p connection"
  portConnCheck $NODE_IP $NODE_SSH "Node SSH connection"
  portConnCheck $NODE_IP $NODE_RPC "Node RPC connection"
  echo "===================== Port Connection Check End ====================="

  echo "===================== Health Survey Check Start ====================="
  runHealthSurvey
  echo "===================== Health Survey Check End ====================="
  curlWeb
  mv $LOG_FILE "$NODE-sanitycheck.log"
}
main