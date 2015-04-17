#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Fetch all extra packages we need to build mail server.

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

ROOTDIR="$(pwd)"
CONF_DIR="${ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/iredadmin

# Re-define @STATUS_FILE, so that iRedMail.sh can read it.
export STATUS_FILE="${ROOTDIR}/../.status"

check_user root
check_hostname

# Where to fetch/store binary packages and source tarball.
export IREDMAIL_MIRROR="${IREDMAIL_MIRROR:=http://iredmail.org}"
export PKG_DIR="${ROOTDIR}/pkgs"

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH="which${PKG_ARCH}"
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET="wget${PKG_ARCH}"

elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    if [ X"${OS_ARCH}" == X"x86_64" ]; then
        export pkg_arch='amd64'
    else
        export pkg_arch="${OS_ARCH}"
    fi

    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH="debianutils"
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET="wget"
    # command: dpkg-scanpackages.
    export BIN_CREATEREPO="dpkg-scanpackages"
    export PKG_CREATEREPO="dpkg-dev"
fi

# Binary packages.
export pkg_total=$(echo ${PKGLIST} | wc -w | awk '{print $1}')
export pkg_counter=1

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

create_repo_rhel()
{
    # createrepo
    ECHO_INFO "Generating yum repository ..."

    # Backup old repo file.
    backup_file ${LOCAL_REPO_FILE}

    # Generate new repo file.
    cat > ${LOCAL_REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=${LOCAL_REPO_NAME}
baseurl=${IREDMAIL_MIRROR}/yum/rpms/${DISTRO_VERSION}/
enabled=1
gpgcheck=0
EOF

    ECHO_INFO "Clean metadata of yum repositories."
    yum clean metadata

    # RHEL/CentOS 6.
    # Create a temporary yum repo to install epel-release without GPG check.
    cat > ${YUM_REPOS_DIR}/tmp_epel.repo <<EOF
[tmp_epel]
name=Extra Packages for Enterprise Linux ${DISTRO_VERSION} - \$basearch
#baseurl=http://download.fedoraproject.org/pub/epel/${DISTRO_VERSION}/\$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-${DISTRO_VERSION}&arch=\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF

    ECHO_INFO "Install epel yum repo."
    eval ${install_pkg} epel-release && rm ${YUM_REPOS_DIR}/tmp_epel.repo
    yum clean metadata

    echo 'export status_create_repo_rhel="DONE"' >> ${STATUS_FILE}
}

if [ -e ${STATUS_FILE} ]; then
    . ${STATUS_FILE}
else
    echo '' > ${STATUS_FILE}
fi

prepare_dirs

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Create yum repository.
    check_status_before_run create_repo_rhel

    # Check required commands, install related package if command doesn't exist.
    check_pkg ${BIN_WHICH} ${PKG_WHICH}
    check_pkg ${BIN_WGET} ${PKG_WGET}

elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    # Force update.
    ECHO_INFO "Resynchronizing the package index files (apt-get update) ..."
    ${APTGET} update
fi

echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
