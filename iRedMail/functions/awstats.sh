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

awstats_config_basic()
{
    ECHO_INFO "Configure Awstats (logfile analyzer for mail and web server)."
    [ -f ${AWSTATS_CONF_SAMPLE} ] && dos2unix ${AWSTATS_CONF_SAMPLE} &>/dev/null

    ECHO_DEBUG "Generate apache config file for awstats: ${AWSTATS_HTTPD_CONF}."
    backup_file ${AWSTATS_HTTPD_CONF}


    cat >| ${AWSTATS_HTTPD_CONF} <<EOF
${CONF_MSG}
# Note: Please refer to ${HTTPD_SSL_CONF} for SSL/TLS setting.
#Alias /awstats/icon "${AWSTATS_ICON_DIR}/"
#Alias /awstats/css "${AWSTATS_CSS_DIR}/"
#Alias /awstats/js "${AWSTATS_JS_DIR}/"
#ScriptAlias /awstats "${AWSTATS_CGI_DIR}/"

<Directory ${AWSTATS_CGI_DIR}/>
    DirectoryIndex awstats.pl
    Options ExecCGI

    AuthName "Authorization Required"
    AuthType Basic
EOF

    ECHO_DEBUG "Setup user auth for awstats: ${AWSTATS_HTTPD_CONF}."
    # Use mod_auth_mysql.

    cat >> ${AWSTATS_HTTPD_CONF} <<EOF
AuthMYSQLEnable On
AuthMySQLHost ${SQL_SERVER}
AuthMySQLPort ${SQL_SERVER_PORT}
AuthMySQLUser ${VMAIL_DB_ADMIN_USER}
AuthMySQLPassword ${VMAIL_DB_ADMIN_PASSWD}
AuthMySQLDB ${VMAIL_DB}
AuthMySQLUserTable mailbox
AuthMySQLNameField username
AuthMySQLPasswordField password
AuthMySQLUserCondition "isglobaladmin=1"
EOF


    # Close <Directory> container.
    cat >> ${AWSTATS_HTTPD_CONF} <<EOF
    ${HTACCESS_ALLOW_ALL}
    Require valid-user
</Directory>
EOF

    # Make Awstats accessible via HTTPS.
   if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /awstats/icon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(\s*</VirtualHost>)#Alias /awstatsicon "$ENV{AWSTATS_ICON_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
        perl -pi -e 's#^(\s*</VirtualHost>)#ScriptAlias /awstats "$ENV{AWSTATS_CGI_DIR}/"\n${1}#' ${HTTPD_SSL_CONF}
    fi

    # Enable authn_dbd under Apache 2.4
    if [ X"${APACHE_VERSION}" == X'2.4' ]; then

        cp ${SAMPLE_DIR}/apache/awstats.conf ${AWSTATS_HTTPD_CONF}

        perl -pi -e 's#PH_DB_DRIVER#mysql#' ${AWSTATS_HTTPD_CONF}
        
        perl -pi -e 's#PH_DIRECTORY#$ENV{AWSTATS_CGI_DIR}#' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_SQL_SERVER#$ENV{SQL_SERVER}#' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_SQL_SERVER_PORT#$ENV{SQL_SERVER_PORT}#' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_SQL_DB_NAME#$ENV{VMAIL_DB}#' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_SQL_DB_USER#$ENV{VMAIL_DB_BIND_USER}#' ${AWSTATS_HTTPD_CONF}
        perl -pi -e 's#PH_SQL_DB_PASSWORD#$ENV{VMAIL_DB_BIND_PASSWD}#' ${AWSTATS_HTTPD_CONF}

        perl -pi -e 's/^(Auth_MySQL_.*)//g' ${HTTPD_CONF}        
    fi


    cat >> ${TIP_FILE} <<EOF
Awstats:
    * Configuration files:
        - ${AWSTATS_CONF_DIR}
        - ${AWSTATS_CONF_WEB}
        - ${AWSTATS_CONF_MAIL}
        - ${AWSTATS_HTTPD_CONF}
    * Login account:
        - Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}, password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * URL:
        - https://${HOSTNAME}/awstats/awstats.pl
        - https://${HOSTNAME}/awstats/awstats.pl?config=web
        - https://${HOSTNAME}/awstats/awstats.pl?config=smtp
    * Crontab job:
        shell> crontab -l root

EOF

    echo 'export status_awstats_config_basic="DONE"' >> ${STATUS_FILE}
}

awstats_config_weblog()
{
    ECHO_DEBUG "Config awstats to analyze apache web access log: ${AWSTATS_CONF_WEB}."
    cd ${AWSTATS_CONF_DIR}
    cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_WEB}

    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"$ENV{HOSTNAME}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"$ENV{HTTPD_LOG_ACCESSLOG}"#' ${AWSTATS_CONF_WEB}
    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_WEB}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_WEB}

    # On RHEL/CentOS/Debian, ${AWSTATS_CONF_SAMPLE} is default config file. Overrided here.
    backup_file ${AWSTATS_CONF_SAMPLE}
    cp -f ${AWSTATS_CONF_WEB} ${AWSTATS_CONF_SAMPLE}

    echo 'export status_awstats_config_weblog="DONE"' >> ${STATUS_FILE}
}

awstats_config_maillog()
{
    ECHO_DEBUG "Config awstats to analyze postfix mail log: ${AWSTATS_CONF_MAIL}."

    cd ${AWSTATS_CONF_DIR}

    # Create a default config file.
    cp -f ${AWSTATS_CONF_SAMPLE} ${AWSTATS_CONF_MAIL}
    cp -f ${AWSTATS_CONF_MAIL} ${AWSTATS_CONF_DIR}/awstats.conf


    export maillogconvert_pl="$( eval ${LIST_FILES_IN_PKG} awstats | grep 'maillogconvert.pl')"


    perl -pi -e 's#^(SiteDomain=)(.*)#${1}"mail"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFile=)(.*)#${1}"perl $ENV{maillogconvert_pl} standard < $ENV{MAILLOG} |"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogType=)(.*)#${1}M#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LogFormat=)(.*)#${1}"%time2 %email %email_r %host %host_r %method %url %code %bytesd"#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForBrowsersDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForOSDetection=)(.*)#${1}0##' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRefererAnalyze=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForRobotsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForWormsDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForSearchEnginesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(LevelForFileTypesDetection=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDomainsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowAuthenticatedUsers=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowRobotsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSessionsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowPagesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileTypesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowFileSizesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowBrowsersStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOSStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowOriginStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeyphrasesStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowKeywordsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMiscStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHTTPErrorsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDownloadsStats=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowLinksOnUrl=)(.*)#${1}0#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(ShowMenu=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSummary=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfMonthStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowDaysOfWeekStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHoursStats=)(.*)#${1}HB#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowSMTPErrorsStats=)(.*)#${1}1#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowHostsStats=)(.*)#${1}HBL#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailSenders=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}
    perl -pi -e 's#^(ShowEMailReceivers=)(.*)#${1}HBML#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(Lang=)(.*)#${1}$ENV{AWSTATS_LANGUAGE}#' ${AWSTATS_CONF_MAIL}

    perl -pi -e 's#^(DirIcons=)(.*)#${1}"/awstats/icon#' ${AWSTATS_CONF_MAIL}

    echo 'export status_awstats_config_maillog="DONE"' >> ${STATUS_FILE}
}

awstats_config_crontab()
{
    ECHO_DEBUG "Setting cronjob for awstats."

    cat >> ${CRON_SPOOL_DIR}/root <<EOF
# ${PROG_NAME}: update Awstats statistics for web
1   */1   *   *   *   perl ${AWSTATS_CGI_DIR}/awstats.pl -config=web -update >/dev/null
# ${PROG_NAME}: update Awstats statistics for smtp
1   */1   *   *   *   perl ${AWSTATS_CGI_DIR}/awstats.pl -config=smtp -update >/dev/null
EOF

    echo 'export status_awstats_config_crontab="DONE"' >> ${STATUS_FILE}
}

