#!/usr/bin/env bash

tmprootdir="$(dirname $0)"
echo ${tmprootdir} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    export ROOTDIR="${tmprootdir}"
else
    export ROOTDIR="$(pwd)"
fi

cd ${ROOTDIR}

export PKG_DIR="${ROOTDIR}/pkgs"
export CONF_DIR="${ROOTDIR}/conf"
export FUNCTIONS_DIR="${ROOTDIR}/functions"
export SAMPLE_DIR="${ROOTDIR}/samples"

# Import variables.
. ${CONF_DIR}/core
. ${CONF_DIR}/server_api
. ${CONF_DIR}/spam_trainer
. ${CONF_DIR}/fail2ban
. ${CONF_DIR}/opendkim

# Switch backend
. ${FUNCTIONS_DIR}/server_api.sh
. ${FUNCTIONS_DIR}/spam_trainer.sh
. ${FUNCTIONS_DIR}/fail2ban.sh
. ${FUNCTIONS_DIR}/opendkim.sh

server_api_install
spam_trainer_install
fail2ban_install
opendkim_install
