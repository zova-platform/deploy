#!/bin/sh
set -eu

for name in auth pricing dispatch trip; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
CREATE ROLE $name LOGIN PASSWORD '$SERVICE_DB_PASSWORD';
CREATE DATABASE $name OWNER $name;
SQL
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$name" \
    -c 'CREATE EXTENSION IF NOT EXISTS postgis;'
done
