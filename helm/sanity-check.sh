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

portConnCheck() {
  IP=$1
  PORT_NO=$2
  MESSAGE=$3
  echo "Checking $MESSAGE at $IP:$PORT_NO..." | tee -a $LOG_FILE
  nc -zv -w5 $IP $PORT_NO
  if [ "$?" -eq 1 ]; then
    echo -e "${RED}ERROR${NC}"
    echo "$MESSAGE check at $IP:$PORT_NO FAILED!" | tee -a $LOG_FILE
  else
    echo -e "${GREEN}PASS${NC}"
    echo "MESSAGE check at $IP:$PORT_NO PASS!" | tee -a $LOG_FILE
  fi
}

deploymentStatusCheck() {
  echo "===================== Kubernetes Deployment Check =====================" | tee -a $LOG_FILE
  kubectl get pods -l group=$NODE
  POD_NUM=$(kubectl get pods -l group=$NODE --no-headers |wc -l | sed -e 's/^[[:space:]]*//')
  RUNNING_POD_NUM=$(kubectl get pods -l group=$NODE --no-headers | grep Running |wc -l | sed -e 's/^[[:space:]]*//')
  EXPECTED_POD_NUM=3
  echo "Number of Pods: $POD_NUM" | tee -a $LOG_FILE
  echo "Number of Running Pods: $RUNNING_POD_NUM" | tee -a $LOG_FILE
  if [ "$POD_NUM" -eq "$EXPECTED_POD_NUM" ]; then
    echo -e "${GREEN}PASS${NC}"
    echo "Number of Pods checked!" | tee -a $LOG_FILE
  else
    echo -e "${RED}ERROR${NC}"
    echo "Number of Pods is abnormal! \nExpected pods: $EXPECTED_POD_NUM\nActual pods: $POD_NUM" | tee -a $LOG_FILE
  fi

  if [ "$POD_NUM" -gt 0 ] && [ "$POD_NUM" -eq "$RUNNING_POD_NUM" ]; then
    echo -e "${GREEN}PASS${NC}"
    echo "All pods are running!" | tee -a $LOG_FILE
  else
    echo -e "${RED}ERROR${NC}"
    echo -e "Some pods are not running!" | tee -a $LOG_FILE
    kubectl get pods -l group=$NODE --no-headers | grep -v Running | tee -a $LOG_FILE
  fi
  echo "===================== Kubernetes Deployment Check =====================" | tee -a $LOG_FILE
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
  echo "Health survey Check - Regular Check" | tee -a $LOG_FILE
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace | tee -a $LOG_FILE
  echo "Health Survey Check - Ping Notary" | tee -a $LOG_FILE
  kubectl exec $POD -- java -jar corda-tools-health-survey.jar -e -t -d ./workspace -n | tee -a $LOG_FILE
  echo "===================== Health Survey Check End ====================="
}

curlWeb() {
  echo "===================== Web Check Start =====================" | tee -a $LOG_FILE
  LINK=$(grep -A 10 'apiconfig:' $DIR/values.yaml | grep 'springbootDNS: "' | cut -d '"' -f 2)
  echo "Checking https://$LINK/$NODE" | tee -a $LOG_FILE
  RESULT=$(curl -Is https://$LINK/$NODE | head -1)
  echo $RESULT | tee -a $LOG_FILE
  if [[ $RESULT == *"HTTP/2 200"* ]]; then
    echo -e "${GREEN}PASS${NC}"
    echo -e "Web Check PASS!" | tee -a $LOG_FILE
  else
    echo -e "${RED}ERROR${NC}"
    echo -e "Web Check FAILED!" | tee -a $LOG_FILE
  fi
  echo "===================== Web Check End =====================" | tee -a $LOG_FILE
}

main() {
  deploymentStatusCheck
  echo "===================== Port Connection Check Start =====================" | tee -a $LOG_FILE
  NODEDB_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'databaseLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_IP=$(grep -A 100 'config:' $DIR/values.yaml | grep 'nodeLoadBalancerIP: "' | cut -d '"' -f 2)
  NODE_P2P=$(grep -A 20 'corda:' $DIR/values.yaml | grep 'p2pPort: ' | cut -d ':' -f 2)
  NODE_SSH=$(grep -A 50 'corda:' $DIR/values.yaml | grep 'sshdPort: ' | cut -d ':' -f 2)
  NODE_RPC=$(grep -A 50 'corda:' $DIR/values.yaml | grep -A 3 'rpc:' | grep 'port: ' | cut -d ":" -f 2)
  portConnCheck $NODEDB_IP 5432 "DB connection"
  portConnCheck $NODE_IP $NODE_P2P "Node p2p connection"
  portConnCheck $NODE_IP $NODE_SSH "Node SSH connection"
  portConnCheck $NODE_IP $NODE_RPC "Node RPC connection"
  echo "===================== Port Connection Check End =====================" | tee -a $LOG_FILE

  runHealthSurvey
  curlWeb

  DT=`date +"%Y%m%d-%H%M%S"`
  mv $LOG_FILE "$DIR/logs/sanitycheck/$NODE-sanitycheck-$DT.log"
}
main