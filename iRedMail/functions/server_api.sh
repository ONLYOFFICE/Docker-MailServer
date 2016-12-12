#!/usr/bin/env bash

server_api_install()
{
    ECHO_INFO "Install ruby."

    # Installing RVM
    tar zxvf ${PKG_DIR}/${RVM_PACKAGE} -C ${PKG_DIR}
    cd ${PKG_DIR}/${RVM_PACKAGE_NAME}
    ./scripts/install --auto-dotfiles
    cd ${ROOTDIR}
    source /etc/profile.d/rvm.sh

    cp ${PKG_DIR}/${RUBY_TARBALLS} ${RVM_PATH}/archives/${RUBY_TARBALLS}

    echo "" > ${RVM_PATH}/gemsets/default.gems
    echo "" > ${RVM_PATH}/gemsets/global.gems
    rvm autolibs read-fail

    # Installing ruby 
    rvm install ${RUBY_VERSION}
    rvm use ${RUBY_VERSION} --default 

    # Installing rubygems
    tar zxvf ${PKG_DIR}/${RUBYGEMS_PACKAGE} -C ${PKG_DIR}
    cd ${PKG_DIR}/${RUBYGEMS_NAME}
    ruby setup.rb

    ${RVM_PATH}/gems/${RUBY_NAME}/wrappers/gem install rack
    ${RVM_PATH}/gems/${RUBY_NAME}/wrappers/gem install bundler    

    # Installing passenger
    tar zxvf ${PKG_DIR}/${PASSENGER_PACKAGE} -C ${PKG_DIR}
    cd ${PKG_DIR}/${PASSENGER_NAME}
    ./bin/passenger-install-apache2-module --auto    

    tar xvf ${PKG_DIR}/${SERVER_API_TARBALLS} -C /var/www/html

    mkdir /var/www/html/${SERVER_API_NAME}/tmp
    mkdir /var/www/html/${SERVER_API_NAME}/public    

    cd /var/www/html/${SERVER_API_NAME}  
    bundle install

    echo 'export status_server_api_install="DONE"' >> ${STATUS_FILE}
}

server_api_config() 
{
    ECHO_INFO "Configure Server API."

    chown -R vmail:vmail /var/www/html/${SERVER_API_NAME}/config.ru    

    cp -rf ${SERVER_API_CONF} /var/www/html/${SERVER_API_NAME}/config/database.yml
    perl -pi -e "s#(database:).*#database: '${VMAIL_DB}'#" /var/www/html/${SERVER_API_NAME}/config/database.yml
    perl -pi -e "s#(username:).*#username: '${VMAIL_DB_ADMIN_USER}'#" /var/www/html/${SERVER_API_NAME}/config/database.yml
    perl -pi -e "s#(password:).*#password: '${VMAIL_DB_ADMIN_PASSWD}'#" /var/www/html/${SERVER_API_NAME}/config/database.yml
    perl -pi -e "s#(host:).*#host: '${MYSQL_SERVER}'#" /var/www/html/${SERVER_API_NAME}/config/database.yml

    ${MYSQL_CLIENT_ROOT} <<EOF
    -- Import SpamTrainer SQL template
    USE ${VMAIL_DB};
    SOURCE ${SERVER_API_DB_CONF};
    INSERT INTO global_vars VALUES ('VERSION','${VERSION}')
    ON DUPLICATE KEY UPDATE value='${VERSION}';
EOF

    cd /var/www/html/${SERVER_API_NAME} 
    ${GEMS_PATH}/${RUBY_NAME}/wrappers/rake api_key:generate

    cat >> ${HTTPD_CONF} <<EOF
Listen 8081

LoadModule passenger_module ${PKG_DIR}/${PASSENGER_NAME}/buildout/apache2/mod_passenger.so
<IfModule mod_passenger.c>
   PassengerRoot ${PKG_DIR}/${PASSENGER_NAME}
   PassengerDefaultRuby /usr/local/rvm/gems/${RUBY_NAME}/wrappers/ruby
</IfModule>

<VirtualHost *:8081>
    ServerName ${FIRST_DOMAIN}
    # !!! Be sure to point DocumentRoot to 'public'!
    DocumentRoot /var/www/html/${SERVER_API_NAME}/public
    RackEnv production
    <Directory /var/www/html/${SERVER_API_NAME}/public>
    # This relaxes Apache security settings.
    AllowOverride all
    # MultiViews must be turned off.
    Options -MultiViews
    </Directory>
</VirtualHost>
EOF

    echo 'export status_server_api_config="DONE"' >> ${STATUS_FILE}
}