* [Overview](#overview)
* [Functionality](#functionality)
* [Recommended System Requirements](#recommended-system-requirements)
* [Installing Prerequisites](#installing-prerequisites)
* [Installing MySQL](#installing-mysql)
* [Installing Mail Server](#installing-mail-server)
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

ONLYOFFICE Mail Server is a part of **ONLYOFFICE Workspace** that also includes [Document Server (distributed as ONLYOFFICE Docs)](https://github.com/ONLYOFFICE/DocumentServer), [Community Server (distributed as ONLYOFFICE Groups](https://github.com/ONLYOFFICE/Docker-CommunityServer), [Talk (instant messaging app)](https://github.com/ONLYOFFICE/XMPPServer). 

## Recommended System Requirements

* **RAM**: 4 GB or more
* **CPU**: dual-core 2 GHz or higher
* **Swap file**: at least 2 GB
* **HDD**: at least 2 GB of free space
* **Distributive**: 64-bit Red Hat, CentOS or other compatible distributive with kernel version 3.8 or later, 64-bit Debian, Ubuntu or other compatible distributive with kernel version 3.8 or later
* **Docker**: version 1.9.0 or later

## Installing Prerequisites

Before you start **ONLYOFFICE Mail Server**, you need to create the following folders:

1. For MySQL server
```
sudo mkdir -p "/app/onlyoffice/mysql/conf.d";
sudo mkdir -p "/app/onlyoffice/mysql/data";
sudo mkdir -p "/app/onlyoffice/mysql/initdb";
```

2. For **Community Server** data and logs
```
sudo mkdir -p "/app/onlyoffice/CommunityServer/data";
sudo mkdir -p "/app/onlyoffice/CommunityServer/logs";
sudo mkdir -p "/app/onlyoffice/CommunityServer/letsencrypt";
```

3. For **Mail Server** data and logs
```
sudo mkdir -p "/app/onlyoffice/MailServer/data/certs";
sudo mkdir -p "/app/onlyoffice/MailServer/logs";
```
4. For **Control Panel**
```
sudo mkdir -p "/app/onlyoffice/ControlPanel/data";
sudo mkdir -p "/app/onlyoffice/ControlPanel/logs";
```
Then create the `onlyoffice` network:
```
sudo docker network create --driver bridge onlyoffice
```

## Installing MySQL

After that you need to create MySQL server Docker container. Create the configuration file:
```
echo "[mysqld]
sql_mode = 'NO_ENGINE_SUBSTITUTION'
max_connections = 1000
max_allowed_packet = 1048576000" > /app/onlyoffice/mysql/conf.d/onlyoffice.cnf
```

Create the SQL script which will generate the users and issue the rights to them. The `onlyoffice_user` is required for **ONLYOFFICE Community Server**, and the `mail_admin` is required for **ONLYOFFICE Mail Server** in case it is going to be installed:
```
echo "CREATE USER 'onlyoffice_user'@'localhost' IDENTIFIED BY 'onlyoffice_pass';
CREATE USER 'mail_admin'@'localhost' IDENTIFIED BY 'Isadmin123';
GRANT ALL PRIVILEGES ON * . * TO 'root'@'%' IDENTIFIED BY 'my-secret-pw';
GRANT ALL PRIVILEGES ON * . * TO 'onlyoffice_user'@'%' IDENTIFIED BY 'onlyoffice_pass';
GRANT ALL PRIVILEGES ON * . * TO 'mail_admin'@'%' IDENTIFIED BY 'Isadmin123';
FLUSH PRIVILEGES;" > /app/onlyoffice/mysql/initdb/setup.sql
```

*Please note, that the above script will set permissions to access SQL server from any domains (`%`). If you want to limit the access, you can specify hosts which will have access to SQL server.*

Now you can create MySQL container setting MySQL version to 5.7:
```
sudo docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-mysql-server \
 -v /app/onlyoffice/mysql/conf.d:/etc/mysql/conf.d \
 -v /app/onlyoffice/mysql/data:/var/lib/mysql \
 -v /app/onlyoffice/mysql/initdb:/docker-entrypoint-initdb.d \
 -e MYSQL_ROOT_PASSWORD=my-secret-pw \
 -e MYSQL_DATABASE=onlyoffice \
 mysql:5.7
 ```
 ## Installing Mail Server

sudo docker run --init --net onlyoffice --privileged -i -t -d --restart=always --name onlyoffice-mail-server -p 25:25 -p 143:143 -p 587:587 \
 -e MYSQL_SERVER=onlyoffice-mysql-server \
 -e MYSQL_SERVER_PORT=3306 \
 -e MYSQL_ROOT_USER=root \
 -e MYSQL_ROOT_PASSWD=my-secret-pw \
 -e MYSQL_SERVER_DB_NAME=onlyoffice_mailserver \
 -v /app/onlyoffice/MailServer/data:/var/vmail \
 -v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver \
 -v /app/onlyoffice/MailServer/logs:/var/log \
 -h yourdomain.com \
 onlyoffice/mailserver
 
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

## Installing ONLYOFFICE Workspace

ONLYOFFICE Mail Server is a part of ONLYOFFICE Workspace that comprises also Document Server and Community Server. To install them, follow these easy steps:

**STEP 1**: Create the `onlyoffice` network.

```bash
docker network create --driver bridge onlyoffice
```
Then launch containers on it using the 'docker run --net onlyoffice' option:

**STEP 2**: Install MySQL.

Follow [these steps](#installing-mysql) to install MySQL server.

**STEP 3**: Install ONLYOFFICE Document Server.

```bash
sudo docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-document-server \
	-v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice  \
	-v /app/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data  \
	-v /app/onlyoffice/DocumentServer/lib:/var/lib/onlyoffice \
	-v /app/onlyoffice/DocumentServer/db:/var/lib/postgresql \
	onlyoffice/documentserver
```
To learn more, refer to the [ONLYOFFICE Document Server documentation](https://github.com/ONLYOFFICE/Docker-DocumentServer "ONLYOFFICE Document Server documentation").

**STEP 4**: Install ONLYOFFICE Mail Server. 

For the mail server correct work you need to specify its hostname 'yourdomain.com'.

```bash
sudo docker run --init --net onlyoffice --privileged -i -t -d --restart=always --name onlyoffice-mail-server -p 25:25 -p 143:143 -p 587:587 \
 -e MYSQL_SERVER=onlyoffice-mysql-server \
 -e MYSQL_SERVER_PORT=3306 \
 -e MYSQL_ROOT_USER=root \
 -e MYSQL_ROOT_PASSWD=my-secret-pw \
 -e MYSQL_SERVER_DB_NAME=onlyoffice_mailserver \
 -v /app/onlyoffice/MailServer/data:/var/vmail \
 -v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver \
 -v /app/onlyoffice/MailServer/logs:/var/log \
 -h yourdomain.com \
 onlyoffice/mailserver
```

The additional parameters for mail server are available [here](https://github.com/ONLYOFFICE/Docker-CommunityServer/blob/master/docker-compose.yml#L75).

**Step5**: Install Control Panel

```
docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-control-panel \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /app/onlyoffice/CommunityServer/data:/app/onlyoffice/CommunityServer/data \
-v /app/onlyoffice/ControlPanel/data:/var/www/onlyoffice/Data \
-v /app/onlyoffice/ControlPanel/logs:/var/log/onlyoffice onlyoffice/controlpanel
```

**STEP 6**: Install ONLYOFFICE Community Server

```
sudo docker run --net onlyoffice -i -t -d --privileged --restart=always --name onlyoffice-community-server -p 80:80 -p 443:443 -p 5222:5222 \
 -e MYSQL_SERVER_ROOT_PASSWORD=my-secret-pw \
 -e MYSQL_SERVER_DB_NAME=onlyoffice \
 -e MYSQL_SERVER_HOST=onlyoffice-mysql-server \
 -e MYSQL_SERVER_USER=onlyoffice_user \
 -e MYSQL_SERVER_PASS=onlyoffice_pass \ 
 -e DOCUMENT_SERVER_PORT_80_TCP_ADDR=onlyoffice-document-server \ 
 -e MAIL_SERVER_API_HOST=${MAIL_SERVER_IP} \
 -e MAIL_SERVER_DB_HOST=onlyoffice-mysql-server \
 -e MAIL_SERVER_DB_NAME=onlyoffice_mailserver \
 -e MAIL_SERVER_DB_PORT=3306 \
 -e MAIL_SERVER_DB_USER=root \
 -e MAIL_SERVER_DB_PASS=my-secret-pw \ 
 -e CONTROL_PANEL_PORT_80_TCP=80 \
 -e CONTROL_PANEL_PORT_80_TCP_ADDR=onlyoffice-control-panel \
 -v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data \
 -v /app/onlyoffice/CommunityServer/logs:/var/log/onlyoffice \
 -v /app/onlyoffice/CommunityServer/letsencrypt:/etc/letsencrypt \
 -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
 onlyoffice/communityserver
```

Where `${MAIL_SERVER_IP}` is the IP address for **ONLYOFFICE Mail Server**. You can easily get it using the command:
```
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' onlyoffice-mail-server
```

Alternatively, you can use an automatic installation script to install the whole ONLYOFFICE Workspace at once. For the mail server correct work you need to specify its hostname 'yourdomain.com'.

**STEP 1**: Download the ONLYOFFICE Workspace Docker script file

```bash
wget https://download.onlyoffice.com/install/workspace-install.sh
```

**STEP 2**: Install ONLYOFFICE Workspace executing the following command:

```bash
workspace-install.sh -md yourdomain.com
```

Or, use [docker-compose](https://docs.docker.com/compose/install "docker-compose"). First you need to clone this [GitHub repository](https://github.com/ONLYOFFICE/Docker-CommunityServer/):

```bash
git clone https://github.com/ONLYOFFICE/Docker-CommunityServer
```

After that switch to the repository folder:

```bash
cd Docker-CommunityServer
```

For the mail server correct work, open one of the files depending on the product you use:

* [docker-compose.yml](https://github.com/ONLYOFFICE/Docker-CommunityServer/blob/master/docker-compose.groups.yml) for Community Server (distributed as ONLYOFFICE Groups)
* [docker-compose.yml](https://github.com/ONLYOFFICE/Docker-CommunityServer/blob/master/docker-compose.workspace.yml) for ONLYOFFICE Workspace Community Edition 
* [docker-compose.yml](https://github.com/ONLYOFFICE/Docker-CommunityServer/blob/master/docker-compose.workspace_enterprise.yml) for ONLYOFFICE Workspace Enterprise Edition

Then replace the `${MAIL_SERVER_HOSTNAME}` variable with your own hostname for the **Mail Server**. After that, assuming you have docker-compose installed, execute the following command:

```bash
cd link-to-your-modified-docker-compose
docker-compose up -d
```

## Project Information

Official website: [https://www.onlyoffice.com/](https://www.onlyoffice.com/?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDockerMail)

License: [View](https://raw.githubusercontent.com/ONLYOFFICE/Docker-MailServer/master/LICENSE.txt "View")

ONLYOFFICE Workspace: [https://www.onlyoffice.com/workspace.aspx](https://www.onlyoffice.com/workspace.aspx?utm_source=github&utm_medium=cpc&utm_campaign=GitHubDockerMail)

## User feedback and support

If you have any problems with or questions about this image, please visit our official forum to find answers to your questions: [dev.onlyoffice.org][1] or you can ask and answer ONLYOFFICE development questions on [Stack Overflow][2].

  [1]: http://dev.onlyoffice.org
  [2]: http://stackoverflow.com/questions/tagged/onlyoffice
