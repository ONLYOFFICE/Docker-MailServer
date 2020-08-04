#!/bin/bash
if [ ${HOSTNAME_FOR_K8S} ]; then
  NAME="$(hostname -f)"
  cp /etc/hosts ~/hosts.new
  sed -i s/$NAME/$HOSTNAME_FOR_K8S/ ~/hosts.new
  cp -f ~/hosts.new /etc/hosts
  sleep 5
  /usr/src/iRedMail/iRedMail.sh
  /usr/src/iRedMail/run_mailserver.sh
  exec tail -f /dev/null
else
  /usr/src/iRedMail/iRedMail.sh
  /usr/src/iRedMail/run_mailserver.sh
  exec tail -f /dev/null
fi
