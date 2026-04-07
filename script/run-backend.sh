#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../

source .venv/bin/activate || true

ENVIR=$(cat deploy-config.json | jq -r '.environment')

DJANGO_ENV=$ENVIR python3 backend/manage.py runserver 0.0.0.0:$1


