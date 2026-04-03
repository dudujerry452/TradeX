dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../

source venv/bin/activate

python3 backend/manage.py runserver


