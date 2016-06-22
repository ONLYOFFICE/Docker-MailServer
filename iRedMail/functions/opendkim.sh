#!/usr/bin/env bash

opendkim_install()
{
    ECHO_INFO "Install OpenDkim."

    # Extract source tarball.
    rpm -i ${PKG_DIR}/${OPENDBX_VERSION}
    rpm -i ${PKG_DIR}/${OPENDKIM_TARBALL} 

    echo 'export status_opendkim_install="DONE"' >> ${STATUS_FILE}         
}

opendkim_config()
{
    ECHO_INFO "Configure OpenDkim."

    mkdir -p ${OPENDKIM_USER_HOME}

    # Create group and add user
    groupadd ${OPENDKIM_GROUP}
    useradd -r -g ${OPENDKIM_GROUP} -G mail -s ${SHELL_NOLOGIN} -d ${OPENDKIM_USER_HOME} -c "OpenDKIM" ${OPENDKIM_USER}

    chown ${OPENDKIM_USER}:${OPENDKIM_GROUP} ${OPENDKIM_USER_HOME}

    # Create directories
    mkdir -p ${OPENDKIM_KEYS_DIR}
    mkdir -p ${OPENDKIM_POSTFIX_RUN_DIR}
    chown -R ${OPENDKIM_USER}:${OPENDKIM_GROUP} ${OPENDKIM_DIR}
    chmod -R go-wrx ${OPENDKIM_KEYS_DIR}
    chown ${OPENDKIM_USER}:${OPENDKIM_GROUP} ${OPENDKIM_POSTFIX_RUN_DIR}

    usermod -G ${OPENDKIM_GROUP} ${POSTFIX_DAEMON_USER} 

    # Copy sample config files.
    cp ${OPENDKIM_INIT} /etc/init.d/
    chmod 755 /etc/init.d/opendkim

    # Create mysql table
    ${MYSQL_CLIENT_ROOT} <<EOF
-- Import OpenDKIM SQL template
USE ${VMAIL_DB};
SOURCE ${OPENDKIM_DB_MYSQL_TMPL};
EOF

   cp -f ${OPENDKIM_SAMPLE_LOCAL_CF} ${OPENDKIM_LOCAL_CF}

   cat >> ${OPENDKIM_LOCAL_CF} <<EOF
# Identifies a set "internal" hosts whose mail should be signed rather than verified.
#InternalHosts refile:/etc/opendkim/TrustedHosts
SigningTable dsn:mysql://${VMAIL_DB_ADMIN_USER}:${VMAIL_DB_ADMIN_PASSWD}@${MYSQL_SERVER}/${VMAIL_DB}/table=dkim?keycol=domain_name?datacol=id
KeyTable dsn:mysql://${VMAIL_DB_ADMIN_USER}:${VMAIL_DB_ADMIN_PASSWD}@${MYSQL_SERVER}/${VMAIL_DB}/table=dkim?keycol=id?datacol=domain_name,selector,private_key
EOF

    postconf -e smtpd_milters='unix:/var/run/opendkim/opendkim.sock'
    postconf -e non_smtpd_milters='$smtpd_milters'
    postconf -e milter_default_action='accept'
    postconf -e milter_protocol='2'
    postconf -e receive_override_options='no_header_body_checks, no_unknown_recipient_checks, no_milters'

    # Start opendkim when system start up.
    service_control enable 'opendkim' >> ${INSTALL_LOG} 2>&1
    service_control disable ${DISABLED_SERVICES} 'sendmail' >> ${INSTALL_LOG} 2>&1

    chkconfig --del sendmail

    echo 'export status_opendkim_config="DONE"' >> ${STATUS_FILE}
}