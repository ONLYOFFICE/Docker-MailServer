fail2ban_install()
{
    ECHO_INFO "Install Fail2ban (authentication failure monitor)."

    # Extract source tarball.
    tar zxf ${PKG_DIR}/${FAIL2BAN_TARBALL} -C ${PKG_DIR}

    cd ${PKG_DIR}/${FAIL2BAN_SOURCE_DIR}

    python setup.py install


    # Create directories
    mkdir -p ${FAIL2BAN_SOCK_DIR}


    # Copy sample config files.
    cp ${PKG_DIR}/${FAIL2BAN_SOURCE_DIR}/files/redhat-initd /etc/init.d/fail2ban
    chmod u+x,g+x,o+x /etc/init.d/fail2ban

    echo 'export status_fail2ban_install="DONE"' >> ${STATUS_FILE}
}


fail2ban_config()
{
    ECHO_INFO "Configure Fail2ban (authentication failure monitor)."

    cp ${FAIL2BAN_SAMPLE_LOCAL_CF} /etc/fail2ban/jail.local
    cp -rf ${FAIL2BAN_SAMPLE_POSTFIX_CF} /etc/fail2ban/filter.d/postfix.conf
    cp -rf ${FAIL2BAN_SAMPLE_IPTABLE_CF} /etc/fail2ban/action.d/iptables-multiport.conf
    cp ${FAIL2BAN_SAMPLE_LOGROTATE_CF} /etc/logrotate.d/fail2ban    

    # get gateway ip
    gateway_ip=$(/sbin/ip route|awk '/default/ { print $3 }')

    sed -i 's/ignoreip = 127.0.0.1\/8/ignoreip = 127.0.0.1\/8 onlyoffice-community-server '$gateway_ip'/' /etc/fail2ban/jail.conf

    fail2ban-client reload &>/dev/null

    service_control enable 'fail2ban' >> ${INSTALL_LOG} 2>&1

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}