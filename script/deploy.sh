
# 要求服务器在~下有venv

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
now=$(date +"%Y%m%d%H%M%S")

cd ${dir}/../

tar zcvf backend_${now}.tar.gz ./backend

scp backend_${now}.tar.gz cloud:~/
rm backend_${now}.tar.gz 
scp deploy-config.json* cloud:~/
scp -r script cloud:~/

ssh cloud << EOF
rm backend
tar xzvf backend_${now}.tar.gz
mv backend backend_${now}
ln -s backend_${now} backend

source venv/bin/activate

bash script/switch-config.sh development

rm backend/db.sqlite3
rm -rf backend/vector_db/*

python3 backend/manage.py migrate
python3 backend/manage.py seed
python3 backend/manage.py sync_vector_products
EOF
