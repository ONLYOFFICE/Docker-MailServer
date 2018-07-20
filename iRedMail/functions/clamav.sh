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

# --------------------------------------------
# ClamAV.
# --------------------------------------------

clamav_config()
{
    ECHO_INFO "Configure ClamAV (anti-virus toolkit)."
    backup_file ${CLAMD_CONF} ${FRESHCLAM_CONF}

    [ -f ${FRESHCLAM_CONF} ] && perl -pi -e 's#^Example##' ${FRESHCLAM_CONF}

    export CLAMD_LOCAL_SOCKET CLAMD_BIND_HOST
    ECHO_DEBUG "Configure ClamAV: ${CLAMD_CONF}."
    perl -pi -e 's#^Example##'  ${CLAMD_CONF}
    perl -pi -e 's/^#(LogTime ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(LogSyslog ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(PidFile ).*/${1}$ENV{CLAMD_PID_FILE}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(DatabaseDirectory ).*/${1}$ENV{CLAMD_DB_DIRECTORY}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(MaxThreads ).*/${1}20/' ${CLAMD_CONF}
    perl -pi -e 's/^#(ReadTimeout ).*/${1}300/' ${CLAMD_CONF}
    perl -pi -e 's/^#(User ).*/${1}$ENV{CLAMAV_USER}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(AllowSupplementaryGroups ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(ScanPE ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(ScanELF ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(DetectBrokenExecutables ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(ScanOLE2 ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^#(ScanMail ).*/${1}yes/' ${CLAMD_CONF}
    perl -pi -e 's/^(TCPSocket .*)/#${1}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(TCPAddr ).*/${1} $ENV{CLAMD_BIND_HOST}/' ${CLAMD_CONF}

    # Disable log file
    perl -pi -e 's/^(LogFile.*)/#${1}/' ${CLAMD_CONF}

    # Set CLAMD_LOCAL_SOCKET
    perl -pi -e 's/^(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}

    ECHO_DEBUG "Configure freshclam: ${FRESHCLAM_CONF}."
    perl -pi -e 's#^(UpdateLogFile ).*#${1}$ENV{FRESHCLAM_LOGFILE}#' ${FRESHCLAM_CONF}
    perl -pi -e 's/^#(UpdateLogFile ).*/${1}$ENV{FRESHCLAM_LOGFILE}/' ${FRESHCLAM_CONF}
    perl -pi -e 's/^#(DatabaseDirectory ).*/${1}$ENV{CLAMD_DB_DIRECTORY}/' ${FRESHCLAM_CONF}
    perl -pi -e 's/^#(LogSyslog ).*/${1}yes/' ${FRESHCLAM_CONF}
    perl -pi -e 's/^#(DatabaseOwner ).*/${1}$ENV{CLAMAV_USER}/' ${FRESHCLAM_CONF}

    # Official database only
    perl -pi -e 's/^#(OfficialDatabaseOnly ).*/${1} yes/' ${CLAMD_CONF}

    ECHO_DEBUG "Add clamav user to amavid group."
    usermod ${CLAMAV_USER} -G ${AMAVISD_SYS_GROUP}

    ECHO_DEBUG "Set permission to 750: ${AMAVISD_TEMPDIR}, ${AMAVISD_QUARANTINEDIR},"
    chmod -R 750 ${AMAVISD_TEMPDIR} ${AMAVISD_QUARANTINEDIR}

    mkdir -p ${CLAMD_LOGDIR} &>/dev/null && \
    chmod -R 750 ${CLAMD_LOGDIR} &>/dev/null && \
    chown -R ${CLAMAV_USER}:${CLAMAV_GROUP} ${CLAMD_LOGDIR}

    if [ X"${DISTRO_VERSION}" == X'7' ]; then
        # Enable freshclam
        perl -pi -e 's/^(FRESHCLAM_DELAY.*)/#${1}/g' ${ETC_SYSCONFIG_DIR}/freshclam
    fi

    # Add user alias in Postfix
    add_postfix_alias ${CLAMAV_USER} ${SYS_ROOT_USER}

    cat >> ${TIP_FILE} <<EOF
ClamAV:
    * Configuration files:
        - ${CLAMD_CONF}
        - ${FRESHCLAM_CONF}
        - /etc/logrotate.d/clamav
    * RC scripts:
            + ${DIR_RC_SCRIPTS}/${CLAMAV_CLAMD_RC_SCRIPT_NAME}
            + ${DIR_RC_SCRIPTS}/${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME}
    * Log files:
        - ${CLAMD_LOGFILE}
        - ${FRESHCLAM_LOGFILE}

EOF

    echo 'export status_clamav_config="DONE"' >> ${STATUS_FILE}
}
