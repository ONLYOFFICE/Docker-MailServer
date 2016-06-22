#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)

#---------------------------------------------------------------------
# This file is part of iRedMail, which is an open source mail server
# solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
#
# iRedMail is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# iRedMail is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
#---------------------------------------------------------------------

# -------------------------------------------------------
# Dovecot & dovecot-sieve.
# -------------------------------------------------------

dovecot_config()
{
    ECHO_INFO "Configure Dovecot (pop3/imap/managesieve server)."

    backup_file ${DOVECOT_CONF}

    ECHO_DEBUG "Configure dovecot: ${DOVECOT_CONF}."

    # RHEL/CentOS 6:    Dovecot-2.1.x
    # RHEL/CentOS 7:    Dovecot-2.2.10+
    # Debian 7:         Dovecot-2.1.x
    # Debian 8:         Dovecot-2.2.13+
    # Ubuntu 14.04:     Dovecot-2.2.9+
    dovecot_version="$(dovecot --version | cut -c1,2,3)"
    if [ X"${dovecot_version}" == X'2.0' -o X"${dovecot_version}" == X'2.1' ]; then
        cp ${SAMPLE_DIR}/dovecot/dovecot2.conf ${DOVECOT_CONF}
    else
        cp ${SAMPLE_DIR}/dovecot/dovecot22.conf ${DOVECOT_CONF}
    fi
    chmod 0664 ${DOVECOT_CONF}

    # Base directory.
    perl -pi -e 's#PH_BASE_DIR#$ENV{DOVECOT_BASE_DIR}#' ${DOVECOT_CONF}

    # Provided services.
    export DOVECOT_PROTOCOLS
    perl -pi -e 's#PH_PROTOCOLS#$ENV{DOVECOT_PROTOCOLS}#' ${DOVECOT_CONF}

    # Set correct uid/gid.
    perl -pi -e 's#PH_MAIL_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_MAIL_GID#$ENV{VMAIL_USER_GID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_FIRST_VALID_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_LAST_VALID_UID#$ENV{VMAIL_USER_UID}#' ${DOVECOT_CONF}

    # Log file.
    perl -pi -e 's#PH_LOG_PATH#$ENV{DOVECOT_LOG_FILE}#' ${DOVECOT_CONF}

    # Authentication related settings.
    # Append this domain name if client gives empty realm.
    perl -pi -e 's#PH_AUTH_DEFAULT_REALM#$ENV{FIRST_DOMAIN}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MECHANISMS#$ENV{DOVECOT_AUTH_MECHS}#' ${DOVECOT_CONF}

    # service auth {}
    perl -pi -e 's#PH_DOVECOT_AUTH_USER#$ENV{POSTFIX_DAEMON_USER}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_AUTH_GROUP#$ENV{POSTFIX_DAEMON_GROUP}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_AUTH_MASTER_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}

    # Virtual mail accounts.
    # Reference: http://wiki2.dovecot.org/AuthDatabase/LDAP
        # MySQL.
        perl -pi -e 's#PH_USERDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_USERDB_DRIVER#sql#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_ARGS#$ENV{DOVECOT_MYSQL_CONF}#' ${DOVECOT_CONF}
        perl -pi -e 's#PH_PASSDB_DRIVER#sql#' ${DOVECOT_CONF}


    # Master user.
    perl -pi -e 's#PH_DOVECOT_MASTER_USER_PASSWORD_FILE#$ENV{DOVECOT_MASTER_USER_PASSWORD_FILE}#' ${DOVECOT_CONF}
    touch ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_MASTER_USER_PASSWORD_FILE}
    chmod 0500 ${DOVECOT_MASTER_USER_PASSWORD_FILE}

    perl -pi -e 's#PH_DOVECOT_AUTH_MASTER_PATH#$ENV{DOVECOT_AUTH_MASTER_PATH}#' ${DOVECOT_CONF}

    # Quota.
    perl -pi -e 's#PH_QUOTA_TYPE#$ENV{DOVECOT_QUOTA_TYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_SCRIPT#$ENV{DOVECOT_QUOTA_WARNING_SCRIPT}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_QUOTA_WARNING_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}

    # Quota dict.
    perl -pi -e 's#PH_SERVICE_DICT_USER#$ENV{VMAIL_USER_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SERVICE_DICT_GROUP#$ENV{VMAIL_GROUP_NAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_SQLTYPE#$ENV{DOVECOT_REALTIME_QUOTA_SQLTYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_CONF#$ENV{DOVECOT_REALTIME_QUOTA_CONF}#' ${DOVECOT_CONF}

    # Sieve.
    perl -pi -e 's#PH_SIEVE_DIR#$ENV{SIEVE_DIR}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SIEVE_LOG_FILE#$ENV{DOVECOT_SIEVE_LOG_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SIEVE_RULE_FILENAME#$ENV{SIEVE_RULE_FILENAME}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_GLOBAL_SIEVE_FILE#$ENV{DOVECOT_GLOBAL_SIEVE_FILE}#' ${DOVECOT_CONF}

    # LMTP
    perl -pi -e 's#PH_DOVECOT_LMTP_LOG_FILE#$ENV{DOVECOT_LMTP_LOG_FILE}#' ${DOVECOT_CONF}

    # SSL.
    perl -pi -e 's#PH_SSL_CERT#$ENV{SSL_CERT_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SSL_KEY#$ENV{SSL_KEY_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SSL_CA#$ENV{SSL_CA_BUNDLE_FILE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_SSL_CIPHERS#$ENV{SSL_CIPHERS}#' ${DOVECOT_CONF}

    # Enable parameters which requires at least Dovecot-2.2.6
    use_longer_dhparam_length='YES'
    if [ X"${DISTRO_VERSION}" == X'6' ]; then
        use_longer_dhparam_length='NO'
    fi

    perl -pi -e 's#PH_POSTFIX_CHROOT_DIR#$ENV{POSTFIX_CHROOT_DIR}#' ${DOVECOT_CONF}

    # Generate dovecot quota warning script.
    mkdir -p $(dirname ${DOVECOT_QUOTA_WARNING_SCRIPT}) >> ${INSTALL_LOG} 2>&1

    backup_file ${DOVECOT_QUOTA_WARNING_SCRIPT}
    rm -f ${DOVECOT_QUOTA_WARNING_SCRIPT} >> ${INSTALL_LOG} 2>&1
    cp -f ${SAMPLE_DIR}/dovecot/dovecot2-quota-warning.sh ${DOVECOT_QUOTA_WARNING_SCRIPT}
    if [ X"${DOVECOT_QUOTA_TYPE}" == X'maildir' ]; then
        perl -pi -e 's#(.*)(-o.*plugin.*)#${1}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    fi

    export DOVECOT_DELIVER HOSTNAME
    perl -pi -e 's#PH_DOVECOT_DELIVER#$ENV{DOVECOT_DELIVER}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}
    perl -pi -e 's#PH_HOSTNAME#$ENV{HOSTNAME}#' ${DOVECOT_QUOTA_WARNING_SCRIPT}

    chown root ${DOVECOT_QUOTA_WARNING_SCRIPT}
    chmod 0755 ${DOVECOT_QUOTA_WARNING_SCRIPT}

    backup_file ${DOVECOT_MYSQL_CONF}
    cp -f ${SAMPLE_DIR}/dovecot/dovecot-sql.conf ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's/^#(iterate_.*)/${1}/' ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's#(.*mailbox.)(enable.*Lc)(=1)#${1}`${2}`${3}#' ${DOVECOT_MYSQL_CONF}

    perl -pi -e 's#PH_SQL_DRIVER#mysql#' ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's#PH_VMAIL_DB#$ENV{VMAIL_DB}#' ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's#PH_VMAIL_DB_BIND_USER#$ENV{VMAIL_DB_ADMIN_USER}#' ${DOVECOT_MYSQL_CONF}
    perl -pi -e 's#PH_VMAIL_DB_BIND_PASSWD#$ENV{VMAIL_DB_ADMIN_PASSWD}#' ${DOVECOT_MYSQL_CONF}

    # Set file permission.
    chmod 0550 ${DOVECOT_MYSQL_CONF}   

    # Realtime quota
    export realtime_quota_db_name="${VMAIL_DB}"
    export realtime_quota_db_user="${VMAIL_DB_ADMIN_USER}"
    export realtime_quota_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"    

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-used-quota.conf ${DOVECOT_REALTIME_QUOTA_CONF}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_REALTIME_QUOTA_CONF}
    chmod 0500 ${DOVECOT_REALTIME_QUOTA_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_NAME#$ENV{realtime_quota_db_name}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_USER#$ENV{realtime_quota_db_user}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_REALTIME_QUOTA_DB_PASSWORD#$ENV{realtime_quota_db_passwd}#' ${DOVECOT_REALTIME_QUOTA_CONF}
    perl -pi -e 's#PH_DOVECOT_REALTIME_QUOTA_TABLE#$ENV{DOVECOT_REALTIME_QUOTA_TABLE}#' ${DOVECOT_REALTIME_QUOTA_CONF}

    # IMAP shared folder
    backup_file ${DOVECOT_SHARE_FOLDER_CONF}

    export share_folder_db_name="${VMAIL_DB}"
    export share_folder_db_user="${VMAIL_DB_ADMIN_USER}"
    export share_folder_db_passwd="${VMAIL_DB_ADMIN_PASSWD}"


    # ACL and share folder settings in dovecot.conf
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_SQLTYPE#$ENV{DOVECOT_SHARE_FOLDER_SQLTYPE}#' ${DOVECOT_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_CONF#$ENV{DOVECOT_SHARE_FOLDER_CONF}#' ${DOVECOT_CONF}

    # Copy sample config and set file owner/permission
    cp ${SAMPLE_DIR}/dovecot/dovecot-share-folder.conf ${DOVECOT_SHARE_FOLDER_CONF}
    chown ${DOVECOT_USER}:${DOVECOT_GROUP} ${DOVECOT_SHARE_FOLDER_CONF}
    chmod 0500 ${DOVECOT_SHARE_FOLDER_CONF}

    # Replace place holders in sample config file
    perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_NAME#$ENV{share_folder_db_name}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_USER#$ENV{share_folder_db_user}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_PASSWORD#$ENV{share_folder_db_passwd}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}
    perl -pi -e 's#PH_DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE#$ENV{DOVECOT_SHARE_FOLDER_ANYONE_DB_TABLE}#' ${DOVECOT_SHARE_FOLDER_CONF}

    ECHO_DEBUG "Copy sample sieve global filter rule file: ${DOVECOT_GLOBAL_SIEVE_FILE}."
    cp -f ${SAMPLE_DIR}/dovecot/dovecot.sieve ${DOVECOT_GLOBAL_SIEVE_FILE}
    chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${DOVECOT_GLOBAL_SIEVE_FILE}
    chmod 0500 ${DOVECOT_GLOBAL_SIEVE_FILE}

    for f in ${DOVECOT_LOG_FILE} ${DOVECOT_SIEVE_LOG_FILE} ${DOVECOT_LMTP_LOG_FILE}; do
        ECHO_DEBUG "Create dovecot log file: ${f}."
        touch ${f}
        chown ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${f}
        chmod 0600 ${f}
    done

    ECHO_DEBUG "Enable dovecot SASL support in postfix: ${POSTFIX_FILE_MAIN_CF}."
    postconf -e mailbox_command="${DOVECOT_DELIVER}"
    postconf -e virtual_transport="${TRANSPORT}"
    postconf -e dovecot_destination_recipient_limit='1'

    postconf -e smtpd_sasl_type='dovecot'
    postconf -e smtpd_sasl_path="${DOVECOT_AUTH_SOCKET_NAME}"

    ECHO_DEBUG "Create directory for Dovecot plugin: Expire."
    dovecot_expire_dict_dir="$(dirname ${DOVECOT_EXPIRE_DICT_BDB})"
    mkdir -p ${dovecot_expire_dict_dir} && \
    chown -R ${DOVECOT_USER}:${DOVECOT_GROUP} ${dovecot_expire_dict_dir} && \
    chmod -R 0750 ${dovecot_expire_dict_dir}

    cat >> ${POSTFIX_FILE_MASTER_CF} <<EOF
# Use dovecot deliver program as LDA.
dovecot unix    -       n       n       -       -      pipe
    flags=DRhu user=${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} argv=${DOVECOT_DELIVER} -f \${sender} -d \${user}@\${domain} -m \${extension}

EOF

    ECHO_DEBUG "Setting logrotate for dovecot log file."

    cat >| ${DOVECOT_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${DOVECOT_LOG_FILE}
${DOVECOT_SIEVE_LOG_FILE}
${DOVECOT_LMTP_LOG_FILE} {
    compress
    weekly
    rotate 10
    create 0600 ${VMAIL_USER_NAME} ${VMAIL_GROUP_NAME}
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        doveadm log reopen
    endscript
}
EOF    

    cat >> ${TIP_FILE} <<EOF
Dovecot:
    * Configuration files:
        - ${DOVECOT_CONF}
        - ${DOVECOT_LDAP_CONF} (For OpenLDAP backend)
        - ${DOVECOT_MYSQL_CONF} (For MySQL backend)
        - ${DOVECOT_PGSQL_CONF} (For PostgreSQL backend)
        - ${DOVECOT_REALTIME_QUOTA_CONF} (For real-time quota usage)
        - ${DOVECOT_SHARE_FOLDER_CONF} (For IMAP sharing folder)
    * RC script: ${DIR_RC_SCRIPTS}/${DOVECOT_RC_SCRIPT_NAME}
    * Log files:
        - ${DOVECOT_LOG_FILE}
        - ${DOVECOT_SIEVE_LOG_FILE}
        - ${DOVECOT_LMTP_LOG_FILE}
    * See also:
        - ${DOVECOT_GLOBAL_SIEVE_FILE}
        - Logrotate config file: ${DOVECOT_LOGROTATE_FILE}

EOF

    echo 'export status_dovecot_config="DONE"' >> ${STATUS_FILE}
}

enable_dovecot()
{
    check_status_before_run dovecot_config

    echo 'export status_enable_dovecot="DONE"' >> ${STATUS_FILE}
}