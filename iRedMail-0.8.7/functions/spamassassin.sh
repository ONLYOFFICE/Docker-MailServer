#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# ---------------------------------------------------------
# SpamAssassin.
# ---------------------------------------------------------
sa_config()
{
    ECHO_INFO "Configure SpamAssassin (content-based spam filter)."

    backup_file ${SA_LOCAL_CF}

    ECHO_DEBUG "Generate new configuration file: ${SA_LOCAL_CF}."
    cp -f ${SA_SAMPLE_LOCAL_CF} ${SA_LOCAL_CF}

    cat >> ${SA_LOCAL_CF} <<EOF
bayes_sql_dsn      DBI:mysql:${SPAMASSASSIN_DB_NAME}:${SQL_SERVER}:${SQL_SERVER_PORT}
bayes_sql_username ${SPAMASSASSIN_DB_USER}
bayes_sql_password ${SPAMASSASSIN_DB_PASSWD}
EOF

    sa_import_sql

    ECHO_DEBUG "Enable crontabs for SpamAssassin update."
    if [ X"${DISTRO}" == X"RHEL" ]; then
        chmod 0644 /etc/cron.d/sa-update
        perl -pi -e 's/#(10.*)/${1}/' /etc/cron.d/sa-update
    elif [ X"${DISTRO}" == X"UBUNTU" -o X"${DISTRO}" == X"DEBIAN" ]; then
        perl -pi -e 's#^(CRON=)0#${1}1#' /etc/cron.daily/spamassassin
    else
        :
    fi

    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        ECHO_DEBUG "Compile SpamAssassin ruleset into native code."
        sa-compile >/dev/null 2>&1
    fi

    # Start spamassassin when system start up.
    ${enable_service} 'spamassassin'

    cat >> ${TIP_FILE} <<EOF
SpamAssassin:
    * Configuration files and rules:
        - ${SA_CONF_DIR}
        - ${SA_CONF_DIR}/local.cf

EOF

    echo 'export status_sa_config="DONE"' >> ${STATUS_FILE}
}

sa_import_sql()
{
    ECHO_DEBUG "Import SpamAssassin database and privileges."

    
    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Create database
    CREATE DATABASE IF NOT EXISTS ${SPAMASSASSIN_DB_NAME};
EOF

    if [ X"${USE_LOCAL_MYSQL_SERVER}" == X'YES' ]; then
    ${MYSQL_CLIENT_ROOT} <<EOF
        -- Grant privileges
        GRANT SELECT,INSERT,UPDATE,DELETE ON ${SPAMASSASSIN_DB_NAME}.* TO "${SPAMASSASSIN_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY '${SPAMASSASSIN_DB_PASSWD}';
EOF
    fi
    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Import SpamAssassin SQL template
    USE ${SPAMASSASSIN_DB_NAME};
    SOURCE ${SA_DB_MYSQL_TMPL};
EOF
    if [ X"${USE_LOCAL_MYSQL_SERVER}" == X'YES' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
        FLUSH PRIVILEGES;
EOF
    fi 

    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Create database
    USE ${SPAMASSASSIN_DB_NAME};
    SET NAMES utf8;
    INSERT INTO bayes_vars (id, username) VALUES (1, '${SPAMASSASSIN_DB_USER}');
    SOURCE ${SA_BAYES_TOKEN_VAR};
    SOURCE ${SA_BAYES_SEEN};
EOF

    echo 'export status_spamassassin_import_sql="DONE"' >> ${STATUS_FILE}
}