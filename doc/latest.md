# API 文档

## 概述

本文档记录 TradeX 电商平台的所有后端 API 接口。

---

## 认证接口

### POST /api/login
用户登录

**请求体：**
```json
{
    "email": "a@a.com",
    "username": "admin_root",
    "password": "string"
}
```

**响应：**
```json
{
    "user_id": "string",
    "username": "string",
    "role": "string"
}
```

---

## 用户接口

### GET /api/users/
获取所有用户列表

**响应：**
```json
[
    {
        "user_id": "string",
        "username": "string",
        "email": "string",
        "real_name": "string",
        "role": "string",
        "register_status": "string",
        "phone": "string",
        "phone_display": "string",
        "address": "string"
    }
]
```

### POST /api/users/
注册新用户

**请求体：**
```json
{
    "email": "string",
    "username": "string",
    "encrypted_password": "string",
    "real_name": "string",
    "id_card": "string",
    "phone": "string",
    "phone_display": "string",
    "address": "string"
}
```

**响应：** 201 Created
```json
{
    "user_id": "string",
    "username": "string",
    "email": "string",
    "real_name": "string",
    "role": "string",
    "register_status": "string",
    "phone": "string",
    "phone_display": "string",
    "address": "string"
}
```

### GET /api/users/{user_id}/
查询用户详情

**响应：** 同用户列表项

### GET /api/users/{user_id}/tag-preferences/
获取用户的标签偏好

**响应：**
```json
[
    {
        "user_id": "string",
        "tag_id": "string",
        "tag_name": "string",
        "score": 5.0,
        "update_time": "2024-01-01T00:00:00Z"
    }
]
```

### GET /api/users/{user_id}/favorites/
获取用户的收藏列表

**响应：**
```json
[
    {
        "user_id": "string",
        "product_id": "string",
        "product_name": "string",
        "favorited_time": "2024-01-01T00:00:00Z"
    }
]
```

---

## 商品接口

### GET /api/products/
获取商品列表

**响应：**
```json
[
    {
        "product_id": "string",
        "product_name": "string",
        "category": "string",
        "description": "string",
        "image_url": "string",
        "price": 9999.00,
        "stock": 30,
        "product_status": "string",
        "publisher_id": "string",
        "view_count": 1000,
        "sales_count": 50,
        "favorite_count": 2,
        "avg_rating": 4.8
    }
]
```

### POST /api/products/
发布新商品

**请求体：**
```json
{
    "product_id": "string (可选)",
    "product_name": "string",
    "category": "string",
    "description": "string",
    "image_url": "string",
    "price": 9999.00,
    "stock": 30,
    "publisher_id": "string",
    "tag_ids": ["tag001", "tag002"]
}
```

**说明：** `tag_ids` 为可选字段，不传或为空数组则不关联标签

**响应：** 201 Created

### GET /api/products/{product_id}/
查询商品详情

**响应：** 同商品列表项

### GET /api/products/{product_id}/tags/
获取商品的所有标签

**响应：**
```json
[
    {
        "tag_id": "string",
        "tag_name": "string",
        "category": "string",
        "usage_count": 10,
        "create_time": "2024-01-01T00:00:00Z"
    }
]
```

### GET /api/products/{product_id}/favorites/
获取收藏该商品的用户列表

**响应：**
```json
[
    {
        "user_id": "string",
        "product_id": "string",
        "product_name": "string",
        "favorited_time": "2024-01-01T00:00:00Z"
    }
]
```

---

## 标签接口

### GET /api/tags/
获取标签列表

**响应：**
```json
[
    {
        "tag_id": "string",
        "tag_name": "string",
        "category": "string",
        "usage_count": 10,
        "create_time": "2024-01-01T00:00:00Z"
    }
]
```

### POST /api/tags/
创建新标签

**请求体：**
```json
{
    "tag_id": "string (可选)",
    "tag_name": "string",
    "category": "string"
}
```

**响应：** 201 Created

### GET /api/tags/{tag_id}/
查询标签详情

**响应：** 同标签列表项

---

## 商品标签关联接口

### GET /api/product-tags/
获取商品标签关联列表

**响应：**
```json
[
    {
        "product_id": "string",
        "tag_id": "string",
        "tag_name": "string",
        "weight": 1.0,
        "tagged_time": "2024-01-01T00:00:00Z"
    }
]
```

### POST /api/product-tags/
为商品添加标签

**请求体：**
```json
{
    "product_id": "string",
    "tag_id": "string",
    "weight": 1.0
}
```

**说明：** `weight` 默认为 1.0，用于推荐排序

**响应：** 201 Created

---

## 用户标签偏好接口

### GET /api/user-tag-preferences/
获取用户标签偏好列表

**响应：**
```json
[
    {
        "user_id": "string",
        "tag_id": "string",
        "tag_name": "string",
        "score": 5.0,
        "update_time": "2024-01-01T00:00:00Z"
    }
]
```

### POST /api/user-tag-preferences/
设置用户标签偏好

**请求体：**
```json
{
    "user_id": "string",
    "tag_id": "string",
    "score": 5.0
}
```

**说明：** `score` 为偏好分数，基于用户点击/购买行为计算

**响应：** 201 Created

---

## 商品收藏接口

### GET /api/product-favorites/
获取所有商品收藏列表

**响应：**
```json
[
    {
        "user_id": "string",
        "product_id": "string",
        "product_name": "string",
        "favorited_time": "2024-01-01T00:00:00Z"
    }
]
```

### POST /api/product-favorites/
收藏商品

**请求体：**
```json
{
    "user_id": "string",
    "product_id": "string"
}
```

**说明：** 收藏成功后，商品的 `favorite_count` 会自动更新

**响应：** 201 Created

---

## RAG 接口

### POST /api/rag/add-product
向 RAG 知识库添加商品

**请求体：**
```json
{
    "id": "string",
    "name": "string",
    "price": 9999.00,
    "desc": "string",
    "category": "string"
}
```

**响应：**
```json
{
    "status": "ok",
    "msg": "商品已加入AI知识库"
}
```

### POST /api/rag/chat/stream
基于商品知识库的 AI 流式问答（SSE）

**请求体：**
```json
{
    "question": "string",
    "n_results": 3
}
```

**说明：** 返回 SSE 流，包含匹配商品信息和 AI 回答

---

## 模型字段说明

### Product 新增字段（推荐系统）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `view_count` | int | 0 | 浏览量 |
| `sales_count` | int | 0 | 销量 |
| `favorite_count` | int | 0 | 收藏数 |
| `avg_rating` | float | 0.0 | 平均评分（1-5分） |

### Tag 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `tag_id` | string | 标签ID（主键） |
| `tag_name` | string | 标签名称（唯一） |
| `category` | string | 标签分类（如：营销/品牌/品类） |
| `usage_count` | int | 使用次数（热度） |
| `create_time` | datetime | 创建时间 |

### ProductTag 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `product` | FK | 商品外键 |
| `tag` | FK | 标签外键 |
| `weight` | float | 标签权重（0-1，用于推荐排序） |
| `tagged_time` | datetime | 打标时间 |

### UserTagPreference 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `user` | FK | 用户外键 |
| `tag` | FK | 标签外键 |
| `score` | float | 偏好分数（基于点击/购买计算） |
| `update_time` | datetime | 更新时间 |

### ProductFavorite 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `user` | FK | 用户外键 |
| `product` | FK | 商品外键 |
| `favorited_time` | datetime | 收藏时间 |

---

## 变更记录

### 2024-03-27

1. **新增字段**
   - Product 表添加 `view_count`, `sales_count`, `favorite_count`, `avg_rating` 字段

2. **新增接口**
   - 标签管理：/api/tags/*
   - 商品标签关联：/api/product-tags/*
   - 用户标签偏好：/api/user-tag-preferences/*
   - 商品收藏：/api/product-favorites/*

3. **接口更新**
   - POST /api/products/ 支持同时传入 `tag_ids` 关联标签
   - 商品响应包含推荐系统字段（view_count, sales_count 等）
