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

# ---------------------------------------------
# Policyd-2.x (code name: cluebringer).
# ---------------------------------------------
cluebringer_user()
{
    ECHO_DEBUG "Add user and group for policyd: ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP}."

    groupadd ${CLUEBRINGER_GROUP}
    useradd -m -d ${CLUEBRINGER_USER_HOME} -s ${SHELL_NOLOGIN} -g ${CLUEBRINGER_GROUP} ${CLUEBRINGER_USER}

    echo 'export status_cluebringer_user="DONE"' >> ${STATUS_FILE}
}

cluebringer_config()
{
    ECHO_DEBUG "Initialize SQL database for policyd."

    backup_file ${CLUEBRINGER_CONF}

    # Configure '[server]' section.
    #
    # User to run this daemon as
    perl -pi -e 's/^#(user=).*/${1}$ENV{CLUEBRINGER_USER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(group=).*/${1}$ENV{CLUEBRINGER_GROUP}/' ${CLUEBRINGER_CONF}

    # Filename to store pid of parent process
    perl -pi -e 's/^(pid_file=).*/${1}$ENV{CLUEBRINGER_PID_FILE}/' ${CLUEBRINGER_CONF}

    # Log level
    # 0 - Errors only
    # 1 - Warnings and errors
    # 2 - Notices, warnings, errors
    # 3 - Info, notices, warnings, errors
    # 4 - Debugging
    perl -pi -e 's/^#(log_level=).*/${1}0/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(log_mail=).*/${1}mail\@syslog:native/' ${CLUEBRINGER_CONF}

    # File to log to instead of stdout
    perl -pi -e 's/^#(log_file=).*/${1}$ENV{CLUEBRINGER_LOG_FILE}/' ${CLUEBRINGER_CONF}

    # IP to listen on, * for all
    perl -pi -e 's/^(host=).*/${1}$ENV{CLUEBRINGER_BIND_HOST}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(host=).*/${1}$ENV{CLUEBRINGER_BIND_HOST}/' ${CLUEBRINGER_CONF}
    # Port to run on
    perl -pi -e 's/^#(port=).*/${1}$ENV{CLUEBRINGER_BIND_PORT}/' ${CLUEBRINGER_CONF}

    # How many seconds before we retry a DB connection
    perl -pi -e 's/^#(bypass_timeout=).*/${1}10/' ${CLUEBRINGER_CONF}
    perl -pi -e 's#^(bypass_timeout=).*#${1}10#' ${CLUEBRINGER_CONF}

    #
    # Configure '[database]' section.
    #
    perl -pi -e 's#^(bypass_mode=).*#${1}pass#' ${CLUEBRINGER_CONF}

    # DSN
    perl -pi -e 's/^(#*)(DSN=DBI:mysql:).*/${2}host=$ENV{SQL_SERVER};database=$ENV{CLUEBRINGER_DB_NAME};user=$ENV{CLUEBRINGER_DB_USER};password=$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Type=).*/${1}mysql/' ${CLUEBRINGER_CONF}

    # Database
    # Uncomment variables first.
    perl -pi -e 's/^#(DB_Host=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(DB_Port=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(DB_Name=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(Username=.*)/${1}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^#(Password=.*)/${1}/' ${CLUEBRINGER_CONF}
    # Set proper values
    perl -pi -e 's/^(DB_Host=).*/${1}$ENV{SQL_SERVER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Port=).*/${1}$ENV{SQL_SERVER_PORT}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(DB_Name=).*/${1}$ENV{CLUEBRINGER_DB_NAME}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Username=).*/${1}$ENV{CLUEBRINGER_DB_USER}/' ${CLUEBRINGER_CONF}
    perl -pi -e 's/^(Password=).*/${1}$ENV{CLUEBRINGER_DB_PASSWD}/' ${CLUEBRINGER_CONF}

    # Get SQL structure template file.
    tmp_sql="/tmp/cluebringer_init_sql.${RANDOM}${RANDOM}"
    echo '' > ${tmp_sql}

    perl -pi -e 's#TYPE=#ENGINE=#g' ${DB_SAMPLE_FILE}
    # Required by MySQL-5.6: 'NOT NULL' must has a default value.
    perl -pi -e 's#(.*Track.*NOT.*NULL)(.*)#${1} DEFAULT ""${2}#g' ${DB_SAMPLE_FILE}

    cat >> ${tmp_sql} <<EOF
CREATE DATABASE IF NOT EXISTS \`${CLUEBRINGER_DB_NAME}\`;
USE ${CLUEBRINGER_DB_NAME};
SOURCE ${DB_SAMPLE_FILE};
EOF

    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
       cat >> ${tmp_sql} <<EOF
-- Grant privileges.
GRANT SELECT,INSERT,UPDATE,DELETE ON ${CLUEBRINGER_DB_NAME}.* TO "${CLUEBRINGER_DB_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${CLUEBRINGER_DB_PASSWD}";
FLUSH PRIVILEGES;
EOF
    fi

    cat >> ${tmp_sql} <<EOF
USE ${CLUEBRINGER_DB_NAME};
EOF

    # Enable greylisting on Default Inbound.
    cat >> ${tmp_sql} <<EOF
INSERT INTO greylisting (PolicyID, Name, UseGreylisting, GreylistPeriod, Track, GreylistAuthValidity, GreylistUnAuthValidity, UseAutoWhitelist, AutoWhitelistPeriod, AutoWhitelistCount, AutoWhitelistPercentage, UseAutoBlacklist, AutoBlacklistPeriod, AutoBlacklistCount, AutoBlacklistPercentage, COMMENT, Disabled) SELECT * FROM 
(SELECT 3 AS PolicyID, 'Greylisting Inbound Emails' AS Name, 1 AS UseGreylisting, 240 AS GreylistPeriod, 'SenderIP:/24' AS Track, 604800 AS GreylistAuthValidity, 86400 AS GreylistUnAuthValidity, 1 AS UseAutoWhitelist, 604800 AS AutoWhitelistPeriod, 100 AS AutoWhitelistCount, 
90 AS AutoWhitelistPercentage, 1 AS UseAutoBlacklist, 604800 AS AutoBlacklistPeriod, 100 AS AutoBlacklistCount, 20 AS AutoBlacklistPercentage, '' AS COMMENT, 0 AS Disabled) AS tmp
WHERE NOT EXISTS (SELECT Name FROM greylisting WHERE PolicyID=3 AND Name='Greylisting Inbound Emails' AND UseGreylisting=1) LIMIT 1;
EOF

    # Add first mail domain to policy group: internal_domains
    cat >> ${tmp_sql} <<EOF
INSERT INTO policy_group_members (PolicyGroupID, Member, Disabled)
SELECT * FROM (SELECT 2, '@${FIRST_DOMAIN}', 0) AS tmp
WHERE NOT EXISTS (SELECT PolicyGroupID FROM policy_group_members WHERE PolicyGroupID=2 AND Member='@${FIRST_DOMAIN}' AND Disabled=0) LIMIT 1;
DELETE FROM greylisting_whitelist WHERE Comment='${HOSTNAME}';
EOF

 # Add whitelist
 for i in $IP_ADDRESS; do
     cat >> ${tmp_sql} <<EOF
INSERT INTO greylisting_whitelist (Source, Comment, Disabled) VALUES ("SenderIP:$i", '${HOSTNAME}', 0) ON DUPLICATE KEY UPDATE Comment='${HOSTNAME}';
EOF
done

    # Delete testing policy and samples.
    cat >> ${tmp_sql} <<EOF
-- Delete default sample policy group members.
DELETE FROM policy_group_members WHERE Member IN ('@example.org', '@example.com');

-- Delete test policy.
DELETE FROM quotas_limits;
DELETE FROM quotas;
DELETE FROM policy_members WHERE policyid=5;
DELETE FROM policies WHERE id=5;
EOF

    # Add necessary records for white/blacklists
    cat ${SAMPLE_DIR}/cluebringer/extra.sql >> ${tmp_sql}
    # Add greylisting-whitelist for big ISPs.
    cat ${SAMPLE_DIR}/cluebringer/greylisting-whitelist.sql >> ${tmp_sql}

    # Initial cluebringer db.
    # Enable greylisting on all inbound emails by default.

    perl -pi -e 's#TYPE=#ENGINE=#g' ${tmp_sql}

    ${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${tmp_sql};
SOURCE ${SAMPLE_DIR}/cluebringer/column_character_set.mysql;
EOF


    rm -f ${tmp_sql} 2>/dev/null
    unset tmp_sql

    # Set correct permission.
    chown ${CLUEBRINGER_USER}:${CLUEBRINGER_GROUP} ${CLUEBRINGER_CONF}
    chmod 0700 ${CLUEBRINGER_CONF}

    if [ X"${CLUEBRINGER_SEPARATE_LOG}" == X"YES" ]; then
        echo -e "local1.*\t\t\t\t\t\t-${CLUEBRINGER_LOG_FILE}" >> ${SYSLOG_CONF}
        cat > ${CLUEBRINGER_LOGROTATE_FILE} <<EOF
${CONF_MSG}
${AMAVISD_LOGFILE} {
    compress
    weekly
    rotate 10
    create 0600 amavis amavis
    missingok

    # Use bzip2 for compress.
    compresscmd $(which bzip2)
    uncompresscmd $(which bunzip2)
    compressoptions -9
    compressext .bz2

    postrotate
        ${SYSLOG_POSTROTATE_CMD}
    endscript
}
EOF
    fi

    # Add postfix alias.
    add_postfix_alias ${CLUEBRINGER_USER} ${SYS_ROOT_USER}

    # Add cron job
    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: Cleanup Cluebringer database
1   3   *   *   *   ${CLUEBRINGER_BIN_CBPADMIN} --config=${CLUEBRINGER_CONF} --cleanup >/dev/null
EOF
    # Tips.
    cat >> ${TIP_FILE} <<EOF
Policyd (cluebringer):
    * Web UI:
        - URL: httpS://${HOSTNAME}/cluebringer/
        - Username: ${FIRST_USER}@${FIRST_DOMAIN}
        - Password: ${FIRST_USER_PASSWD_PLAIN}
    * Configuration files:
        - ${CLUEBRINGER_CONF}
        - ${CLUEBRINGER_WEBUI_CONF}
    * RC script:
        - ${CLUEBRINGER_RC_SCRIPT}
    * Database:
        - Database name: ${CLUEBRINGER_DB_NAME}
        - Database user: ${CLUEBRINGER_DB_USER}
        - Database password: ${CLUEBRINGER_DB_PASSWD}

EOF

    if [ X"${CLUEBRINGER_SEPARATE_LOG}" == X"YES" ]; then
        cat >> ${TIP_FILE} <<EOF
    * Log file:
        - ${SYSLOG_CONF}
        - ${CLUEBRINGER_LOGFILE}

EOF
    else
        echo -e '\n' >> ${TIP_FILE}
    fi

    echo 'export status_cluebringer_config="DONE"' >> ${STATUS_FILE}
}

cluebringer_webui_config()
{
    ECHO_DEBUG "Configure webui of Policyd (cluebringer)."

    backup_file ${CLUEBRINGER_WEBUI_CONF}

    # Make Cluebringer accessible via HTTPS.
    perl -pi -e 's#^(\s*</VirtualHost>)#Alias /cluebringer "$ENV{CLUEBRINGER_HTTPD_ROOT}/"\n${1}#' ${HTTPD_SSL_CONF}

    # Configure webui.
    perl -pi -e 's#(.DB_DSN=).*#${1}"mysql:host=$ENV{SQL_SERVER};dbname=$ENV{CLUEBRINGER_DB_NAME}";#' ${CLUEBRINGER_WEBUI_CONF}

    perl -pi -e 's#(.DB_USER=).*#${1}"$ENV{CLUEBRINGER_DB_USER}";#' ${CLUEBRINGER_WEBUI_CONF}
    perl -pi -e 's/.*(.DB_PASS=).*/${1}"$ENV{CLUEBRINGER_DB_PASSWD}";/' ${CLUEBRINGER_WEBUI_CONF}
    perl -pi -e 's#(.DB_PASS=).*#${1}"$ENV{CLUEBRINGER_DB_PASSWD}";#' ${CLUEBRINGER_WEBUI_CONF}

    cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
${CONF_MSG}
#
# SECURITY WARNING:
#
# Since libapache2-mod-auth-mysql doesn't support advance SQL query, both
# global admins and normal domain admins are able to login to this webui.

# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.

<Directory ${CLUEBRINGER_HTTPD_ROOT}/>
    DirectoryIndex index.php
    AuthType basic
    AuthName "Authorization Required"
EOF

    ECHO_DEBUG "Setup user auth for cluebringer webui: ${CLUEBRINGER_HTTPD_CONF}."


    # Use mod_auth_mysql.
    cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
AuthMYSQLEnable On
AuthMySQLHost ${SQL_SERVER}
AuthMySQLPort ${SQL_SERVER_PORT}
AuthMySQLUser ${VMAIL_DB_ADMIN_USER}
AuthMySQLPassword ${VMAIL_DB_ADMIN_PASSWD}
AuthMySQLDB ${VMAIL_DB}
AuthMySQLUserTable mailbox
AuthMySQLNameField username
AuthMySQLPasswordField password
EOF


# END BACKEND

        # Close <Directory> container.
        cat >> ${CLUEBRINGER_HTTPD_CONF} <<EOF
    Order allow,deny
    Allow from all
    Require valid-user
</Directory>
EOF

    echo 'export status_cluebringer_webui_config="DONE"' >> ${STATUS_FILE}
}

