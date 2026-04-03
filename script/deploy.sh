dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
now=$(date +"%Y%m%d%H%M%S")

cd ${dir}/../

tar zcvf backend_${now}.tar.gz ./backend

scp backend_${now}.tar.gz cloud:~/
scp deploy-config.json cloud:~/

ssh cloud << EOF
rm backend
tar xzvf backend_${now}.tar.gz
mv backend backend_${now}
ln -s backend_${now} backend

source venv/bin/activate

python3 backend/generate_env.py

rm backend/db.sqlite3
rm -rf backend/vector_db/*

python3 backend/manage.py migrate
python3 backend/manage.py seed
python3 backend/manage.py sync_vector_products
EOF
