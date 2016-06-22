#!/usr/bin/env bash

# Author: Zhang Huangbin <zhb _at_ iredmail.org>

# Add required system accounts

add_user_vmail()
{
    ECHO_DEBUG "Create HOME folder for vmail user."

    homedir="$(dirname $(echo ${VMAIL_USER_HOME_DIR} | sed 's#/$##'))"
    [ -L ${homedir} ] && rm -f ${homedir}
    [ -d ${homedir} ] || mkdir -p ${homedir}
    [ -d ${STORAGE_MAILBOX_DIR} ] || mkdir -p ${STORAGE_MAILBOX_DIR}

    ECHO_DEBUG "Create system account: ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} (${VMAIL_USER_UID}:${VMAIL_USER_GID})."

    # vmail/vmail must has the same UID/GID on all supported Linux/BSD
    # distributions, required by cluster environment. e.g. GlusterFS.   
    groupadd -g ${VMAIL_USER_GID} ${VMAIL_GROUP_NAME} >> ${INSTALL_LOG} 2>&1
    useradd -m \
        -u ${VMAIL_USER_UID} \
        -g ${VMAIL_GROUP_NAME} \
        -s ${SHELL_NOLOGIN} \
        -d ${VMAIL_USER_HOME_DIR} \
        ${VMAIL_USER_NAME} >> ${INSTALL_LOG} 2>&1

    rm -f ${VMAIL_USER_HOME_DIR}/.* >> ${INSTALL_LOG} 2>&1

    export FIRST_USER_MAILDIR_HASH_PART="$(hash_domain ${FIRST_DOMAIN})/$(hash_maildir ${FIRST_USER})"
    export FIRST_USER_MAILDIR_FULL_PATH="${STORAGE_MAILBOX_DIR}/${FIRST_USER_MAILDIR_HASH_PART}"
    # Create maildir.
    # We will deliver emails with sensitive info of iRedMail installation
    # to postmaster immediately after installation completed.
    # NOTE: 'Maildir/' is appended by Dovecot (defined in dovecot.conf).
    export FIRST_USER_MAILDIR_INBOX="${FIRST_USER_MAILDIR_FULL_PATH}/Maildir/new"
    mkdir -p ${FIRST_USER_MAILDIR_INBOX} >> ${INSTALL_LOG} 2>&1

    # Reset permission for home directory. Required by FIRST_USER_MAILDIR_FULL_PATH.
    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${VMAIL_USER_HOME_DIR}
    chmod -R 0700 ${VMAIL_USER_HOME_DIR}

    ECHO_DEBUG "Create directory to store user sieve rule files: ${SIEVE_DIR}."
    mkdir -p ${SIEVE_DIR} && \
    chown -R ${VMAIL_USER_NAME}:${VMAIL_GROUP_NAME} ${SIEVE_DIR} && \
    chmod -R 0700 ${SIEVE_DIR}

    cat >> ${TIP_FILE} <<EOF
Mail Storage:
    - Root directory: ${VMAIL_USER_HOME_DIR}
    - Mailboxes: ${STORAGE_MAILBOX_DIR}
    - Backup scripts and copies: ${BACKUP_DIR}

EOF

    echo 'export status_add_user_vmail="DONE"' >> ${STATUS_FILE}
}


add_required_users()
{
    ECHO_INFO "Create required system accounts: vmail, iredapd."
    check_status_before_run add_user_vmail    

    echo 'export status_add_required_users="DONE"' >> ${STATUS_FILE}
}