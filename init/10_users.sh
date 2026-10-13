#!/bin/sh
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS 'mims_owner'@'%' IDENTIFIED BY '${MIMS_OWNER_PASSWORD:-dev_owner_pw}';
CREATE USER IF NOT EXISTS 'mims_app'@'%' IDENTIFIED BY '${MIMS_APP_PASSWORD:-dev_app_pw}';
CREATE USER IF NOT EXISTS 'mims_reports'@'%' IDENTIFIED BY '${MIMS_REPORTS_PASSWORD:-dev_reports_pw}';
SQL
