* [Overview](#overview)
* [Functionality](#functionality)
* [Recommended System Requirements](#recommended-system-requirements)
* [Running Docker Image](#running-docker-image)
* [Configuring Docker Image](#configuring-docker-image)
* [Installing the SSL Certificates](#installing-the-ssl-certificates)
	+ [Available Configuration Parameters](#available-configuration-parameters)
* [Storing Data](#storing-data)
* [Installing ONLYOFFICE Mail Server integrated with Document and Community Servers](#installing-onlyoffice-mail-server-integrated-with-document-and-community-servers)
* [Project Information](#project-information)
* [User Feedback and Support](#user-feedback-and-support)

## Overview

ONLYOFFICE Mail Server is a full-featured mail server solution developed on the base of the iRedMail package, containing the following components: Postfix, Dovecot, SpamAssassin, ClamAV, OpenDKIM, Fail2ban.

## Functionality

Integrated with ONLYOFFICE Community Server, Mail Server allows to:

* connect your own domain name;
* create mailboxes;
* add aliases for each mailbox;
* create mailbox groups.

## Recommended System Requirements

* **RAM**: 4 GB or more
* **CPU**: dual-core 2 GHz or higher
* **Swap file**: at least 2 GB
* **HDD**: at least 2 GB of free space
* **Distributive**: 64-bit Red Hat, CentOS or other compatible distributive with kernel version 3.8 or later, 64-bit Debian, Ubuntu or other compatible distributive with kernel version 3.8 or later
* **Docker**: version 1.9.0 or later

## Running Docker Image

	sudo docker run --privileged -i -t -d -p 25:25 -p 143:143 -p 587:587 \
	-h yourdomain.com onlyoffice/mailserver
 
Where `yourdomain.com` is your own domain name.

In this case the mail server will ensure the mail delivery to internal addresses hosted on this server.

## Configuring Docker Image

To ensure the mail delivery to internal addresses as well as addresses of external servers you need to get your own domain name and configure a DNS server.

The following DNS records are required:
- A record (used to point a domain to the IP address of the host where this docker image is deployed).
- Pointer (RTP) record or a reverse DNS record (used to map a network interface (IP) to a hostname).
    
```bash
sudo docker run --privileged -i -t -d -p 25:25 -p 143:143 -p 587:587 \
-v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver -h yourdomain.com onlyoffice/mailserver
```
	
Where `yourdomain.com` is your own domain name.


## Installing the SSL Certificates

The self-signed certificates for your domain will be created by default while running the docker container. If you want to use CA sertified certificates,
you will need to rename them and copy into the /app/onlyoffice/MailServer/data/certs directory before running the image. The following files are required:

	/app/onlyoffice/MailServer/data/certs/mail.onlyoffice.key
	/app/onlyoffice/MailServer/data/certs/mail.onlyoffice.crt
	/app/onlyoffice/MailServer/data/certs/mail.onlyoffice.ca-bundle

You can copy the SSL certificates into the /app/onlyoffice/MailServer/data/certs directory after running the image. But in this case you will need to restart the docker container.

### Available Configuration Parameters

*Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command.*

Below is the complete list of parameters that can be set using environment variables.

- **STORAGE_BASE_DIR**: The path to the mail store. Defaults to `/var/vmail`.
- **FIRST_DOMAIN**: The first virtual domain, where the postmaster address will be hosted. This domain should not coincide with the primary mail server domain. Defaults to `mailserver.onlyoffice.com`.
- **DOMAIN_ADMIN_PASSWD**: The postmaster password. The default postmaster address is `postmaster@mailserver.onlyoffice.com`.

## Storing Data

All the data are stored in the specially-designated directories, **data volumes**, at the following location:
* **/var/log** for ONLYOFFICE Mail Server logs
* **/var/lib/mysql** for MySQL database data
* **/var/vmail** for mail storage
* **/etc/pki/tls/mailserver** for certificates

To get access to your data from outside the container, you need to mount the volumes. It can be done by specifying the '-v' option in the docker run command.

    sudo docker run --privileged -i -t -d -p 25:25 -p 143:143 -p 587:587 \
        -v /app/onlyoffice/MailServer/logs:/var/log  \
        -v /app/onlyoffice/MailServer/mysql:/var/lib/mysql  \
        -v /app/onlyoffice/MailServer/data:/var/vmail  \
        -v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver -h yourdomain.com onlyoffice/mailserver

Storing the data on the host machine allows you to easily update ONLYOFFICE once the new version is released without losing your data.

## Installing ONLYOFFICE Mail Server integrated with Document and Community Servers

ONLYOFFICE Mail Server is a part of ONLYOFFICE Community Edition that comprises also Document Server and Community Server. To install them, follow these easy steps:

**STEP 1**: Create the 'onlyoffice' network.

```bash
docker network create --driver bridge onlyoffice
```
Than launch containers on it using the 'docker run --net onlyoffice' option:

**STEP 1**: Install ONLYOFFICE Document Server.

```bash
sudo docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-document-server \
	-v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data \
	-v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice \
	onlyoffice/documentserver
```

**STEP 2**: Install ONLYOFFICE Mail Server. 

For the mail server correct work you need to specify its hostname 'yourdomain.com'.

```bash
sudo docker run --net onlyoffice --privileged -i -t -d --restart=always --name onlyoffice-mail-server \
	-p 25:25 -p 143:143 -p 587:587 \
	-v /app/onlyoffice/MailServer/data:/var/vmail \
	-v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver \
	-v /app/onlyoffice/MailServer/logs:/var/log \
	-v /app/onlyoffice/MailServer/mysql:/var/lib/mysql \
	-h yourdomain.com \
	onlyoffice/mailserver
```

**STEP 3**: Install ONLYOFFICE Community Server

```bash
sudo docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-community-server \
	-p 80:80 -p 5222:5222 -p 443:443 \
	-v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data \
	-v /app/onlyoffice/CommunityServer/mysql:/var/lib/mysql \
	-v /app/onlyoffice/CommunityServer/logs:/var/log/onlyoffice \
	-v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/DocumentServerData \
	-e DOCUMENT_SERVER_PORT_80_TCP_ADDR=onlyoffice-document-server \
	-e MAIL_SERVER_DB_HOST=onlyoffice-mail-server \
	onlyoffice/communityserver
```

Alternatively, you can use an automatic installation script to install the whole ONLYOFFICE Community Edition at once. For the mail server correct work you need to specify its hostname 'yourdomain.com'.

**STEP 1**: Download the Community Edition Docker script file

```bash
wget http://download.onlyoffice.com/install/opensource-install.sh
```

**STEP 2**: Install ONLYOFFICE Community Edition executing the following command:

```bash
bash opensource-install.sh -md yourdomain.com
```

Or, use [docker-compose](https://docs.docker.com/compose/install "docker-compose"). For the mail server correct work you need to specify its hostname 'yourdomain.com'. Assuming you have docker-compose installed, execute the following command:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/Docker-CommunityServer/master/docker-compose.yml
docker-compose up -d
```

## Project Information

Official website: [http://www.onlyoffice.org](http://onlyoffice.org "http://www.onlyoffice.org")

License: [View](https://raw.githubusercontent.com/ONLYOFFICE/Docker-MailServer/master/LICENSE.txt "View")

SaaS version: [http://www.onlyoffice.com](http://www.onlyoffice.com "http://www.onlyoffice.com")


## User Feedback and Support

If you have any problems with or questions about [ONLYOFFICE][2], please visit our official forum to find answers to your questions: [dev.onlyoffice.org][1] or you can ask and answer ONLYOFFICE development questions on [Stack Overflow][3].

  [1]: http://dev.onlyoffice.org
  [2]: https://github.com/ONLYOFFICE
  [3]: http://stackoverflow.com/questions/tagged/onlyoffice
