"""
core/api/__init__.py — 聚合所有模块的 Router
"""
from ninja import Router

from .auth import router as auth_router
from .users import router as users_router, user_tag_prefs_router
from .products import router as products_router
from .categories import router as categories_router
from .tags import router as tags_router, product_tags_router
from .favorites import router as favorites_router
from .forum import router as forum_router
from .recommendations import router as recommendations_router
from .orders import router as orders_router
from .notifications import router as notifications_router
from .uploads import router as uploads_router
from .rag import router as rag_router
from .system import router as system_router
from .chat import router as chat_router

router = Router()

# 认证
router.add_router("/login", auth_router, tags=["认证"])

# 用户相关
router.add_router("/users", users_router, tags=["用户"])

# 商品相关
router.add_router("/products", products_router, tags=["商品"])

# 分类相关
router.add_router("/categories", categories_router, tags=["分类"])

# 标签相关
router.add_router("/tags", tags_router, tags=["标签"])

# 商品标签关联（独立路由）
router.add_router("/product-tags", product_tags_router, tags=["商品标签"])

# 用户标签偏好（独立路由）
router.add_router("/user-tag-preferences", user_tag_prefs_router, tags=["用户标签偏好"])

# 收藏相关
router.add_router("/product-favorites", favorites_router, tags=["商品收藏"])

# 论坛相关
router.add_router("/forum", forum_router, tags=["论坛"])

# 推荐系统
router.add_router("/recommendations", recommendations_router, tags=["推荐系统"])

# 订单系统
router.add_router("/orders", orders_router, tags=["订单"])

# 通知系统
router.add_router("/notifications", notifications_router, tags=["通知"])

# 文件上传
router.add_router("/uploads", uploads_router, tags=["文件"])

# RAG AI
router.add_router("/rag", rag_router, tags=["RAG"])

# 系统
router.add_router("/health", system_router, tags=["System"])

# 聊天系统
router.add_router("/chat", chat_router, tags=["聊天"])
