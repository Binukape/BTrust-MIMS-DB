#!/bin/sh
set -e
cd /opt/mims
. ./.env
mkdir -p backups
docker compose -f docker-compose.prod.yml exec -T db \
  mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --events mims_db \
  | gzip > "backups/mims_$(date +%F_%H%M).sql.gz"
find backups -name 'mims_*.sql.gz' -mtime +7 -delete
