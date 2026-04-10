from django.contrib import admin

from .models import (
	ForumCategory,
	ForumComment,
	ForumPost,
	ForumPostLike,
	ForumPostTag,
	ForumTag,
)

admin.site.register(ForumCategory)
admin.site.register(ForumTag)
admin.site.register(ForumPost)
admin.site.register(ForumPostTag)
admin.site.register(ForumPostLike)
admin.site.register(ForumComment)
