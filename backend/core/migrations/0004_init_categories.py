# Initialize categories: 杂物, 数码, 旧书, 其他(兜底)

from django.db import migrations


def init_categories(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Product = apps.get_model('core', 'Product')

    # 创建分类
    categories = [
        {'category_id': 'misc', 'name': '杂物', 'description': '各种杂物', 'sort_order': 1},
        {'category_id': 'digital', 'name': '数码', 'description': '数码产品', 'sort_order': 2},
        {'category_id': 'books', 'name': '旧书', 'description': '二手书籍', 'sort_order': 3},
        {'category_id': 'other', 'name': '其他', 'description': '未分类商品', 'sort_order': 99},
    ]

    for cat_data in categories:
        Category.objects.get_or_create(
            category_id=cat_data['category_id'],
            defaults={
                'name': cat_data['name'],
                'description': cat_data['description'],
                'sort_order': cat_data['sort_order'],
                'is_active': True,
            }
        )

    # 获取"其他"分类
    other_category = Category.objects.get(category_id='other')

    # 迁移旧数据：所有没有category_ref的商品归到"其他"
    for product in Product.objects.filter(category_ref__isnull=True):
        product.category_ref = other_category
        product.save(update_fields=['category_ref'])


def reverse_init(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Category.objects.filter(category_id__in=['misc', 'digital', 'books', 'other']).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_category_product_category_ref'),
    ]

    operations = [
        migrations.RunPython(init_categories, reverse_init),
    ]
