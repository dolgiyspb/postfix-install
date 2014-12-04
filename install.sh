#!/bin/sh



function install_deps {
    local DEPENDENCIES='binutils gcc make libpam0g-dev postgresql libpq-dev'
    apt-get install -y $DEPENDENCIES
}

function unpack_sources {
    local TEMP_DIR=~/mail-server-install
    mkdir $TEMP_DIR
    find . -name '*.tar.gz' -exec cp {} $TEMP_DIR \;
    cp database.init.sql $TEMP_DIR
    cp -r dovecot $TEMP_DIR
    cp -r postfix $TEMP_DIR
    cd $TEMP_DIR
    find . -name '*.tar.gz' -exec tar -xzf {} \; -exec rm {} \;
}

function build_db {
    local DB_DIR=`find . -maxdepth 1 -name "db*" -type d`
    local DB_BUILD_DIR=$DB_DIR/build_unix
    local DB_DIST_DIR=../dist    
    save_current_dir
    cd $DB_BUILD_DIR
    $DB_DIST_DIR/configure --libdir=/usr/lib --includedir=/usr/include
    make
    make install
    make library_install
    ldconfig
    restore_current_dir
}

function save_current_dir {
    CURRENT_DIR=`pwd`
}
function restore_current_dir {
    cd $CURRENT_DIR
}

function build_postfix {
    save_current_dir
    local POSTFIX_DIR=`find . -maxdepth 1 -name "postfix-*" -type d`
    adduser --system --group postfix
    addgroup postdrop
    cd $POSTFIX_DIR
    make -f Makefile.init makefiles 'CCARGS=-DHAS_PGSQL -I/usr/include/postgresql/' 'AUXLIBS=-L/usr/lib/postgresql/9.1/lib/ -lpq'
    make
    make upgrade
    newaliases
    postfix start
    restore_current_dir
    
}

function install_dovecot {
    save_current_dir
    local DOVECOT_DIR=`find . -name "dovecot-*" -type d`
    cd $DOVECOT_DIR
    ./configure --with-pam --with-sql=yes --with-pgsql
    make
    make install
    cp -r /usr/local/share/doc/dovecot/example-config/* /usr/local/etc/dovecot/
    openssl req -new -x509 -days 3650 -nodes -out /etc/ssl/certs/dovecot.pem -keyout /etc/ssl/private/dovecot.pem -subj "/C=RU/ST=Spb/L=Spb/O=Mstb/OU=721/CN=istok"
    adduser --system dovenull
    adduser --system dovecot
    dovecot
    restore_current_dir
}
function configure_database {
    echo -n "configure database current dir: "
    echo `pwd`
    local DB_USERNAME="postfix"
    local DB_PASSWORD="12345678"
    local DB_NAME="mails"
    su postgres -c "createdb $DB_NAME"
    su postgres -c "createuser -D -R -S $DB_USERNAME"
    set_user_creds $DB_USERNAME $DB_PASSWORD $DB_NAME
    cp database.init.sql /var/lib/postgresql
    chown postgres /var/lib/postgresql/database.init.sql 
    su postgres -c "psql $DB_NAME < /var/lib/postgresql/database.init.sql"
    echo "client_encoding = latin1" >> /etc/postgresql/9.1/main/postgresql.conf
    create_adapters $DB_USERNAME $DB_PASSWORD $DB_NAME
    service postgres restart
}
function set_user_creds() {
    local SETUP_STRING="ALTER USER $1 WITH PASSWORD '$2';"
    echo ${SETUP_STRING} > user
    su postgres -c "psql $3 < user"
    rm user
}

function create_adapters() {
    local DB_USERNAME=$1
    local DB_PASSWORD=$2
    local DB_NAME=$3
    local VIRTUAL_MAILBOX_DOMAINS_QUERY="SELECT 1 FROM virtual_domains WHERE name='%s'"
    local VIRTUAL_MAILBOX_MAPS_QUERY="SELECT 1 FROM virtual_users WHERE email='%s'"
    local VIRTUAL_MAILBOX_ALIAS_QUERY="SELECT destination FROM virtual_aliases WHERE source='%s'"
    create_postfix_db_adapter $DB_USERNAME $DB_PASSWORD $DB_NAME "$VIRTUAL_MAILBOX_DOMAINS_QUERY" "virtual_mailbox_domains"
    create_postfix_db_adapter $DB_USERNAME $DB_PASSWORD $DB_NAME "$VIRTUAL_MAILBOX_MAPS_QUERY" "virtual_mailbox_maps"
    create_postfix_db_adapter $DB_USERNAME $DB_PASSWORD $DB_NAME "$VIRTUAL_MAILBOX_ALIAS_QUERY" "virtual_alias_maps"
    chgrp postfix /etc/postfix/pgsql-*
    chmod u=rw,g=r,o= /etc/postfix/pgsql-*
    postfix reload
}

function create_postfix_db_adapter() {
    local DB_USERNAME=$1
    local DB_PASSWORD=$2
    local DB_NAME=$3
    local QUERY=$4
    local PARAMETR_NAME=$5
    local FILENAME=/etc/postfix/pgsql-$PARAMETR_NAME.cf
    echo $DB_USERNAME $DB_PASSWORD $DB_NAME $QUERY $PARAMETR_NAME $FILENAME
    echo "user = $DB_USERNAME" >> $FILENAME
    echo "password = $DB_PASSWORD" >> $FILENAME
    echo "hosts = 127.0.0.1" >> $FILENAME
    echo "dbname = $DB_NAME" >> $FILENAME
    echo "query = $QUERY" >> $FILENAME
    postconf -e $PARAMETR_NAME=pgsql:$FILENAME
}

function configure_dovecot {
    groupadd vmail
    useradd -g vmail vmail -d /var/vmail -m
    chown -R vmail:vmail /var/vmail/
    chmod u+w /var/vmail/
}
function copy_configs {
    cp -r dovecot /usr/local/etc/
    cp -r postfix /etc
}

function run {
    install_deps

    unpack_sources

    build_db

    build_postfix

    install_dovecot

    configure_database
    
    configure_dovecot

    copy_configs
}

run
#configure_database

