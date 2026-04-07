#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../

rm deploy-config.json 
cp deploy-config.json.${1} deploy-config.json

source venv/bin/activate || true

cd backend && python3 generate_env.py

echo "switch to ${1}"
