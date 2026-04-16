#!/usr/bin/env bash

# 要求服务器在~下有.venv

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
now=$(date +"%Y%m%d%H%M%S")

cd ${dir}/../

tar zcf backend_${now}.tar.gz ./backend

scp backend_${now}.tar.gz cloud:~/
rm backend_${now}.tar.gz 
scp deploy-config.json* cloud:~/
scp -r script cloud:~/

ssh -T cloud << EOF
  rm -f backend
  tar xzf backend_${now}.tar.gz
  mv backend backend_${now}
  ln -s backend_${now} backend

  source .venv/bin/activate

  bash script/switch-config.sh development > /tmp/deploy-switch.log 2>&1

  rm -f backend/db.sqlite3
  rm -rf backend/vector_db/*

  python3 backend/manage.py migrate > /tmp/deploy-migrate.log 2>&1
  python3 backend/manage.py seed > /tmp/deploy-seed.log 2>&1
  python3 backend/manage.py sync_vector_products > /tmp/deploy-sync.log 2>&1
EOF
