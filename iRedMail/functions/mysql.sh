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

# Please refer another file: functions/backend.sh

# -------------------------------------------------------
# -------------------- MySQL ----------------------------
# -------------------------------------------------------
mysql_generate_defaults_file_root()
{
    if [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
        ECHO_INFO "Configure MariaDB database server."
    else
        ECHO_INFO "Configure MySQL database server."
    fi

    ECHO_DEBUG "Generate temporary defaults file for MySQL client option --defaults-file: ${MYSQL_DEFAULTS_FILE_ROOT}."
    cat >> ${MYSQL_DEFAULTS_FILE_ROOT} <<EOF
[client]
host=${MYSQL_SERVER}
port=${MYSQL_SERVER_PORT}
user=${MYSQL_ROOT_USER}
password=${MYSQL_ROOT_PASSWD}
EOF
}

mysql_password_refresh()
{
    service_control stop ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    mysqld_safe --skip-grant-tables --user=root & >> ${INSTALL_LOG} 2>&1
    ECHO_DEBUG "Sleep 5 seconds for safe MySQL daemon initialization ..."
    sleep 5

    ECHO_DEBUG "Setting password for MySQL admin (${MYSQL_ROOT_USER})."
    mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWD}') WHERE User='root';
FLUSH PRIVILEGES;
EOF

    service_control restart ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1
}

mysql_initialize()
{
    ECHO_DEBUG "Starting MySQL."

    backup_file ${MYSQL_MY_CNF}


    if [ ! -f ${MYSQL_MY_CNF} ]; then
        ECHO_DEBUG "Copy sample MySQL config file: ${SAMPLE_DIR}/mysql/my.cnf -> ${MYSQL_MY_CNF}."
        cp ${SAMPLE_DIR}/mysql/my.cnf ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    # Disable 'skip-networking' in my.cnf.
    perl -pi -e 's#^(skip-networking.*)#${1}#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1

    # Enable innodb_file_per_table by default.
    grep '^innodb_file_per_table' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    if [ X"$?" != X'0' ]; then
        perl -pi -e 's#^(\[mysqld\])#${1}\ninnodb_file_per_table#' ${MYSQL_MY_CNF} >> ${INSTALL_LOG} 2>&1
    fi

    service_control restart ${MYSQL_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 5 seconds for MySQL daemon initialization ..."
    sleep 5

    if [ X"${LOCAL_ADDRESS}" == X'127.0.0.1' ]; then
        # Try to access without password, set a password if it's empty.
        mysql -u${MYSQL_ROOT_USER} -e "show databases" >> ${INSTALL_LOG} 2>&1
        if [ X"$?" == X'0' ]; then
            ECHO_DEBUG "Setting password for MySQL admin (${MYSQL_ROOT_USER})."
            mysqladmin --user=root password "${MYSQL_ROOT_PASSWD}"
        else
            mysql_password_refresh
        fi
    else 
		if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
			ECHO_DEBUG "Grant access privilege to ${MYSQL_ROOT_USER}@${LOCAL_ADDRESS} ..."
			mysql -u${MYSQL_ROOT_USER} <<EOF
USE mysql;
-- Allow access from MYSQL_GRANT_HOST with password
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}';
GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_ROOT_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}';
-- Allow GRANT privilege
UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='${MYSQL_GRANT_HOST}';
UPDATE user SET Grant_priv='Y' WHERE User='${MYSQL_ROOT_USER}' AND Host='127.0.0.1';
-- Set root password
UPDATE user SET Password = PASSWORD('${MYSQL_ROOT_PASSWD}') WHERE User = 'root';
EOF
		fi
	fi

	if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
		echo '' > ${MYSQL_INIT_SQL}
		cat >> ${MYSQL_INIT_SQL} <<EOF
-- Delete anonymouse user.
USE mysql;

DELETE FROM user WHERE User='';
DELETE FROM db WHERE User='';
EOF
	

		ECHO_DEBUG "Initialize MySQL database."
		${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${MYSQL_INIT_SQL};
FLUSH PRIVILEGES;
EOF
	fi

    cat >> ${TIP_FILE} <<EOF
MySQL:
    * Root user: ${MYSQL_ROOT_USER}, Password: ${MYSQL_ROOT_PASSWD}
    * Bind account (read-write):
        - Username: ${MAIL_DB_EXTERNAL_USER}, Password: ${MAIL_DB_EXTERNAL_PASSWD}
    * Vmail admin account (read-write):
        - Username: ${VMAIL_DB_ADMIN_USER}, Password: ${VMAIL_DB_ADMIN_PASSWD}
    * RC script: ${MYSQLD_RC_SCRIPT}
    * See also:
        - ${MYSQL_INIT_SQL}

EOF

    echo 'export status_mysql_initialize="DONE"' >> ${STATUS_FILE}
}

# It's used only when backend is MySQL.
mysql_import_vmail_users()
{
    ECHO_DEBUG "Generating SQL template for postfix virtual hosts: ${MYSQL_VMAIL_SQL}."
    export DOMAIN_ADMIN_PASSWD="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${DOMAIN_ADMIN_PASSWD})"
    export FIRST_USER_PASSWD="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${FIRST_USER_PASSWD})"

    # Generate SQL.
    # Modify default SQL template, set storagebasedirectory.
    perl -pi -e 's#(.*storagebasedirectory.*DEFAULT).*#${1} "$ENV{STORAGE_BASE_DIR}",#' ${MYSQL_VMAIL_STRUCTURE_SAMPLE}
    perl -pi -e 's#(.*storagenode.*DEFAULT).*#${1} "$ENV{STORAGE_NODE}",#' ${MYSQL_VMAIL_STRUCTURE_SAMPLE}

    # Mailbox format is 'Maildir/' by default.
    cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Create database for virtual hosts. */
CREATE DATABASE IF NOT EXISTS \`${VMAIL_DB}\` CHARACTER SET utf8;
EOF
    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
        cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Permissions. */
GRANT SELECT,INSERT,DELETE,UPDATE ON ${VMAIL_DB}.* TO "${VMAIL_DB_ADMIN_USER}"@"${MYSQL_GRANT_HOST}" IDENTIFIED BY "${VMAIL_DB_ADMIN_PASSWD}";
EOF
        if [ X"${MAIL_DB_EXTERNAL_GRANT_HOST}" == X'' ]; then
            cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Permissions. */
GRANT SELECT,INSERT,DELETE,UPDATE ON ${VMAIL_DB}.* TO "${MAIL_DB_EXTERNAL_USER}"@"localhost" IDENTIFIED BY "${MAIL_DB_EXTERNAL_PASSWD}";
GRANT SELECT,INSERT,DELETE,UPDATE ON ${VMAIL_DB}.* TO "${MAIL_DB_EXTERNAL_USER}"@"%" IDENTIFIED BY "${MAIL_DB_EXTERNAL_PASSWD}";
EOF
        else
            cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Permissions. */
GRANT SELECT,INSERT,DELETE,UPDATE ON ${VMAIL_DB}.* TO "${MAIL_DB_EXTERNAL_USER}"@"${MAIL_DB_EXTERNAL_GRANT_HOST}" IDENTIFIED BY "${MAIL_DB_EXTERNAL_PASSWD}";
EOF
        fi
    fi
    
    cat >> ${MYSQL_VMAIL_SQL} <<EOF
/* Initialize the database. */
USE ${VMAIL_DB};
SOURCE ${MYSQL_VMAIL_STRUCTURE_SAMPLE};

/* Add your first domain. */
INSERT INTO domain (domain,transport,settings,created) VALUES ("${FIRST_DOMAIN}", "${TRANSPORT}", "default_user_quota:1024;", NOW()) ON DUPLICATE KEY UPDATE domain=domain;

/* Add your first normal user. */
INSERT INTO mailbox (username,password,name,maildir,quota,domain,isadmin,isglobaladmin,created) VALUES ("${FIRST_USER}@${FIRST_DOMAIN}","${FIRST_USER_PASSWD}","${FIRST_USER}","${FIRST_USER_MAILDIR_HASH_PART}",1024, "${FIRST_DOMAIN}", 1, 1, NOW()) ON DUPLICATE KEY UPDATE username=username;
INSERT INTO alias (address,goto,domain,created) VALUES ("${FIRST_USER}@${FIRST_DOMAIN}", "${FIRST_USER}@${FIRST_DOMAIN}", "${FIRST_DOMAIN}", NOW())  ON DUPLICATE KEY UPDATE address=address;

/* Mark first mail user as global admin */
INSERT INTO domain_admins (username,domain,created) VALUES ("${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}","ALL", NOW()) ON DUPLICATE KEY UPDATE username=username, domain=domain;

EOF

    ECHO_DEBUG "Import postfix virtual hosts/users: ${MYSQL_VMAIL_SQL}."
    ${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${MYSQL_VMAIL_SQL};
EOF

    if [ X"${MYSQL_EXTERNAL}" == X'NO' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
FLUSH PRIVILEGES;
EOF
    fi


    cat >> ${TIP_FILE} <<EOF
Virtual Users:
    - ${MYSQL_VMAIL_STRUCTURE_SAMPLE}
    - ${MYSQL_VMAIL_SQL}

EOF

    echo 'export status_mysql_import_vmail_users="DONE"' >> ${STATUS_FILE}
}

