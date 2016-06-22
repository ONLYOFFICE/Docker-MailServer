#!/bin/bash

SERVER_HOSTNAME=${SERVER_HOSTNAME:-''}

OLD_HOSTNAME="$( hostname )"
SHORT_HOSTNAME='mail'

echo "Changing hostname from ${OLD_HOSTNAME} to ${SERVER_HOSTNAME}..."

hostname "${SERVER_HOSTNAME}"

sed -i "s/HOSTNAME=.*/HOSTNAME=${SHORT_HOSTNAME}/g" /etc/sysconfig/network

if [ -n "$( grep "${OLD_HOSTNAME}" /etc/hosts )" ]; then
 sed -i "s/${OLD_HOSTNAME}/${SERVER_HOSTNAME} ${SHORT_HOSTNAME}/g" /etc/hosts
else
 echo -e "$( hostname -I | awk '{ print $1 }' )\t${SERVER_HOSTNAME} ${SHORT_HOSTNAME}" >> /etc/hosts
fi