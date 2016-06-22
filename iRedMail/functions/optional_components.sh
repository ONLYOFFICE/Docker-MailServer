#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# -------------------------------------------
# Install all optional components.
# -------------------------------------------
optional_components()
{

    # OpenDkim.
    if  [ X"${CONFIGURATION_ONLY}" != X"YES" ]; then  
        check_status_before_run opendkim_install 
    fi
    check_status_before_run opendkim_config

    # Fail2ban.
    if [ X"${CONFIGURATION_ONLY}" != X"YES" ]; then
        check_status_before_run fail2ban_install 
    fi
    check_status_before_run fail2ban_config

    # ServerAPI.
    if [ X"${CONFIGURATION_ONLY}" != X"YES" ]; then
        check_status_before_run server_api_install
    fi
    check_status_before_run server_api_config

    # SpamTrainer.
    if [ X"${CONFIGURATION_ONLY}" != X"YES" ]; then 
        check_status_before_run spam_trainer_install
    fi
    check_status_before_run spam_trainer_config

    # Awstats.
    [ X"${USE_AWSTATS}" == X"YES" -a X"${WEB_SERVER_IS_APACHE}" == X'YES' ] && \
        check_status_before_run awstats_config_basic && \
        check_status_before_run awstats_config_weblog && \
        check_status_before_run awstats_config_maillog && \
        check_status_before_run awstats_config_crontab
}