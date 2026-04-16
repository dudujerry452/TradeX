#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENVIR=$(cat deploy-config.json | jq -r '.environment')

cd ${dir}/../

source .venv/bin/activate || true

rm backend/db.sqlite3
rm -rf backend/vector_db/*

DJANGO_ENV=$ENVIR python3 backend/manage.py migrate
DJANGO_ENV=$ENVIR python3 backend/manage.py seed
DJANGO_ENV=$ENVIR python3 backend/manage.py sync_vector_products


