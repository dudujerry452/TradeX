import json

from django.test import TestCase
from django.urls import reverse

from .models import Product, User


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
            "user_id": "u001",
            "username": "alice",
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
        self.assertEqual(body["user_id"], "u001")
        self.assertEqual(body["username"], "alice")
        self.assertTrue(User.objects.filter(user_id="u001").exists())

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
