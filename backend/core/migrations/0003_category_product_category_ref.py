# Generated migration for Category model

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),
    ]

    operations = [
        # 创建 Category 表
        migrations.CreateModel(
            name='Category',
            fields=[
                ('category_id', models.CharField(max_length=50, primary_key=True, serialize=False, verbose_name='分类ID')),
                ('name', models.CharField(max_length=100, verbose_name='分类名称')),
                ('description', models.TextField(blank=True, verbose_name='分类描述')),
                ('sort_order', models.IntegerField(default=0, verbose_name='排序顺序')),
                ('is_active', models.BooleanField(default=True, verbose_name='是否启用')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='创建时间')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='更新时间')),
            ],
            options={
                'verbose_name': '商品分类',
                'verbose_name_plural': '商品分类',
                'db_table': 'category',
                'ordering': ['sort_order', 'name'],
            },
        ),
        # 添加 Product.category_ref 外键
        migrations.AddField(
            model_name='product',
            name='category_ref',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='products', to='core.category', verbose_name='所属分类'),
        ),
        # 修改 Product.category 为可选
        migrations.AlterField(
            model_name='product',
            name='category',
            field=models.CharField(blank=True, max_length=100, verbose_name='商品分类(旧)'),
        ),
    ]
