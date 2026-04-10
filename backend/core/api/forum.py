"""
core/api/forum.py — 论坛相关接口
"""
import uuid
from typing import Optional

import jwt
from django.db.models import F, Q
from ninja import Router
from ninja.errors import HttpError

from core.models import (
    ForumCategory,
    ForumComment,
    ForumPost,
    ForumPostLike,
    ForumPostTag,
    ForumTag,
    User,
)
from .common import (
    JWT_SECRET,
    auth,
    ForumCommentIn,
    ForumPostIn,
)

router = Router()


def _get_user_from_request(request):
    header = request.headers.get('Authorization', '')
    if not header.startswith('Bearer '):
        return None

    token = header.removeprefix('Bearer ').strip()
    if not token:
        return None

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return User.objects.get(user_id=payload.get('user_id'))
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
        return None


def _serialize_comment(comment: ForumComment) -> dict:
    return {
        'comment_id': comment.comment_id,
        'post_id': comment.post_id,
        'author_id': comment.author_id,
        'author_name': comment.author.username,
        'content': comment.content,
        'like_count': comment.like_count,
        'is_deleted': comment.is_deleted,
        'created_at': comment.created_at,
        'updated_at': comment.updated_at,
    }


def _serialize_post(post: ForumPost, liked_post_ids: set[str] | None = None, include_comments: bool = False) -> dict:
    comments = None
    if include_comments:
        comments = [
            _serialize_comment(comment)
            for comment in post.comments.select_related('author').filter(is_deleted=False)
        ]

    return {
        'post_id': post.post_id,
        'title': post.title,
        'content': post.content,
        'cover_image_url': post.cover_image_url,
        'author_id': post.author_id,
        'author_name': post.author.username,
        'category_id': post.category_id,
        'category_name': post.category.name if post.category else None,
        'tags': [link.tag.tag_name for link in post.tag_links.select_related('tag').all()],
        'view_count': post.view_count,
        'like_count': post.like_count,
        'comment_count': post.comment_count,
        'status': post.status,
        'is_pinned': post.is_pinned,
        'published_at': post.published_at,
        'updated_at': post.updated_at,
        'is_liked': liked_post_ids is not None and post.post_id in liked_post_ids,
        'comments': comments,
    }


def _get_liked_post_ids(user_id: Optional[str]) -> set[str]:
    if not user_id:
        return set()
    return set(
        ForumPostLike.objects.filter(user__user_id=user_id).values_list('post__post_id', flat=True)
    )


def _apply_ordering(queryset, ordering: str):
    ordering_map = {
        '-published_at': '-published_at',
        'published_at': 'published_at',
        '-like_count': '-like_count',
        'like_count': 'like_count',
        '-comment_count': '-comment_count',
        'comment_count': 'comment_count',
        '-view_count': '-view_count',
        'view_count': 'view_count',
    }

    if ordering == 'hot':
        return queryset.annotate(
            hot_score=F('like_count') * 3 + F('comment_count') * 2 + F('view_count') * 0.2
        ).order_by('-is_pinned', '-hot_score', '-published_at')

    return queryset.order_by('-is_pinned', ordering_map.get(ordering, '-published_at'))


@router.get('/categories/', tags=['论坛'], summary='获取论坛分类列表', auth=None)
def list_forum_categories(request):
    return ForumCategory.objects.filter(is_active=True).order_by('sort_order', 'name')


@router.get('/tags/', tags=['论坛'], summary='获取论坛标签列表', auth=None)
def list_forum_tags(request, q: str = ''):
    tags = ForumTag.objects.all().order_by('-usage_count', 'tag_name')
    if q.strip():
        tags = tags.filter(tag_name__icontains=q.strip())
    return tags


@router.get('/posts/', tags=['论坛'], summary='获取论坛帖子列表', auth=None)
def list_forum_posts(
    request,
    q: str = '',
    category_id: str = '',
    tag: str = '',
    ordering: str = '-published_at',
    limit: int = 20,
    offset: int = 0,
):
    posts = ForumPost.objects.filter(status=ForumPost.StatusChoices.PUBLISHED).select_related('author', 'category').prefetch_related('tag_links__tag')

    if category_id.strip():
        posts = posts.filter(
            Q(category__category_id=category_id.strip()) |
            Q(category__name=category_id.strip())
        )

    if tag.strip():
        posts = posts.filter(
            Q(tag_links__tag__tag_id=tag.strip()) |
            Q(tag_links__tag__tag_name__icontains=tag.strip())
        )

    if q.strip():
        posts = posts.filter(
            Q(title__icontains=q.strip()) |
            Q(content__icontains=q.strip())
        )

    if q.strip() or category_id.strip() or tag.strip():
        posts = posts.distinct()

    posts = _apply_ordering(posts, ordering)

    user = _get_user_from_request(request)
    liked_post_ids = _get_liked_post_ids(user.user_id if user else None)

    return [
        _serialize_post(post, liked_post_ids=liked_post_ids, include_comments=False)
        for post in posts[offset:offset + limit]
    ]


@router.get('/posts/{post_id}/', tags=['论坛'], summary='获取帖子详情', auth=None)
def get_forum_post(request, post_id: str):
    try:
        post = ForumPost.objects.select_related('author', 'category').prefetch_related('tag_links__tag', 'comments__author').get(post_id=post_id)
    except ForumPost.DoesNotExist:
        raise HttpError(404, '帖子不存在')

    post.view_count += 1
    post.save(update_fields=['view_count'])

    user = _get_user_from_request(request)
    liked_post_ids = _get_liked_post_ids(user.user_id if user else None)
    return _serialize_post(post, liked_post_ids=liked_post_ids, include_comments=True)


@router.post('/posts/', response={201: dict}, tags=['论坛'], summary='发布论坛帖子', auth=auth)
def create_forum_post(request, data: ForumPostIn):
    author = request.auth

    category = None
    if data.category_id:
        try:
            category = ForumCategory.objects.get(category_id=data.category_id)
        except ForumCategory.DoesNotExist:
            raise HttpError(404, '论坛分类不存在')

    post = ForumPost.objects.create(
        post_id=uuid.uuid4().hex[:20],
        title=data.title.strip(),
        content=data.content.strip(),
        cover_image_url=data.cover_image_url or '',
        author=author,
        category=category,
        status=ForumPost.StatusChoices.PUBLISHED,
    )

    tag_names: list[str] = []
    for raw_tag in data.tag_names:
        tag_name = raw_tag.strip()
        if tag_name and tag_name not in tag_names:
            tag_names.append(tag_name)

    for tag_name in tag_names:
        tag, _ = ForumTag.objects.get_or_create(
            tag_name=tag_name,
            defaults={'tag_id': uuid.uuid4().hex[:20]},
        )
        ForumPostTag.objects.get_or_create(post=post, tag=tag)
        tag.usage_count = ForumPostTag.objects.filter(tag=tag).count()
        tag.save(update_fields=['usage_count'])

    post.refresh_from_db()
    return 201, _serialize_post(post, liked_post_ids=set(), include_comments=False)


@router.post('/posts/{post_id}/like/', tags=['论坛'], summary='点赞或取消点赞帖子', auth=auth)
def toggle_forum_post_like(request, post_id: str):
    user = request.auth
    try:
        post = ForumPost.objects.get(post_id=post_id)
    except ForumPost.DoesNotExist:
        raise HttpError(404, '帖子不存在')

    like = ForumPostLike.objects.filter(user=user, post=post)
    if like.exists():
        like.delete()
        post.like_count = max(0, post.like_count - 1)
        post.save(update_fields=['like_count'])
        liked = False
    else:
        ForumPostLike.objects.create(user=user, post=post)
        post.like_count += 1
        post.save(update_fields=['like_count'])
        liked = True

    return {'success': True, 'liked': liked, 'like_count': post.like_count, 'comment_count': post.comment_count}


@router.get('/posts/{post_id}/comments/', tags=['论坛'], summary='获取帖子评论列表', auth=None)
def list_forum_comments(request, post_id: str):
    comments = ForumComment.objects.select_related('author', 'post').filter(post__post_id=post_id, is_deleted=False)
    return [_serialize_comment(comment) for comment in comments]


@router.post('/posts/{post_id}/comments/', response={201: dict}, tags=['论坛'], summary='发表评论', auth=auth)
def create_forum_comment(request, post_id: str, data: ForumCommentIn):
    try:
        post = ForumPost.objects.get(post_id=post_id)
    except ForumPost.DoesNotExist:
        raise HttpError(404, '帖子不存在')

    comment = ForumComment.objects.create(
        comment_id=uuid.uuid4().hex[:20],
        post=post,
        author=request.auth,
        content=data.content.strip(),
    )

    post.comment_count += 1
    post.save(update_fields=['comment_count'])

    return 201, _serialize_comment(comment)