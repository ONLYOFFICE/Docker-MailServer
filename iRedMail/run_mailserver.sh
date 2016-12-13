#!/bin/bash

HTTPD_LOG_DIR="/var/log/httpd"
TMP_SQL="/tmp/cluebringer_init_sql.${RANDOM}${RANDOM}"
HOSTNAME="$(hostname -f)"
IP_ADDRESS="$(hostname -i && dig +short myip.opendns.com @resolver1.opendns.com)"

tmprootdir="$(dirname $0)"
echo ${tmprootdir} | grep '^/' >/dev/null 2>&1
if [ X"$?" == X"0" ]; then
    ROOTDIR="${tmprootdir}"
else
    ROOTDIR="$(pwd)"
fi

cd ${ROOTDIR}

. ${ROOTDIR}/config
. ${ROOTDIR}/conf/mysql
. ${ROOTDIR}/functions/postfix.sh
. ${ROOTDIR}/functions/mysql.sh

if [ ! -f ${HTTPD_LOG_DIR} ]; then
    mkdir ${HTTPD_LOG_DIR}
fi

rm /var/run/syslogd.pid
rm /var/run/cbpolicyd.pid
rm /var/run/opendkim/opendkim.pid

# start services
service mysqld start

# update rows in 'greylisting_whitelist'
mysql_generate_defaults_file_root

cat >> ${TMP_SQL} <<EOF
USE ${CLUEBRINGER_DB_NAME};
DELETE FROM greylisting_whitelist WHERE Comment='${HOSTNAME}';
EOF

for i in $IP_ADDRESS; do
    cat >> ${TMP_SQL} <<EOF
INSERT INTO greylisting_whitelist (Source, Comment, Disabled) VALUES ("SenderIP:$i", '${HOSTNAME}', 0);
EOF
done

# generate and insert access_token into 'api_keys'
cur_date="$(date +'%F %T')"
expires_at="$(date +'%F %T' -d "+36500 days")"
access_token=$(date | md5sum | awk '{ print $1 }')

cat >> ${TMP_SQL} <<EOF
INSERT IGNORE INTO api_keys (id, access_token, active, expires_at, created_at, updated_at) VALUES (1, '${access_token}', 1, '${expires_at}', '${cur_date}', '${cur_date}');
EOF

${MYSQL_CLIENT_ROOT} <<EOF
SOURCE ${TMP_SQL};
EOF

service crond start
service dovecot start
service rsyslog start
service amavisd start
service postfix start
service cbpolicyd start
service clamd start
service clamd.amavisd start
service httpd start
service opendkim start
service spamassassin start
service fail2ban start
service spamtrainer start

rm -f ${MYSQL_DEFAULTS_FILE_ROOT} &>/dev/null
rm -f ${TMP_SQL} 2>/dev/null
unset TMP_SQL