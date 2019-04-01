#!/usr/bin/env bash

spam_trainer_install()
{
    ECHO_INFO "Install python daemon."

    # Extract source tarball.
    tar zxvf ${PKG_DIR}/${LOCKFILE_TARBALL} -C ${PKG_DIR}
    cd ${PKG_DIR}/${LOCKFILE_NAME}
    python setup.py install

    cd ${SAMPLE_DIR}/spam_trainer
    python ${BOOTSTRAP_PYPA_SETUP}

    tar zxvf ${PKG_DIR}/${PYTHON_DAEMON_TARBALL} -C ${PKG_DIR}
    cd ${PKG_DIR}/${PYTHON_DAEMON_NAME}
    python setup.py install

    echo 'export status_spam_trainer_install="DONE"' >> ${STATUS_FILE}

}

spam_trainer_config()
{
    ECHO_INFO "Configure SpamTrainer."

    # Create directories
    mkdir -p /var/log/spamtrainer
    mkdir /var/run/spamtrainer
    mkdir /usr/share/spamtrainer
    mkdir /usr/share/spamtrainer/spam
    mkdir /usr/share/spamtrainer/ham

    cp ${SPAM_TRAINER_SAMPLE} /usr/share/spamtrainer/spamtrainer.py
    cp ${SPAM_TRAINER_SETTINGS} /usr/share/spamtrainer/settings.py
    cp ${SPAM_TRAINER_START_SCRIPT} /etc/init.d/spamtrainer
    chmod u+x /etc/init.d/spamtrainer    
  
    perl -pi -e "s#(DATABASE_NAME).*=(.*)#DATABASE_NAME = '${VMAIL_DB}'#" /usr/share/spamtrainer/settings.py
    perl -pi -e "s#(DATABASE_USER).*=(.*)#DATABASE_USER = '${VMAIL_DB_ADMIN_USER}'#" /usr/share/spamtrainer/settings.py    
    perl -pi -e "s#(DATABASE_PASSWORD).*=(.*)#DATABASE_PASSWORD = '${VMAIL_DB_ADMIN_PASSWD}'#" /usr/share/spamtrainer/settings.py
    perl -pi -e "s#(DATABASE_HOST).*=(.*)#DATABASE_HOST = '${MYSQL_SERVER}'#" /usr/share/spamtrainer/settings.py

    service_control enable 'spamtrainer' >> ${INSTALL_LOG} 2>&1

    echo 'export status_spam_trainer_config="DONE"' >> ${STATUS_FILE}
    
}