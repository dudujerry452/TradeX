import json

from django.test import TestCase
from django.urls import reverse

from .models import Product, User, Tag, ProductTag, UserTagPreference, ProductFavorite


# ── helpers ───────────────────────────────────────────────────────────────────

def make_user(**kwargs):
    defaults = dict(
        user_id="u001",
        username="testuser",
        email = "a@a.com",
        encrypted_password="hashed_pw",
        real_name="张三",
        id_card="110101199001011234",
        phone="13800000000",
        phone_display=None, 
        address="北京市朝阳区",
    )
    defaults.update(kwargs)
    return User.objects.create(**defaults)


def make_product(publisher, **kwargs):
    defaults = dict(
        product_id="p001",
        product_name="测试商品",
        category="电子产品",
        description="这是一个测试商品",
        image_url="http://example.com/img.jpg",
        price="99.00",
        stock=10,
        publisher=publisher,
    )
    defaults.update(kwargs)
    return Product.objects.create(**defaults)


# ── User API tests ─────────────────────────────────────────────────────────────

class UserListCreateTests(TestCase):

    def test_get_empty_user_list(self):
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_user(self):
        payload = {
            "username": "alice",
            "email": "alice@gmail.com", 
            "encrypted_password": "pw123",
            "real_name": "爱丽丝",
            "id_card": "110101199001010001",
            "phone": "13900000001",
            "address": "上海市静安区",
        }
        response = self.client.post(
            "/api/users/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["username"], "alice")

    def test_get_user_list_after_create(self):
        make_user()
        response = self.client.get("/api/users/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["username"], "testuser")

    def test_create_user_duplicate_username(self):
        make_user()
        payload = {
            "username": "testuser",   # duplicate
            "email": "lisi@qq.com", 
            "encrypted_password": "pw",
            "real_name": "李四",
            "id_card": "110101199001019999",
            "phone": "13900000099",
            "address": "广州市天河区",
        }
        response = self.client.post(
            "/api/users/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        # view now catches IntegrityError and returns 400
        self.assertEqual(response.status_code, 400)
        self.assertIn("detail", response.json())


class UserDetailTests(TestCase):

    def setUp(self):
        self.user = make_user()

    def test_get_existing_user(self):
        response = self.client.get("/api/users/u001/")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["user_id"], "u001")
        self.assertEqual(body["username"], "testuser")
        self.assertEqual(body["real_name"], "张三")
        self.assertEqual(body["role"], User.RoleChoices.NORMAL)
        self.assertEqual(body["register_status"], User.RegisterStatusChoices.PENDING)

    def test_get_nonexistent_user_returns_404(self):
        response = self.client.get("/api/users/does_not_exist/")
        self.assertEqual(response.status_code, 404)
        self.assertIn("detail", response.json())


# ── Product API tests ──────────────────────────────────────────────────────────

class ProductListCreateTests(TestCase):

    def setUp(self):
        self.publisher = make_user()

    def test_get_empty_product_list(self):
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_product(self):
        payload = {
            "product_id": "p001",
            "product_name": "苹果手机",
            "category": "电子产品",
            "description": "最新款苹果手机",
            "image_url": "http://example.com/phone.jpg",
            "price": "5999.00",
            "stock": 50,
            "publisher_id": "u001",
        }
        response = self.client.post(
            "/api/products/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["product_id"], "p001")
        self.assertEqual(body["product_name"], "苹果手机")
        self.assertTrue(Product.objects.filter(product_id="p001").exists())

    def test_create_product_invalid_publisher(self):
        payload = {
            "product_name": "商品X",
            "category": "其他",
            "description": "描述",
            "image_url": "http://example.com/x.jpg",
            "price": "1.00",
            "stock": 1,
            "publisher_id": "nonexistent_user",
        }
        response = self.client.post(
            "/api/products/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 404)
        self.assertIn("detail", response.json())

    def test_get_product_list_after_create(self):
        make_product(self.publisher)
        response = self.client.get("/api/products/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["product_name"], "测试商品")
        self.assertEqual(data[0]["product_status"], Product.StatusChoices.PENDING)

    def test_create_product_with_tags(self):
        # 先创建标签
        tag1 = make_tag(tag_id="t001", tag_name="热销")
        tag2 = make_tag(tag_id="t002", tag_name="新品")
        payload = {
            "product_id": "p002",
            "product_name": "带标签的商品",
            "category": "电子产品",
            "description": "这是一个带标签的测试商品",
            "image_url": "http://example.com/img2.jpg",
            "price": "199.00",
            "stock": 20,
            "publisher_id": "u001",
            "tag_ids": ["t001", "t002"],
        }
        response = self.client.post(
            "/api/products/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["product_id"], "p002")

        # 验证标签已关联
        product = Product.objects.get(product_id="p002")
        tags = list(product.product_tags.values_list("tag__tag_name", flat=True))
        self.assertIn("热销", tags)
        self.assertIn("新品", tags)

        # 验证标签使用次数已更新
        tag1.refresh_from_db()
        tag2.refresh_from_db()
        self.assertGreater(tag1.usage_count, 0)
        self.assertGreater(tag2.usage_count, 0)


class ProductDetailTests(TestCase):

    def setUp(self):
        publisher = make_user()
        self.product = make_product(publisher)

    def test_get_existing_product(self):
        response = self.client.get("/api/products/p001/")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["product_id"], "p001")
        self.assertEqual(body["product_name"], "测试商品")
        self.assertEqual(body["publisher_id"], "u001")

    def test_get_nonexistent_product_returns_404(self):
        response = self.client.get("/api/products/no_such_product/")
        self.assertEqual(response.status_code, 404)
        self.assertIn("detail", response.json())


# ── helpers for tag tests ─────────────────────────────────────────────────────

def make_tag(**kwargs):
    defaults = dict(
        tag_id="t001",
        tag_name="测试标签",
        category="风格",
        usage_count=0,
    )
    defaults.update(kwargs)
    return Tag.objects.create(**defaults)


# ── Tag API tests ─────────────────────────────────────────────────────────────

class TagListCreateTests(TestCase):

    def test_get_empty_tag_list(self):
        response = self.client.get("/api/tags/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_tag(self):
        payload = {
            "tag_id": "t001",
            "tag_name": "新品上市",
            "category": "营销",
        }
        response = self.client.post(
            "/api/tags/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["tag_name"], "新品上市")
        self.assertEqual(body["category"], "营销")
        self.assertTrue(Tag.objects.filter(tag_id="t001").exists())

    def test_get_tag_list_after_create(self):
        make_tag()
        response = self.client.get("/api/tags/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["tag_name"], "测试标签")


class TagDetailTests(TestCase):

    def setUp(self):
        self.tag = make_tag()

    def test_get_existing_tag(self):
        response = self.client.get("/api/tags/t001/")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["tag_id"], "t001")
        self.assertEqual(body["tag_name"], "测试标签")

    def test_get_nonexistent_tag_returns_404(self):
        response = self.client.get("/api/tags/no_such_tag/")
        self.assertEqual(response.status_code, 404)
        self.assertIn("detail", response.json())


# ── ProductTag API tests ─────────────────────────────────────────────────────

class ProductTagListCreateTests(TestCase):

    def setUp(self):
        self.publisher = make_user()
        self.product = make_product(self.publisher)
        self.tag = make_tag()

    def test_get_empty_product_tag_list(self):
        response = self.client.get("/api/product-tags/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_product_tag(self):
        payload = {
            "product_id": "p001",
            "tag_id": "t001",
            "weight": 0.8,
        }
        response = self.client.post(
            "/api/product-tags/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["product_id"], "p001")
        self.assertEqual(body["tag_id"], "t001")
        self.assertEqual(body["tag_name"], "测试标签")
        self.assertEqual(body["weight"], 0.8)

    def test_get_product_tags(self):
        ProductTag.objects.create(product=self.product, tag=self.tag, weight=1.0)
        response = self.client.get("/api/products/p001/tags/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["tag_name"], "测试标签")

    def test_create_product_tag_invalid_product(self):
        payload = {
            "product_id": "nonexistent_product",
            "tag_id": "t001",
            "weight": 1.0,
        }
        response = self.client.post(
            "/api/product-tags/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 404)


# ── UserTagPreference API tests ───────────────────────────────────────────────

class UserTagPreferenceListCreateTests(TestCase):

    def setUp(self):
        self.user = make_user()
        self.tag = make_tag()

    def test_get_empty_user_tag_preference_list(self):
        response = self.client.get("/api/user-tag-preferences/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_user_tag_preference(self):
        payload = {
            "user_id": "u001",
            "tag_id": "t001",
            "score": 5.0,
        }
        response = self.client.post(
            "/api/user-tag-preferences/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["user_id"], "u001")
        self.assertEqual(body["tag_id"], "t001")
        self.assertEqual(body["score"], 5.0)

    def test_get_user_tag_preferences(self):
        UserTagPreference.objects.create(user=self.user, tag=self.tag, score=3.5)
        response = self.client.get("/api/users/u001/tag-preferences/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["score"], 3.5)

    def test_create_user_tag_preference_invalid_user(self):
        payload = {
            "user_id": "nonexistent_user",
            "tag_id": "t001",
            "score": 5.0,
        }
        response = self.client.post(
            "/api/user-tag-preferences/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 404)


# ── ProductFavorite API tests

class ProductFavoriteListCreateTests(TestCase):

    def setUp(self):
        self.publisher = make_user()
        self.user = make_user(user_id="u002", username="testuser2", id_card="110101199001011235", phone="13900000001", email="b@b.com")
        self.product = make_product(self.publisher)

    def test_get_empty_product_favorite_list(self):
        response = self.client.get("/api/product-favorites/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_create_product_favorite(self):
        payload = {
            "user_id": "u002",
            "product_id": "p001",
        }
        response = self.client.post(
            "/api/product-favorites/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["user_id"], "u002")
        self.assertEqual(body["product_id"], "p001")

        # 验证商品收藏数已更新
        self.product.refresh_from_db()
        self.assertEqual(self.product.favorite_count, 1)

    def test_get_user_favorites(self):
        ProductFavorite.objects.create(user=self.user, product=self.product)
        response = self.client.get("/api/users/u002/favorites/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["product_id"], "p001")

    def test_get_product_favorites(self):
        ProductFavorite.objects.create(user=self.user, product=self.product)
        response = self.client.get("/api/products/p001/favorites/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["user_id"], "u002")

    def test_create_product_favorite_invalid_user(self):
        payload = {
            "user_id": "nonexistent_user",
            "product_id": "p001",
        }
        response = self.client.post(
            "/api/product-favorites/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 404)


# ── 推荐系统测试 ───────────────────────────────────────────────────────────────

class TrendingRecommendationsTests(TestCase):
    """热门推荐API测试"""

    def setUp(self):
        self.publisher = make_user()
        # 创建多个商品，设置不同的热度指标
        self.product1 = make_product(
            self.publisher,
            product_id="p001",
            product_name="高热度商品",
            view_count=1000,
            sales_count=500,
            favorite_count=300,
            avg_rating=4.8,
            product_status=Product.StatusChoices.APPROVED,
        )
        self.product2 = make_product(
            self.publisher,
            product_id="p002",
            product_name="中热度商品",
            view_count=500,
            sales_count=200,
            favorite_count=100,
            avg_rating=4.5,
            product_status=Product.StatusChoices.APPROVED,
        )
        self.product3 = make_product(
            self.publisher,
            product_id="p003",
            product_name="低热度商品",
            view_count=100,
            sales_count=50,
            favorite_count=20,
            avg_rating=4.0,
            product_status=Product.StatusChoices.APPROVED,
        )
        # 未审核商品，不应出现在推荐中
        self.product4 = make_product(
            self.publisher,
            product_id="p004",
            product_name="待审核商品",
            view_count=9999,
            sales_count=9999,
            favorite_count=9999,
            avg_rating=5.0,
            product_status=Product.StatusChoices.PENDING,
        )

    def test_get_trending_recommendations(self):
        """测试热门推荐按热度正确排序"""
        response = self.client.get("/api/recommendations/trending/?limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 3)  # 只返回APPROVED商品

        # 验证按热度排序（高热度在前）
        self.assertEqual(data[0]["product_id"], "p001")
        self.assertEqual(data[1]["product_id"], "p002")
        self.assertEqual(data[2]["product_id"], "p003")

    def test_get_trending_with_limit(self):
        """测试限制返回数量"""
        response = self.client.get("/api/recommendations/trending/?limit=2")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 2)
        # 只返回最热的2个
        self.assertEqual(data[0]["product_id"], "p001")
        self.assertEqual(data[1]["product_id"], "p002")

    def test_trending_excludes_non_approved(self):
        """测试未审核商品不会出现在推荐中"""
        response = self.client.get("/api/recommendations/trending/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        product_ids = [p["product_id"] for p in data]
        self.assertNotIn("p004", product_ids)  # 待审核商品不应出现


class PersonalizedRecommendationsTests(TestCase):
    """个性化推荐API测试"""

    def setUp(self):
        self.user = make_user()
        self.publisher = make_user(
            user_id="u002",
            username="publisher",
            email="pub@test.com",
            id_card="110101199001011235",
            phone="13900000001",
        )

        # 创建标签
        self.tag1 = make_tag(tag_id="t001", tag_name="科技")
        self.tag2 = make_tag(tag_id="t002", tag_name="时尚")
        self.tag3 = make_tag(tag_id="t003", tag_name="美食")

        # 创建商品并设置标签
        self.product1 = make_product(
            self.publisher,
            product_id="p001",
            product_name="科技产品A",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.product1, tag=self.tag1, weight=1.0)

        self.product2 = make_product(
            self.publisher,
            product_id="p002",
            product_name="科技产品B",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.product2, tag=self.tag1, weight=0.8)

        self.product3 = make_product(
            self.publisher,
            product_id="p003",
            product_name="时尚产品",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.product3, tag=self.tag2, weight=1.0)

        self.product4 = make_product(
            self.publisher,
            product_id="p004",
            product_name="美食产品",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.product4, tag=self.tag3, weight=1.0)

    def test_personalized_with_tag_preference(self):
        """测试有标签偏好时的个性化推荐"""
        # 用户偏好"科技"标签
        UserTagPreference.objects.create(user=self.user, tag=self.tag1, score=5.0)

        response = self.client.get(f"/api/recommendations/personalized/?user_id={self.user.user_id}&limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        # 应该返回与科技标签相关的商品
        self.assertGreaterEqual(len(data), 2)
        product_ids = [p["product_id"] for p in data]
        self.assertIn("p001", product_ids)
        self.assertIn("p002", product_ids)

    def test_personalized_excludes_favorited(self):
        """测试已收藏商品不会出现在推荐中"""
        # 用户偏好"科技"标签
        UserTagPreference.objects.create(user=self.user, tag=self.tag1, score=5.0)
        # 收藏了其中一个科技产品
        ProductFavorite.objects.create(user=self.user, product=self.product1)
        self.product1.favorite_count = 1
        self.product1.save()

        response = self.client.get(f"/api/recommendations/personalized/?user_id={self.user.user_id}&limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        product_ids = [p["product_id"] for p in data]
        # 已收藏的商品不应出现
        self.assertNotIn("p001", product_ids)
        # 未收藏的科技产品应该出现
        self.assertIn("p002", product_ids)

    def test_personalized_fallback_to_trending(self):
        """测试无标签偏好时回退到热门推荐"""
        # 设置商品热度
        self.product1.view_count = 1000
        self.product1.sales_count = 500
        self.product1.save()

        response = self.client.get(f"/api/recommendations/personalized/?user_id={self.user.user_id}&limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        # 应该返回商品（基于热度）
        self.assertGreaterEqual(len(data), 1)

    def test_personalized_without_user_id(self):
        """测试未提供user_id时返回热门推荐"""
        response = self.client.get("/api/recommendations/personalized/?limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertGreaterEqual(len(data), 1)

    def test_personalized_invalid_user(self):
        """测试无效用户时返回热门推荐"""
        response = self.client.get("/api/recommendations/personalized/?user_id=nonexistent&limit=10")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertGreaterEqual(len(data), 1)


class SimilarProductsTests(TestCase):
    """相似商品API测试"""

    def setUp(self):
        self.publisher = make_user()

        # 创建标签
        self.tag1 = make_tag(tag_id="t001", tag_name="手机")
        self.tag2 = make_tag(tag_id="t002", tag_name="苹果")
        self.tag3 = make_tag(tag_id="t003", tag_name="安卓")

        # 创建商品
        # 目标商品：有"手机"和"苹果"标签
        self.target_product = make_product(
            self.publisher,
            product_id="p001",
            product_name="iPhone 15",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.target_product, tag=self.tag1, weight=1.0)
        ProductTag.objects.create(product=self.target_product, tag=self.tag2, weight=1.0)

        # 相似商品1：有"手机"和"苹果"标签（2个共同标签）
        self.similar1 = make_product(
            self.publisher,
            product_id="p002",
            product_name="iPhone 14",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.similar1, tag=self.tag1, weight=1.0)
        ProductTag.objects.create(product=self.similar1, tag=self.tag2, weight=1.0)

        # 相似商品2：只有"手机"标签（1个共同标签）
        self.similar2 = make_product(
            self.publisher,
            product_id="p003",
            product_name="Samsung S24",
            product_status=Product.StatusChoices.APPROVED,
        )
        ProductTag.objects.create(product=self.similar2, tag=self.tag1, weight=1.0)
        ProductTag.objects.create(product=self.similar2, tag=self.tag3, weight=1.0)

        # 不相似商品：没有共同标签
        self.unrelated = make_product(
            self.publisher,
            product_id="p004",
            product_name="篮球",
            product_status=Product.StatusChoices.APPROVED,
        )

        # 待审核商品，不应出现在结果中
        self.pending = make_product(
            self.publisher,
            product_id="p005",
            product_name="iPhone 13",
            product_status=Product.StatusChoices.PENDING,
        )
        ProductTag.objects.create(product=self.pending, tag=self.tag1, weight=1.0)

    def test_get_similar_products(self):
        """测试获取相似商品"""
        response = self.client.get(f"/api/recommendations/similar/?product_id={self.target_product.product_id}&limit=5")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        # 应该返回2个相似商品
        self.assertEqual(len(data), 2)
        # 按共同标签数量排序：p002有2个，p003有1个
        self.assertEqual(data[0]["product_id"], "p002")
        self.assertEqual(data[1]["product_id"], "p003")
        # 验证相关度分数
        self.assertEqual(data[0]["relevance_score"], 2.0)
        self.assertEqual(data[1]["relevance_score"], 1.0)

    def test_similar_excludes_self(self):
        """测试相似商品不包括自己"""
        response = self.client.get(f"/api/recommendations/similar/?product_id={self.target_product.product_id}")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        product_ids = [p["product_id"] for p in data]
        self.assertNotIn("p001", product_ids)

    def test_similar_excludes_non_approved(self):
        """测试未审核商品不会出现在相似商品中"""
        response = self.client.get(f"/api/recommendations/similar/?product_id={self.target_product.product_id}")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        product_ids = [p["product_id"] for p in data]
        self.assertNotIn("p005", product_ids)  # 待审核商品

    def test_similar_with_limit(self):
        """测试限制返回数量"""
        response = self.client.get(f"/api/recommendations/similar/?product_id={self.target_product.product_id}&limit=1")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 1)
        # 只返回最相似的
        self.assertEqual(data[0]["product_id"], "p002")

    def test_similar_nonexistent_product(self):
        """测试查询不存在的商品返回404"""
        response = self.client.get("/api/recommendations/similar/?product_id=nonexistent")
        self.assertEqual(response.status_code, 404)

    def test_similar_product_no_tags(self):
        """测试没有标签的商品返回空列表"""
        # 创建没有标签的商品
        no_tag_product = make_product(
            self.publisher,
            product_id="p006",
            product_name="无标签商品",
            product_status=Product.StatusChoices.APPROVED,
        )
        response = self.client.get(f"/api/recommendations/similar/?product_id={no_tag_product.product_id}")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 0)


class ProductViewTests(TestCase):
    """商品浏览记录API测试"""

    def setUp(self):
        self.publisher = make_user()
        self.product = make_product(
            self.publisher,
            product_id="p001",
            product_name="测试商品",
            view_count=100,
            product_status=Product.StatusChoices.APPROVED,
        )

    def test_record_product_view(self):
        """测试记录商品浏览"""
        initial_view_count = self.product.view_count

        response = self.client.post(f"/api/products/{self.product.product_id}/view/")
        self.assertEqual(response.status_code, 200)
        data = response.json()

        self.assertTrue(data["success"])
        self.assertEqual(data["view_count"], initial_view_count + 1)

        # 验证数据库已更新
        self.product.refresh_from_db()
        self.assertEqual(self.product.view_count, initial_view_count + 1)

    def test_record_view_multiple_times(self):
        """测试多次记录浏览"""
        for i in range(3):
            response = self.client.post(f"/api/products/{self.product.product_id}/view/")
            self.assertEqual(response.status_code, 200)

        # 验证浏览次数增加了3次
        self.product.refresh_from_db()
        self.assertEqual(self.product.view_count, 103)

    def test_record_view_nonexistent_product(self):
        """测试记录不存在商品的浏览返回404"""
        response = self.client.post("/api/products/nonexistent/view/")
        self.assertEqual(response.status_code, 404)


class RecommendationPaginationTests(TestCase):
    """推荐系统分页功能测试"""

    def setUp(self):
        self.client = Client()
        # 创建测试用户
        self.user = User.objects.create(
            user_id="test_user",
            username="testuser",
            email="test@example.com",
            encrypted_password="pwd",
            real_name="Test User",
            id_card="123456789012345678",
            phone="test@test.com",
            address="Test Address",
            register_status="APPROVED"
        )
        # 创建20个测试商品
        self.products = []
        for i in range(20):
            p = Product.objects.create(
                product_id=f"prod_{i}",
                product_name=f"Product {i}",
                category="electronics",
                description=f"Description {i}",
                image_url=f"http://example.com/{i}.jpg",
                price=100.0 + i,
                stock=10,
                publisher=self.user,
                product_status="APPROVED",
                view_count=i * 10,
                sales_count=i * 5,
                favorite_count=i * 3,
                avg_rating=4.0
            )
            self.products.append(p)

    def test_trending_recommendations_pagination(self):
        """测试热门推荐分页"""
        # 第一页
        response = self.client.get('/api/recommendations/trending/?limit=5&offset=0')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 5)

        # 第二页
        response = self.client.get('/api/recommendations/trending/?limit=5&offset=5')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 5)

        # 验证两页数据不重复
        first_page = self.client.get('/api/recommendations/trending/?limit=5&offset=0')
        second_page = self.client.get('/api/recommendations/trending/?limit=5&offset=5')
        first_ids = {p['product_id'] for p in first_page.json()}
        second_ids = {p['product_id'] for p in second_page.json()}
        self.assertEqual(len(first_ids & second_ids), 0)  # 无交集

    def test_trending_recommendations_offset_beyond_total(self):
        """测试offset超过总数时返回空列表"""
        response = self.client.get('/api/recommendations/trending/?limit=10&offset=100')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 0)

    def test_personalized_recommendations_pagination(self):
        """测试个性化推荐分页"""
        # 创建用户标签偏好
        tag = Tag.objects.create(tag_id="tag1", tag_name="Electronics", category="category")
        UserTagPreference.objects.create(user=self.user, tag=tag, score=5.0)

        # 给商品添加标签
        for p in self.products[:10]:
            ProductTag.objects.create(product=p, tag=tag, weight=1.0)

        # 第一页
        response = self.client.get(f'/api/recommendations/personalized/?user_id={self.user.user_id}&limit=3&offset=0')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 3)

        # 第二页
        response = self.client.get(f'/api/recommendations/personalized/?user_id={self.user.user_id}&limit=3&offset=3')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 3)

    def test_personalized_recommendations_no_user_fallback(self):
        """测试无用户时回退到热门推荐"""
        response = self.client.get('/api/recommendations/personalized/?limit=5&offset=0')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 5)

    def test_invalid_offset_returns_empty(self):
        """测试负offset返回空列表"""
        response = self.client.get('/api/recommendations/trending/?limit=10&offset=-1')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data), 0)


class UserTagPreferenceOnFavoriteTests(TestCase):
    """收藏时自动更新标签偏好测试"""

    def setUp(self):
        self.publisher = make_user()
        self.user = make_user(
            user_id="u002",
            username="testuser2",
            email="b@b.com",
            id_card="110101199001011235",
            phone="13900000001",
        )

        # 创建标签
        self.tag1 = make_tag(tag_id="t001", tag_name="科技")
        self.tag2 = make_tag(tag_id="t002", tag_name="新品")

        # 创建商品并关联标签
        self.product = make_product(
            self.publisher,
            product_id="p001",
            product_name="科技新品",
        )
        ProductTag.objects.create(product=self.product, tag=self.tag1, weight=1.0)
        ProductTag.objects.create(product=self.product, tag=self.tag2, weight=0.8)

    def test_create_tag_preference_on_first_favorite(self):
        """测试首次收藏时创建标签偏好"""
        # 确认用户没有标签偏好
        self.assertEqual(UserTagPreference.objects.filter(user=self.user).count(), 0)

        # 收藏商品
        payload = {
            "user_id": self.user.user_id,
            "product_id": self.product.product_id,
        }
        response = self.client.post(
            "/api/product-favorites/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)

        # 验证标签偏好已创建
        preferences = UserTagPreference.objects.filter(user=self.user)
        self.assertEqual(preferences.count(), 2)

        # 验证初始分数为1.0
        tag1_pref = UserTagPreference.objects.get(user=self.user, tag=self.tag1)
        self.assertEqual(tag1_pref.score, 1.0)
        tag2_pref = UserTagPreference.objects.get(user=self.user, tag=self.tag2)
        self.assertEqual(tag2_pref.score, 1.0)

    def test_increase_tag_preference_on_repeat_favorite(self):
        """测试重复收藏时增加标签偏好分数"""
        # 先收藏一次
        ProductFavorite.objects.create(user=self.user, product=self.product)
        UserTagPreference.objects.create(user=self.user, tag=self.tag1, score=1.0)
        UserTagPreference.objects.create(user=self.user, tag=self.tag2, score=1.0)

        # 删除收藏记录（模拟取消收藏后再次收藏）
        ProductFavorite.objects.filter(user=self.user, product=self.product).delete()

        # 再次收藏
        payload = {
            "user_id": self.user.user_id,
            "product_id": self.product.product_id,
        }
        response = self.client.post(
            "/api/product-favorites/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)

        # 验证标签偏好分数增加
        tag1_pref = UserTagPreference.objects.get(user=self.user, tag=self.tag1)
        self.assertEqual(tag1_pref.score, 1.5)  # 1.0 + 0.5
        tag2_pref = UserTagPreference.objects.get(user=self.user, tag=self.tag2)
        self.assertEqual(tag2_pref.score, 1.5)

    def test_tag_preference_score_cap(self):
        """测试标签偏好分数上限为10.0"""
        # 先创建一个高分数的标签偏好
        UserTagPreference.objects.create(user=self.user, tag=self.tag1, score=9.8)

        # 收藏商品
        payload = {
            "user_id": self.user.user_id,
            "product_id": self.product.product_id,
        }
        response = self.client.post(
            "/api/product-favorites/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)

        # 验证分数不超过10.0 (9.8 + 0.5 = 10.3, 但上限为10.0)
        tag1_pref = UserTagPreference.objects.get(user=self.user, tag=self.tag1)
        self.assertEqual(tag1_pref.score, 10.0)
