* [Overview](#overview)
* [Functionality](#functionality)
* [Recommended System Requirements](#recommended-system-requirements)
* [Running Docker Image](#running-docker-image)
* [Configuring Docker Image](#configuring-docker-image)
* [Installing the SSL Certificates](#installing-the-ssl-certificates)
	+ [Available Configuration Parameters](#available-configuration-parameters)
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
* **Docker**: version 1.4.1 or later

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
-v /opt/docker/Data:/etc/pki/tls/mailserver -h yourdomain.com onlyoffice/mailserver
```
	
Where `yourdomain.com` is your own domain name.


## Installing the SSL Certificates

The self-signed certificates for your domain will be created by default while running the docker container. If you want to use CA sertified certificates,
you will need to rename them and copy into the /opt/onlyoffice/Data directory before running the image. The following files are required:

	/opt/docker/Data/mail.onlyoffice.key
	/opt/docker/Data/mail.onlyoffice.crt
	/opt/docker/Data/mail.onlyoffice.ca-bundle

You can copy the SSL certificates into the /opt/onlyoffice/Data directory after running the image. But in this case you will need to restart the docker container.

### Available Configuration Parameters

*Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command.*

Below is the complete list of parameters that can be set using environment variables.

- **STORAGE_BASE_DIR**: The path to the mail store. Defaults to `/var/vmail`.
- **FIRST_DOMAIN**: The first virtual domain, where the postmaster address will be hosted. This domain should not coincide with the primary mail server domain. Defaults to `mailserver.onlyoffice.com`.
- **DOMAIN_ADMIN_PASSWD**: The postmaster password. The default postmaster address is `postmaster@mailserver.onlyoffice.com`.

## Installing ONLYOFFICE Mail Server integrated with Document and Community Servers

ONLYOFFICE Mail Server is a part of ONLYOFFICE Free Edition that comprises also Document Server and Community Server. To install them, follow these easy steps:

**STEP 1**: Installing ONLYOFFICE Document Server.

```bash
sudo docker run -i -t -d  --name onlyoffice-document-server onlyoffice/documentserver
```

**STEP 2**: Installing ONLYOFFICE Mail Server. 

```bash
sudo docker run --privileged -i -t -d --name onlyoffice-mail-server -p 25:25 -p 143:143 -p 587:587 \
-h yourdomain.com onlyoffice/mailserver
```
 Where `yourdomain.com` is your own domain name.
 
**STEP 3**: Installing ONLYOFFICE Community Server

```bash
sudo docker run -i -t -d -p 80:80  -p 443:443 \
--link onlyoffice-mail-server:mail_server \
--link onlyoffice-document-server:document_server \
 onlyoffice/communityserver
```

Alternatively, you can use [docker-compose](https://docs.docker.com/compose/install "docker-compose") to install the whole ONLYOFFICE Free Edition at once. For the mail server correct work you need to specify its hostname 'yourdomain.com'. Assuming you have docker-compose installed, execute the following command:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/Docker-CommunityServer/master/docker-compose.yml
docker-compose up -d
```

## Project Information

Official website: [http://www.onlyoffice.org](http://onlyoffice.org "http://www.onlyoffice.org")

License: [View](https://raw.githubusercontent.com/ONLYOFFICE/Docker-MailServer/master/LICENSE.txt "View")

SaaS version: [http://www.onlyoffice.com](http://www.onlyoffice.com "http://www.onlyoffice.com")


## User Feedback and Support

If you have any problems with or questions about this image, please contact us through a [dev.onlyoffice.org][1].

  [1]: http://dev.onlyoffice.org
