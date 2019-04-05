#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# ---------------------------------------------------------
# SpamAssassin.
# ---------------------------------------------------------
sa_config()
{
    ECHO_INFO "Configure SpamAssassin (content-based spam filter)."

    backup_file ${SA_LOCAL_CF}

    ECHO_DEBUG "Copy sample SpamAssassin config file: ${SA_SAMPLE_LOCAL_CF} -> ${SA_LOCAL_CF}."
    cp -f ${SA_SAMPLE_LOCAL_CF} ${SA_LOCAL_CF}

    #ECHO_DEBUG "Disable plugin: URIDNSBL."
    #perl -pi -e 's/(^loadplugin.*Mail.*SpamAssassin.*Plugin.*URIDNSBL.*)/#${1}/' ${SA_INIT_PRE}

    sa_import_sql

    ECHO_DEBUG "Enable crontabs for SpamAssassin update."

    chmod 0644 /etc/cron.d/sa-update
    perl -pi -e 's/#(10.*)/${1}/' /etc/cron.d/sa-update    

    cat >> ${TIP_FILE} <<EOF
SpamAssassin:
    * Configuration files and rules:
        - ${SA_CONF_DIR}
        - ${SA_CONF_DIR}/local.cf

EOF

    # Start opendkim when system start up.
    service_control enable 'spamassassin' >> ${INSTALL_LOG} 2>&1

    echo 'export status_sa_config="DONE"' >> ${STATUS_FILE}
}

sa_import_sql()
{
    ECHO_DEBUG "Import SpamAssassin database and privileges."

    
    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Create database
    CREATE DATABASE IF NOT EXISTS \`${SPAMASSASSIN_DB_NAME}\`;
EOF

    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
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
    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
        FLUSH PRIVILEGES;
EOF
    fi 

    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Create database
    USE ${SPAMASSASSIN_DB_NAME};
    SET NAMES utf8;
    INSERT INTO bayes_vars (id, username) VALUES (1, '${SPAMASSASSIN_DB_USER}') ON DUPLICATE KEY UPDATE username='${SPAMASSASSIN_DB_USER}';
    SOURCE ${SA_BAYES_TOKEN_VAR};
    SOURCE ${SA_BAYES_SEEN};
EOF

    echo 'export status_spamassassin_import_sql="DONE"' >> ${STATUS_FILE}
}