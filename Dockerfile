FROM centos:6.6
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ADD iRedMail.repo /etc/yum.repos.d/iRedMail.repo
ADD run_mailserver.sh /usr/src/
ADD iRedMail-0.8.7 /usr/src/iRedMail-0.8.7/

RUN yum -y update && \
    yum clean metadata && \
    sed -i "s/tsflags=nodocs//g" /etc/yum.conf && \
    yum -y --disablerepo=rpmforge,ius,remi install epel-release && \
    yum -y install mysql-server.x86_64 mysql.x86_64 httpd.x86_64 httpd-devel mod_ssl.x86_64 php.x86_64 php-common.x86_64 && \
    yum -y install php-gd.x86_64 php-xml.x86_64 php-mysql.x86_64 php-ldap.x86_64 php-imap.x86_64 php-mbstring.x86_64 && \
    yum -y install php-pecl-apc.x86_64 postfix.x86_64 cluebringer perl-DBD-MySQL.x86_64 dovecot.x86_64 dovecot-managesieve.x86_64 && \
    yum -y install dovecot-pigeonhole.x86_64 clamd.x86_64 clamav.x86_64 clamav-db.x86_64 spamassassin.x86_64 altermime.x86_64 && \
    yum -y install perl-LDAP.noarch perl-Mail-SPF.noarch amavisd-new.noarch MySQL-python.x86_64 awstats.noarch && \
    yum -y install mod_auth_mysql.x86_64 libopendkim.x86_64 libopendkim-devel.x86_64 mysql-devel.x86_64 readline-devel.x86_64 && \
    yum -y install gcc gcc-c++ sendmail-milter.x86_64 sendmail-devel.x86_64 libbsd-devel readline zlib-devel libyaml-devel libffi-devel && \
    yum -y install openssl-devel libtool bison iconv-devel curl-devel which sqlite-devel  bzip2.x86_64 && \
    yum -y install acl.x86_64 patch.x86_64 tmpwatch.x86_64 crontabs.noarch dos2unix.x86_64 logwatch && \
    find /usr/src/iRedMail-0.8.7 -type d -name pkgs -prune -o -type f -exec dos2unix {} \; && \
    chmod 755 /usr/src/iRedMail-0.8.7/pkgs_install.sh && \
    chmod 755 /usr/src/iRedMail-0.8.7/iRedMail.sh && \
    chmod 755 /usr/src/run_mailserver.sh  && \
    bash /usr/src/iRedMail-0.8.7/pkgs_install.sh && \
    mkdir -p /etc/pki/tls/mailserver /var/vmail

VOLUME ["/var/log"]
VOLUME ["/var/lib/mysql"]
VOLUME ["/var/vmail"]
VOLUME ["/etc/pki/tls/mailserver"]

EXPOSE 25
EXPOSE 143
EXPOSE 587
EXPOSE 8081
EXPOSE 3306

CMD export CONFIGURATION_ONLY='YES' && \
    bash -C '/usr/src/iRedMail-0.8.7/iRedMail.sh' && \
    bash -C '/usr/src/run_mailserver.sh';'bash'