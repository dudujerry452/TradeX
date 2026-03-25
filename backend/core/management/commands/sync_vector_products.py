"""
python manage.py sync_vector_products
将数据库商品批量同步到 Chroma 向量库。
"""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from core.models import Product
from core.rag_vector_service import get_rag_collection, sync_products_to_vector_db


class Command(BaseCommand):
    help = "将数据库商品批量同步到向量库 (默认 upsert, 可选 --replace 清理脏数据)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--replace",
            action="store_true",
            help="先同步数据库商品，再删除向量库中数据库不存在的商品ID",
        )

    def handle(self, *args, **options):
        replace = options["replace"]

        try:
            collection = get_rag_collection(settings.BASE_DIR)
            products = Product.objects.all()
            result = sync_products_to_vector_db(collection, products, replace=replace)
        except Exception as exc:
            raise CommandError(f"同步失败: {exc}")

        self.stdout.write(self.style.SUCCESS("向量库同步完成"))
        self.stdout.write(f"  - 数据库商品总数: {result.total_db_count}")
        self.stdout.write(f"  - 已同步(新增/更新): {result.synced_count}")
        self.stdout.write(f"  - 已删除(向量库残留): {result.deleted_count}")
