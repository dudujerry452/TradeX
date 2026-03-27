"""
python manage.py seed
向数据库插入前端测试用的种子数据
"""
from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import (
    Message,
    Order,
    OrderDetail,
    Product,
    ProductReview,
    ProductFavorite,
    RegisterReview,
    Tag,
    ProductTag,
    UserTagPreference,
    User,
)


# ── 数据定义 ────

USERS = [
    dict(
        user_id="seed_admin001",
        username="admin_root",
        email="a@a.com",
        phone_display=None, 
        encrypted_password="hashed_admin_pw",
        real_name="系统管理员",
        id_card="110101198001010001",
        phone="13800000001",
        address="北京市西城区",
        role=User.RoleChoices.ADMIN,
        register_status=User.RegisterStatusChoices.APPROVED,
    ),
    dict(
        user_id="seed_buyer001",
        username="buyer_alice",
        email="b@a.com",
        phone_display="123333", 
        encrypted_password="hashed_pw",
        real_name="爱丽丝",
        id_card="110101199501010002",
        phone="13900000002",
        address="上海市静安区南京西路100号",
        register_status=User.RegisterStatusChoices.APPROVED,
    ),
    dict(
        user_id="seed_buyer002",
        username="buyer_bob",
        email="c@a.com",
        phone_display="12331441", 
        encrypted_password="hashed_pw",
        real_name="鲍勃",
        id_card="110101199301010003",
        phone="13900000003",
        address="广州市天河区天河路200号",
        register_status=User.RegisterStatusChoices.APPROVED,
    ),
    dict(
        user_id="seed_seller001",
        username="seller_techshop",
        email="d@a.com",
        phone_display=None, 
        encrypted_password="hashed_pw",
        real_name="科技数码店",
        id_card="110101198801010004",
        phone="13700000004",
        address="深圳市南山区科技园1号",
        register_status=User.RegisterStatusChoices.APPROVED,
    ),
    dict(
        user_id="seed_seller002",
        username="seller_newbie",
        email="e@a.com",
        phone_display=None, 
        encrypted_password="hashed_pw",
        real_name="新手卖家",
        id_card="110101200001010005",
        phone="13700000005",
        address="成都市锦江区春熙路88号",
        register_status=User.RegisterStatusChoices.PENDING,
    ),
]

PRODUCTS = [
    dict(
        product_id="seed_prod001",
        product_name="苹果 iPhone 16 Pro",
        category="手机数码",
        description="苹果最新旗舰手机, 256GB, 钛金属机身, 支持Apple Intelligence.",
        image_url="https://picsum.photos/seed/iphone/400/400",
        price="9999.00",
        stock=30,
        publisher_id="seed_seller001",
        product_status=Product.StatusChoices.APPROVED,
        view_count=1000,
        sales_count=50,
        favorite_count=2,
        avg_rating=4.8,
    ),
    dict(
        product_id="seed_prod002",
        product_name="索尼 WH-1000XM5 降噪耳机",
        category="音频设备",
        description="旗舰级主动降噪无线耳机, 续航30小时, 支持LDAC高解析音频.",
        image_url="https://picsum.photos/seed/headphone/400/400",
        price="2499.00",
        stock=50,
        publisher_id="seed_seller001",
        product_status=Product.StatusChoices.APPROVED,
        view_count=800,
        sales_count=30,
        favorite_count=1,
        avg_rating=4.5,
    ),
    dict(
        product_id="seed_prod003",
        product_name="Cherry MX 机械键盘",
        category="电脑外设",
        description="Cherry MX红轴, 87键紧凑布局, RGB背光, PBT键帽.",
        image_url="https://picsum.photos/seed/keyboard/400/400",
        price="599.00",
        stock=100,
        publisher_id="seed_seller002",
        product_status=Product.StatusChoices.PENDING,
        view_count=200,
        sales_count=0,
        favorite_count=0,
        avg_rating=0.0,
    ),
    dict(
        product_id="seed_prod004",
        product_name="小米手环 7 (旧款)",
        category="智能穿戴",
        description="此商品已停止销售.",
        image_url="https://picsum.photos/seed/band/400/400",
        price="199.00",
        stock=0,
        publisher_id="seed_seller001",
        product_status=Product.StatusChoices.OFF_SHELF,
        view_count=500,
        sales_count=100,
        favorite_count=0,
        avg_rating=4.2,
    ),
]

REGISTER_REVIEWS = [
    dict(
        review_id="seed_rr001",
        pending_user_id="seed_buyer001",
        admin_id="seed_admin001",
        result=RegisterReview.ResultChoices.APPROVED,
        opinion="资料齐全, 审核通过.",
    ),
    dict(
        review_id="seed_rr002",
        pending_user_id="seed_buyer002",
        admin_id="seed_admin001",
        result=RegisterReview.ResultChoices.APPROVED,
        opinion="审核通过.",
    ),
    dict(
        review_id="seed_rr003",
        pending_user_id="seed_seller001",
        admin_id="seed_admin001",
        result=RegisterReview.ResultChoices.APPROVED,
        opinion="营业执照已核实, 审核通过.",
    ),
]

PRODUCT_REVIEWS = [
    dict(
        review_id="seed_pr001",
        pending_product_id="seed_prod001",
        admin_id="seed_admin001",
        result=ProductReview.ResultChoices.APPROVED,
        opinion="商品描述真实, 价格合理, 审核通过.",
    ),
    dict(
        review_id="seed_pr002",
        pending_product_id="seed_prod002",
        admin_id="seed_admin001",
        result=ProductReview.ResultChoices.APPROVED,
        opinion="审核通过.",
    ),
]

ORDERS = [
    dict(
        order_id="seed_ord001",
        buyer_id="seed_buyer001",
        seller_id="seed_seller001",
        total_amount="9999.00",
        address_snapshot="上海市静安区南京西路100号",
        phone_snapshot="13900000002",
        order_status=Order.StatusChoices.COMPLETED,
        ship_time=timezone.now(),
        receive_time=timezone.now(),
    ),
    dict(
        order_id="seed_ord002",
        buyer_id="seed_buyer002",
        seller_id="seed_seller001",
        total_amount="4998.00",
        address_snapshot="广州市天河区天河路200号",
        phone_snapshot="13900000003",
        order_status=Order.StatusChoices.SHIPPED,
        ship_time=timezone.now(),
    ),
]

ORDER_DETAILS = [
    dict(
        detail_id="seed_od001",
        order_id="seed_ord001",
        product_id="seed_prod001",
        quantity=1,
        price_snapshot="9999.00",
        subtotal="9999.00",
    ),
    dict(
        detail_id="seed_od002",
        order_id="seed_ord002",
        product_id="seed_prod002",
        quantity=2,
        price_snapshot="2499.00",
        subtotal="4998.00",
    ),
]

MESSAGES = [
    dict(
        message_id="seed_msg001",
        user_id="seed_buyer001",
        product_id="seed_prod001",
        content="请问这款手机支持双卡双待吗?",
        reply_content="您好, 支持双卡双待 (nano SIM + eSIM), 感谢关注!",
        reply_time=timezone.now(),
    ),
    dict(
        message_id="seed_msg002",
        user_id="seed_buyer002",
        product_id="seed_prod002",
        content="耳机能连接两台设备同时使用吗?",
        reply_content=None,
        reply_time=None,
    ),
]

TAGS = [
    dict(
        tag_id="seed_tag001",
        tag_name="新品",
        category="营销",
        usage_count=2,
    ),
    dict(
        tag_id="seed_tag002",
        tag_name="热销",
        category="营销",
        usage_count=1,
    ),
    dict(
        tag_id="seed_tag003",
        tag_name="苹果",
        category="品牌",
        usage_count=1,
    ),
    dict(
        tag_id="seed_tag004",
        tag_name="索尼",
        category="品牌",
        usage_count=1,
    ),
    dict(
        tag_id="seed_tag005",
        tag_name="电子产品",
        category="品类",
        usage_count=2,
    ),
]

PRODUCT_TAGS = [
    dict(
        id=1,
        product_id="seed_prod001",
        tag_id="seed_tag001",
        weight=1.0,
    ),
    dict(
        id=2,
        product_id="seed_prod001",
        tag_id="seed_tag003",
        weight=1.0,
    ),
    dict(
        id=3,
        product_id="seed_prod001",
        tag_id="seed_tag005",
        weight=0.8,
    ),
    dict(
        id=4,
        product_id="seed_prod002",
        tag_id="seed_tag002",
        weight=1.0,
    ),
    dict(
        id=5,
        product_id="seed_prod002",
        tag_id="seed_tag004",
        weight=1.0,
    ),
    dict(
        id=6,
        product_id="seed_prod002",
        tag_id="seed_tag005",
        weight=0.8,
    ),
]

USER_TAG_PREFERENCES = [
    dict(
        id=1,
        user_id="seed_buyer001",
        tag_id="seed_tag001",
        score=5.0,
    ),
    dict(
        id=2,
        user_id="seed_buyer001",
        tag_id="seed_tag003",
        score=4.5,
    ),
    dict(
        id=3,
        user_id="seed_buyer002",
        tag_id="seed_tag002",
        score=3.0,
    ),
]

PRODUCT_FAVORITES = [
    dict(
        user_id="seed_buyer001",
        product_id="seed_prod001",
    ),
    dict(
        user_id="seed_buyer001",
        product_id="seed_prod002",
    ),
    dict(
        user_id="seed_buyer002",
        product_id="seed_prod002",
    ),
]


# ── 主逻辑 ────────────────────────────────────────────────────────────────────

class Command(BaseCommand):
    help = "插入前端测试种子数据 (幂等, 可重复运行)"

    def _upsert(self, model, lookup_field, records):
        created_count = 0
        for data in records:
            lookup = {lookup_field: data[lookup_field]}
            _, created = model.objects.get_or_create(
                **lookup, defaults={k: v for k, v in data.items() if k != lookup_field}
            )
            if created:
                created_count += 1
                self.stdout.write(f"  + {model.__name__}: {data[lookup_field]}")
            else:
                self.stdout.write(
                    self.style.WARNING(f"  ~ {model.__name__}: {data[lookup_field]} (已存在, 跳过)")
                )
        return created_count

    def handle(self, *args, **options):
        total = 0

        self.stdout.write(self.style.MIGRATE_HEADING("── 用户 ──"))
        total += self._upsert(User, "user_id", USERS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 商品 ──"))
        total += self._upsert(Product, "product_id", PRODUCTS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 注册审核 ──"))
        total += self._upsert(RegisterReview, "review_id", REGISTER_REVIEWS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 商品审核 ──"))
        total += self._upsert(ProductReview, "review_id", PRODUCT_REVIEWS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 订单 ──"))
        total += self._upsert(Order, "order_id", ORDERS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 订单明细 ──"))
        total += self._upsert(OrderDetail, "detail_id", ORDER_DETAILS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 留言 ──"))
        total += self._upsert(Message, "message_id", MESSAGES)

        self.stdout.write(self.style.MIGRATE_HEADING("── 标签 ──"))
        total += self._upsert(Tag, "tag_id", TAGS)

        self.stdout.write(self.style.MIGRATE_HEADING("── 商品标签关联 ──"))
        total += self._upsert_product_tags()

        self.stdout.write(self.style.MIGRATE_HEADING("── 用户标签偏好 ──"))
        total += self._upsert_user_tag_preferences()

        self.stdout.write(self.style.MIGRATE_HEADING("── 商品收藏 ──"))
        total += self._upsert_product_favorites()

        self.stdout.write(
            self.style.SUCCESS(f"\n完成. 共新增 {total} 条记录.")
        )

    def _upsert_product_tags(self):
        created_count = 0
        for data in PRODUCT_TAGS:
            product = Product.objects.get(product_id=data["product_id"])
            tag = Tag.objects.get(tag_id=data["tag_id"])
            _, created = ProductTag.objects.get_or_create(
                product=product,
                tag=tag,
                defaults={"weight": data["weight"]}
            )
            if created:
                created_count += 1
                self.stdout.write(f"  + ProductTag: {data['product_id']} - {data['tag_id']}")
            else:
                self.stdout.write(
                    self.style.WARNING(f"  ~ ProductTag: {data['product_id']} - {data['tag_id']} (已存在, 跳过)")
                )
        return created_count

    def _upsert_user_tag_preferences(self):
        created_count = 0
        for data in USER_TAG_PREFERENCES:
            user = User.objects.get(user_id=data["user_id"])
            tag = Tag.objects.get(tag_id=data["tag_id"])
            _, created = UserTagPreference.objects.get_or_create(
                user=user,
                tag=tag,
                defaults={"score": data["score"]}
            )
            if created:
                created_count += 1
                self.stdout.write(f"  + UserTagPreference: {data['user_id']} - {data['tag_id']}")
            else:
                self.stdout.write(
                    self.style.WARNING(f"  ~ UserTagPreference: {data['user_id']} - {data['tag_id']} (已存在, 跳过)")
                )
        return created_count

    def _upsert_product_favorites(self):
        created_count = 0
        for data in PRODUCT_FAVORITES:
            user = User.objects.get(user_id=data["user_id"])
            product = Product.objects.get(product_id=data["product_id"])
            _, created = ProductFavorite.objects.get_or_create(
                user=user,
                product=product,
            )
            if created:
                created_count += 1
                self.stdout.write(f"  + ProductFavorite: {data['user_id']} - {data['product_id']}")
            else:
                self.stdout.write(
                    self.style.WARNING(f"  ~ ProductFavorite: {data['user_id']} - {data['product_id']} (已存在, 跳过)")
                )
        return created_count
