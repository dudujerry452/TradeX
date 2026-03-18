# TradeX API 文档

## 1. 文档信息

- 项目: TradeX
- 版本: v1
- 协议: HTTP/HTTPS
- 数据格式: JSON
- 字符编码: UTF-8
- 基础路径: /api

## 2. 通用约定

### 2.1 请求头

所有 POST 接口统一使用:

```http
Content-Type: application/json
```

### 2.2 成功响应

- 列表查询: 直接返回数组
- 详情查询: 直接返回对象
- 创建成功: 返回关键字段对象，HTTP 状态码 201

### 2.3 失败响应

错误时统一返回:

```json
{
    "error": "错误描述"
}
```

常见状态码:

- 400: 请求参数错误或唯一约束冲突
- 404: 资源不存在
- 405: 请求方法不允许

## 3. 用户接口

### 3.1 获取用户列表

- 方法: GET
- 路径: /api/users/
- 说明: 获取所有用户（无筛选条件）

响应示例:

```json
[
    {
        "user_id": "u001",
        "username": "alice",
        "real_name": "张三",
        "role": "normal",
        "register_status": "pending",
        "register_time": "2026-03-18T08:00:00Z"
    }
]
```

### 3.2 创建用户

- 方法: POST
- 路径: /api/users/
- 说明: 创建新用户。user_id 可选，不传则后端自动生成。

请求体:

```json
{
    "user_id": "u001",
    "username": "alice",
    "encrypted_password": "pw123",
    "real_name": "爱丽丝",
    "id_card": "110101199001010001",
    "phone": "13900000001",
    "address": "上海市静安区"
}
```

成功响应 (201):

```json
{
    "user_id": "u001",
    "username": "alice"
}
```

失败响应 (400):

```json
{
    "error": "UNIQUE constraint failed: ..."
}
```

### 3.3 获取用户详情

- 方法: GET
- 路径: /api/users/{user_id}/
- 说明: 根据 user_id 查询用户详情

成功响应 (200):

```json
{
    "user_id": "u001",
    "username": "alice",
    "real_name": "爱丽丝",
    "role": "normal",
    "register_status": "pending",
    "phone": "13900000001",
    "address": "上海市静安区"
}
```

失败响应 (404):

```json
{
    "error": "User not found"
}
```

## 4. 商品接口

### 4.1 获取商品列表

- 方法: GET
- 路径: /api/products/
- 说明: 获取所有商品（无筛选条件）

响应示例:

```json
[
    {
        "product_id": "p001",
        "product_name": "测试商品",
        "category": "电子产品",
        "price": "99.00",
        "stock": 10,
        "product_status": "pending"
    }
]
```

### 4.2 创建商品

- 方法: POST
- 路径: /api/products/
- 说明: 创建商品。publisher_id 必须是已存在的用户 ID。

请求体:

```json
{
    "product_id": "p001",
    "product_name": "苹果手机",
    "category": "电子产品",
    "description": "最新款苹果手机",
    "image_url": "http://example.com/phone.jpg",
    "price": "5999.00",
    "stock": 50,
    "publisher_id": "u001"
}
```

成功响应 (201):

```json
{
    "product_id": "p001",
    "product_name": "苹果手机"
}
```

失败响应 (404):

```json
{
    "error": "Publisher not found"
}
```

### 4.3 获取商品详情

- 方法: GET
- 路径: /api/products/{product_id}/
- 说明: 根据 product_id 查询商品详情

成功响应 (200):

```json
{
    "product_id": "p001",
    "product_name": "苹果手机",
    "category": "电子产品",
    "description": "最新款苹果手机",
    "image_url": "http://example.com/phone.jpg",
    "price": "5999.00",
    "stock": 50,
    "product_status": "pending",
    "publisher_id": "u001"
}
```

失败响应 (404):

```json
{
    "error": "Product not found"
}
```

