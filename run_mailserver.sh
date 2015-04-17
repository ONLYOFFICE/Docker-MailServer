#/bin/bash

DATA_DIR="/usr/src/iRedMail-0.8.7"

# start services
service crond start
service mysqld start
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