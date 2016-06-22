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
# ---------------- Apache & PHP -------------------------
# -------------------------------------------------------

apache_config()
{
    ECHO_INFO "Configure Apache web server and PHP."

    backup_file ${HTTPD_CONF} ${HTTPD_SSL_CONF}

    # --------------------------
    # Apache Setting.
    # --------------------------
    ECHO_DEBUG "Basic configurations."
    perl -pi -e 's#^(ServerTokens).*#${1} ProductOnly#' ${HTTPD_CONF}
    perl -pi -e 's#^(ServerSignature).*#${1} EMail#' ${HTTPD_CONF}
    perl -pi -e 's#^(LogLevel).*#${1} warn#' ${HTTPD_CONF}


    ############
    # SSL
    #
    # Disable SSLv3
    echo '# Disable SSLv3' >> ${HTTPD_CONF}
    echo 'SSLProtocol all -SSLv2 -SSLv3' >> ${HTTPD_CONF}

    perl -pi -e 's#^(SSLCipherSuite).*#${1} $ENV{SSL_CIPHERS}#g' ${HTTPD_SSL_CONF}
    perl -pi -e 's#^(SSLCipherSuite.*)#${1}\nSSLHonorCipherOrder on#g' ${HTTPD_SSL_CONF}

    ECHO_DEBUG "Set correct SSL Cert/Key file location."
    perl -pi -e 's#^(SSLCertificateFile)(.*)#${1} $ENV{SSL_CERT_FILE}#' ${HTTPD_SSL_CONF}
    perl -pi -e 's#^(SSLCertificateKeyFile)(.*)#${1} $ENV{SSL_KEY_FILE}#' ${HTTPD_SSL_CONF}
    perl -pi -e 's|#SSLCACertificateFile.*|SSLCACertificateFile $ENV{SSL_CA_BUNDLE_FILE}|' ${HTTPD_SSL_CONF}

      
     cat >> ${TIP_FILE} <<EOF
Apache:
    * Configuration files:
        - ${HTTPD_CONF_ROOT}
        - ${HTTPD_CONF}
        - ${HTTPD_CONF_DIR}/*
    * Directories:
        - ${HTTPD_SERVERROOT}
        - ${HTTPD_DOCUMENTROOT}
    * See also:
        - ${HTTPD_DOCUMENTROOT}/index.html
EOF

    echo 'export status_apache_php_config="DONE"' >> ${STATUS_FILE}
}