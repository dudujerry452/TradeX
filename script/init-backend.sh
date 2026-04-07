#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../

source venv/bin/activate || true

rm backend/db.sqlite3
rm -rf backend/vector_db/*

python3 backend/manage.py migrate
python3 backend/manage.py seed
python3 backend/manage.py sync_vector_products


