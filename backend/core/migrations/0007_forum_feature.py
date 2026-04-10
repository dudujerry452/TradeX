# Generated manually for forum feature support

from django.db import migrations, models
import django.db.models.deletion


def seed_forum_categories(apps, schema_editor):
    ForumCategory = apps.get_model('core', 'ForumCategory')
    defaults = [
        ('forum_general', '交流', '日常讨论与经验分享', 0),
        ('forum_qna', '问答', '提问和解答问题', 10),
        ('forum_review', '测评', '商品和体验测评', 20),
        ('forum_share', '晒单', '分享购买和使用心得', 30),
    ]

    for category_id, name, description, sort_order in defaults:
        ForumCategory.objects.get_or_create(
            category_id=category_id,
            defaults={
                'name': name,
                'description': description,
                'sort_order': sort_order,
                'is_active': True,
            },
        )


def unseed_forum_categories(apps, schema_editor):
    ForumCategory = apps.get_model('core', 'ForumCategory')
    ForumCategory.objects.filter(category_id__in=['forum_general', 'forum_qna', 'forum_review', 'forum_share']).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0006_alter_notification_options_alter_orderlog_options_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='ForumCategory',
            fields=[
                ('category_id', models.CharField(max_length=50, primary_key=True, serialize=False, verbose_name='分类ID')),
                ('name', models.CharField(max_length=100, unique=True, verbose_name='分类名称')),
                ('description', models.TextField(blank=True, verbose_name='分类描述')),
                ('sort_order', models.IntegerField(default=0, verbose_name='排序顺序')),
                ('is_active', models.BooleanField(default=True, verbose_name='是否启用')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='创建时间')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='更新时间')),
            ],
            options={
                'db_table': 'forum_category',
                'verbose_name': '论坛分类',
                'verbose_name_plural': '论坛分类',
                'ordering': ['sort_order', 'name'],
            },
        ),
        migrations.CreateModel(
            name='ForumTag',
            fields=[
                ('tag_id', models.CharField(max_length=50, primary_key=True, serialize=False, verbose_name='标签ID')),
                ('tag_name', models.CharField(max_length=100, unique=True, verbose_name='标签名称')),
                ('usage_count', models.IntegerField(default=0, verbose_name='使用次数')),
                ('create_time', models.DateTimeField(auto_now_add=True, verbose_name='创建时间')),
            ],
            options={
                'db_table': 'forum_tag',
                'verbose_name': '论坛标签',
                'verbose_name_plural': '论坛标签',
            },
        ),
        migrations.CreateModel(
            name='ForumPost',
            fields=[
                ('post_id', models.CharField(max_length=50, primary_key=True, serialize=False, verbose_name='帖子ID')),
                ('title', models.CharField(max_length=200, verbose_name='帖子标题')),
                ('content', models.TextField(verbose_name='帖子内容')),
                ('cover_image_url', models.URLField(blank=True, max_length=500, verbose_name='封面图片')),
                ('view_count', models.IntegerField(default=0, verbose_name='浏览量')),
                ('like_count', models.IntegerField(default=0, verbose_name='点赞数')),
                ('comment_count', models.IntegerField(default=0, verbose_name='评论数')),
                ('status', models.CharField(choices=[('PUBLISHED', '已发布'), ('HIDDEN', '已隐藏')], default='PUBLISHED', max_length=20, verbose_name='帖子状态')),
                ('is_pinned', models.BooleanField(default=False, verbose_name='是否置顶')),
                ('published_at', models.DateTimeField(auto_now_add=True, verbose_name='发布时间')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='更新时间')),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forum_posts', to='core.user', verbose_name='发帖用户')),
                ('category', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='posts', to='core.forumcategory', verbose_name='所属分类')),
            ],
            options={
                'db_table': 'forum_post',
                'verbose_name': '论坛帖子',
                'verbose_name_plural': '论坛帖子',
                'ordering': ['-is_pinned', '-published_at'],
            },
        ),
        migrations.CreateModel(
            name='ForumPostLike',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='点赞时间')),
                ('post', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='likes', to='core.forumpost', verbose_name='帖子')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forum_post_likes', to='core.user', verbose_name='用户')),
            ],
            options={
                'db_table': 'forum_post_like',
                'verbose_name': '论坛帖子点赞',
                'verbose_name_plural': '论坛帖子点赞',
                'unique_together': {('user', 'post')},
            },
        ),
        migrations.CreateModel(
            name='ForumComment',
            fields=[
                ('comment_id', models.CharField(max_length=50, primary_key=True, serialize=False, verbose_name='评论ID')),
                ('content', models.TextField(verbose_name='评论内容')),
                ('like_count', models.IntegerField(default=0, verbose_name='点赞数')),
                ('is_deleted', models.BooleanField(default=False, verbose_name='是否删除')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='创建时间')),
                ('updated_at', models.DateTimeField(auto_now=True, verbose_name='更新时间')),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='forum_comments', to='core.user', verbose_name='评论用户')),
                ('post', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='comments', to='core.forumpost', verbose_name='所属帖子')),
            ],
            options={
                'db_table': 'forum_comment',
                'verbose_name': '论坛评论',
                'verbose_name_plural': '论坛评论',
                'ordering': ['created_at'],
            },
        ),
        migrations.CreateModel(
            name='ForumPostTag',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('tagged_time', models.DateTimeField(auto_now_add=True, verbose_name='打标时间')),
                ('post', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='tag_links', to='core.forumpost', verbose_name='帖子')),
                ('tag', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='post_links', to='core.forumtag', verbose_name='标签')),
            ],
            options={
                'db_table': 'forum_post_tag',
                'verbose_name': '论坛帖子标签关联',
                'verbose_name_plural': '论坛帖子标签关联',
                'unique_together': {('post', 'tag')},
            },
        ),
        migrations.RunPython(seed_forum_categories, unseed_forum_categories),
    ]