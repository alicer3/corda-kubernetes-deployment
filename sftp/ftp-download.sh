#!/bin/bash

set -eu
DIR="."

. $DIR/ftp-config.sh

today=`date "+%Y%m%d"`
SOURCEPATH=("/upload/${today}/springboot/*" "/upload/${today}/cordapps/*")
DESTPATH=("${DIR}/../docker-images/bin/springboot/${today}" "${DIR}/files/cordapps/${today}")

log() {
  # shellcheck disable=SC2006
  today=`date "+%Y%m%d"`
  echo "[`date '+%Y%m%d-%H:%M:%S.%N'`]====== $1 ... ====== " >> "${DIR}/${today}-ftp-download.log"
}

Download () {
  source="$1"
  dest="$2"

  log "Start download packages from ftp: ${SERVER}${PATH}"
  log "From: ${source} to ${dest}."
  log "Make sure sshpass is installed in the host."

export SSHPASS=$PASSWORD
sshpass -e sftp -oBatchMode=no -b - $USER@$SERVER <<EOF
get -r ${source} ${dest}/
bye
EOF

  log "Download packages from ftp completed."
}

main() {

  len=${#SOURCEPATH[@]}
  for (( i=0; i<$len; i++ )); do
    # todo: need to check folder existance to avoid overwrite?
    mkdir -p ${DESTPATH[$i]}
    Download ${SOURCEPATH[$i]} ${DESTPATH[$i]}
  done

  exit 0
}
main
