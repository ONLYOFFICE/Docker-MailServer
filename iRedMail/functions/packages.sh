#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

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

install_all()
{
    ALL_PKGS=''
    ENABLED_SERVICES=''
    DISABLED_SERVICES=''

    # Enable syslog or rsyslog.

    # RHEL/CENTOS/Scientific
    ENABLED_SERVICES="rsyslog ${ENABLED_SERVICES}"
    DISABLED_SERVICES="${DISABLED_SERVICES} exim"
    
    # Postfix.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${POSTFIX_RC_SCRIPT_NAME}"
    ALL_PKGS="${ALL_PKGS} postfix"


    # Backend: OpenLDAP, MySQL, PGSQL and extra packages.
    # MySQL server & client.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${MYSQL_RC_SCRIPT_NAME}"

    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
        [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql-server"
        [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb-server"
    fi

    # Client
    [ X"${BACKEND_ORIG}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} mysql"
    [ X"${BACKEND_ORIG}" == X'MARIADB' ] && ALL_PKGS="${ALL_PKGS} mariadb"

    # Perl module
    ALL_PKGS="${ALL_PKGS} perl-DBD-MySQL"

    if [ X"${USE_AWSTATS}" == X'YES' -o X"${USE_CLUEBRINGER}" == X'YES' ]; then
        if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
            if [ X"${DISTRO_VERSION}" == X'6' ]; then
                ALL_PKGS="${ALL_PKGS} mod_auth_mysql"
            else
                ALL_PKGS="${ALL_PKGS} apr-util-mysql"
            fi
        fi
    fi


    # PHP.
    ALL_PKGS="${ALL_PKGS} php-common php-gd php-xml php-mysql php-ldap php-pgsql php-imap php-mbstring php-pecl-apc php-intl php-mcrypt"
    [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ] && ALL_PKGS="${ALL_PKGS} php"

    # Apache. Always install Apache.
    if [ X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} httpd mod_ssl"
    fi
    
    # Nginx
    if [ X"${WEB_SERVER_IS_NGINX}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} nginx php-fpm"
    fi

    if [ X"${WEB_SERVER_IS_NGINX}" == X'YES' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME} ${UWSGI_RC_SCRIPT_NAME}"
        DISABLED_SERVICES="${DISABLED_SERVICES} ${APACHE_RC_SCRIPT_NAME}"
    else
        ENABLED_SERVICES="${ENABLED_SERVICES} ${APACHE_RC_SCRIPT_NAME}"
        DISABLED_SERVICES="${DISABLED_SERVICES} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME} ${UWSGI_RC_SCRIPT_NAME}"
    fi

    # Cluebringer
    if [ X"${USE_CLUEBRINGER}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} cluebringer"
        ENABLED_SERVICES="${ENABLED_SERVICES} ${CLUEBRINGER_RC_SCRIPT_NAME}"
    fi    

    # Dovecot.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${DOVECOT_RC_SCRIPT_NAME}"
    ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"

    if [ X"${DISTRO_VERSION}" == X'6' ]; then
        ALL_PKGS="${ALL_PKGS} dovecot-managesieve"
    else
        ALL_PKGS="${ALL_PKGS} dovecot-mysql"
    fi

    # We use Dovecot SASL auth instead of saslauthd
    DISABLED_SERVICES="${DISABLED_SERVICES} saslauthd"
   

    # Amavisd-new & ClamAV & Altermime.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_CLAMD_RC_SCRIPT_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    if [ X"${DISTRO_VERSION}" == X'6' ]; then
        ALL_PKGS="${ALL_PKGS} amavisd-new clamd clamav-db spamassassin altermime perl-LDAP perl-Mail-SPF unrar"
        ENABLED_SERVICES="${ENABLED_SERVICES} clamd.amavisd"
    else
        ALL_PKGS="${ALL_PKGS} clamav clamav-update clamav-server clamav-server-systemd amavisd-new spamassassin altermime perl-LDAP perl-Mail-SPF unrar"
        ENABLED_SERVICES="${ENABLED_SERVICES} clamd@amavisd"
    fi

    DISABLED_SERVICES="${DISABLED_SERVICES} spamassassin"
   
    ############
    # iRedAPD.
    #
    # Don't append 'iredapd' to ${ENABLED_SERVICES} since we don't have
    # RC script ready in early stage.

    ALL_PKGS="${ALL_PKGS} python-sqlalchemy python-setuptools"
    ALL_PKGS="${ALL_PKGS} MySQL-python"
   

    #############
    # Awstats.
    #
    if [ X"${USE_AWSTATS}" == X'YES' -a X"${WEB_SERVER_IS_APACHE}" == X'YES' ]; then
        ALL_PKGS="${ALL_PKGS} awstats"
    fi


    #############
    # OpenDkim
    #
    ALL_PKGS="${ALL_PKGS} libopendkim libopendkim-devel mysql-devel readline-devel gcc gcc-c++ sendmail-milter.x86_64 sendmail-devel libbsd-devel"

    #############
    # ServerApi
    #
    ALL_PKGS="${ALL_PKGS} gcc-c++ readline"
    ALL_PKGS="${ALL_PKGS} libyaml-devel libffi-devel openssl-devel libtool"
    ALL_PKGS="${ALL_PKGS} bison curl-devel httpd-devel sqlite-devel which"
    
    ############################
    # Misc packages & services.
    #
    ALL_PKGS="${ALL_PKGS} unzip bzip2 acl patch tmpwatch crontabs dos2unix logwatch"
    ENABLED_SERVICES="${ENABLED_SERVICES} crond"
    
    export ALL_PKGS ENABLED_SERVICES

    # Install all packages.
    install_all_pkgs()
    {   
        eval ${install_pkg} ${ALL_PKGS} | tee ${INSTALL_LOG}  

        if [ -f ${RUNTIME_DIR}/.pkg_install_failed ]; then
            ECHO_ERROR "Installation failed, please check the terminal output."
            ECHO_ERROR "If you're not sure what the problem is, try to get help in iRedMail"
            ECHO_ERROR "forum: http://www.iredmail.org/forum/"
            exit 255
        else
            echo 'export status_install_all_pkgs="DONE"' >> ${STATUS_FILE}
        fi
    }

    # Enable/Disable services.
    enable_all_services()
    {
        if [ -f /usr/lib/systemd/system/clamd\@.service ]; then
            if ! grep '\[Install\]' /usr/lib/systemd/system/clamd\@.service &>/dev/null; then
                echo '[Install]' >> /usr/lib/systemd/system/clamd\@.service
                echo 'WantedBy=multi-user.target' >> /usr/lib/systemd/system/clamd\@.service
            fi
        fi

        # Enable/Disable services.
        service_control enable ${ENABLED_SERVICES} >> ${INSTALL_LOG} 2>&1
        service_control disable ${DISABLED_SERVICES} >> ${INSTALL_LOG} 2>&1

        echo 'export status_enable_all_services="DONE"' >> ${STATUS_FILE}
    }

    after_package_installation()
    {
        if [ X"${DISTRO_VERSION}" == X'6' ]; then
            # Copy DNS related libs to chrooted Postfix directory, so that Postfix
            # can correctly resolve IP address under chroot.
            for i in '/lib' '/lib64'; do
                ls $i/*nss* &>/dev/null
                ret1=$?
                ls $i/*reso* &>/dev/null
                ret2=$?

                if [ X"${ret1}" == X'0' -o X"${ret2}" == X'0' ]; then
                    mkdir -p ${POSTFIX_CHROOT_DIR}${i}
                    cp ${i}/*nss* ${i}/*reso* ${POSTFIX_CHROOT_DIR}${i}/ &>/dev/null
                fi
            done
        fi

        echo 'export status_after_package_installation="DONE"' >> ${STATUS_FILE}
    }
    
    if [ X"${CONFIGURATION_ONLY}" != X"YES" ]; then 
        check_status_before_run install_all_pkgs
    fi
    check_status_before_run enable_all_services
    check_status_before_run after_package_installation

    echo 'export status_install_all="DONE"' >> ${STATUS_FILE}
}