#!/usr/bin/env bash

set -e

: ${DB:?}

start_db() {
  mkdir -p /var/lib/ramdisk
  mount -t tmpfs -o size=8192m ramdisk /var/lib/ramdisk

  if [ "${DB}" = "mysql" ]; then
    service mysql stop

    cp -R /var/lib/mysql/* /var/lib/ramdisk
    chown -R mysql /var/lib/ramdisk
    chgrp -R mysql /var/lib/ramdisk
    chmod 700 /var/lib/ramdisk
    echo -e "\n[mysqld]\ndatadir = /var/lib/ramdisk" >> /etc/mysql/my.cnf
    service mysql start

    trap stop_mysql EXIT
  elif [ "${DB}" = "postgres" ]; then
    service postgresql start
    POSTGRES_DATA_DIR=$(su postgres -c "psql -c 'show data_directory'" | grep -o "\S*main")
    POSTGRES_CONF_FILE=$(su postgres -c "psql -c 'show config_file'" | grep -o "\S*postgresql.conf")
    service postgresql stop

    cp -R $POSTGRES_DATA_DIR/* /var/lib/ramdisk
    chown -R postgres /var/lib/ramdisk
    chgrp -R postgres /var/lib/ramdisk
    chmod 700 /var/lib/ramdisk
    sed -i -E "s#data_directory = (.*)#data_directory = '/var/lib/ramdisk'#g" $POSTGRES_CONF_FILE
    service postgresql start

    trap stop_postgres EXIT
  else
    echo "Unknown DB type '${DB}', this script only supports 'mysql' and 'postgres'"
    exit 1
  fi
}

stop_mysql() {
  service mysql stop
}

stop_postgres() {
  service postgresql stop
}

pushd cloud_controller_ng > /dev/null
  start_db

  export BUNDLE_GEMFILE=Gemfile
  bundle install

  if [ -n "${RUN_IN_PARALLEL}" ]; then
    bundle exec rubocop --parallel
    bundle exec rake spec:all
  else
    bundle exec rubocop
    bundle exec rake spec:serial
  fi
popd > /dev/null
