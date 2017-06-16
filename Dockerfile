FROM centos:6.7
MAINTAINER Ascensio System SIA <support@onlyoffice.com>

ADD iRedMail.repo /etc/yum.repos.d/iRedMail.repo
ADD iRedMail /usr/src/iRedMail/

RUN yum -y update && \
    yum clean metadata && \
    sed -i "s/tsflags=nodocs//g" /etc/yum.conf && \
    yum -y --disablerepo=rpmforge,ius,remi install epel-release && \
	yum -y install tar wget curl htop nano gcc make perl && \
	wget https://www.openssl.org/source/openssl-1.0.2-latest.tar.gz && \
	tar -zxf openssl-1.0.2-latest.tar.gz && \
	cd openssl-1.0.2*/ && \
	./config && \
	make && \
	make install && \
	cd .. && \
    rm -rf openssl-1.0.2* && \
    yum -y install postfix mysql-server mysql perl-DBD-MySQL mod_auth_mysql && \
    yum -y install php php-common php-gd php-xml php-mysql php-ldap php-pgsql php-imap php-mbstring php-pecl-apc php-intl php-mcrypt && \
    yum -y install httpd mod_ssl cluebringer dovecot dovecot-pigeonhole dovecot-managesieve && \
    yum -y install amavisd-new clamd clamav-db spamassassin altermime perl-LDAP perl-Mail-SPF unrar && \
    yum -y install python-sqlalchemy python-setuptools MySQL-python  awstats && \
    yum -y install libopendkim libopendkim-devel mysql-devel readline-devel gcc-c++ sendmail-milter sendmail-devel libbsd-devel && \
    yum -y install readline libyaml-devel libffi-devel openssl-devel bison && \
    yum -y install curl-devel httpd-devel sqlite-devel which libtool unzip bzip2 acl patch tmpwatch crontabs dos2unix logwatch crond && \
    find /usr/src/iRedMail -type d -name pkgs -prune -o -type f -exec dos2unix {} \; && \
    chmod 755 /usr/src/iRedMail/pkgs_install.sh && \
    chmod 755 /usr/src/iRedMail/iRedMail.sh && \
    chmod 755 /usr/src/iRedMail/run_mailserver.sh  && \
    bash /usr/src/iRedMail/pkgs_install.sh && \
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
    export USE_DOCKER='YES' && \
    bash -C '/usr/src/iRedMail/iRedMail.sh' && \
    bash -C '/usr/src/iRedMail/run_mailserver.sh';'bash'