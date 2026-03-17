from django.db import models

class User(models.User):
    """
    之后用户加密用 django.contrib.auth.models.AbstractUser 替代
    """
    class RoleChoices(models.TextChoices):
        NORMAL = 'NORMAL', '普通用户'
        ADMIN = 'ADMIN', '系统管理员'

    class RegisterStatusChoices(models.TextChoices):
        PENDING = 'PENDING', '待审核'
        APPROVED = 'APPROVED', '审核通过'
        REJECTED = 'REJECTED', '审核驳回'

    user_id = models.CharField(max_length=50, primary_key=True, verbose_name="用户ID")
    username = models.CharField(max_length=100, unique=True, verbose_name="用户名")
    encrypted_password = models.CharField(max_length=255, verbose_name="加密登录密码")
    real_name = models.CharField(max_length=100, verbose_name="真实姓名")
    id_card = models.CharField(max_length=18, unique=True, verbose_name="身份证号")
    phone = models.CharField(max_length=20, verbose_name="联系电话")
    address = models.CharField(max_length=255, verbose_name="收货地址")
    
    role = models.CharField(
        max_length=20, 
        choices=RoleChoices.choices, 
        default=RoleChoices.NORMAL, 
        verbose_name="用户角色"
    )
    register_status = models.CharField(
        max_length=20, 
        choices=RegisterStatusChoices.choices, 
        default=RegisterStatusChoices.PENDING, 
        verbose_name="注册状态"
    )
    
    register_time = models.DateTimeField(auto_now_add=True, verbose_name="注册时间")
    last_login_time = models.DateTimeField(null=True, blank=True, verbose_name="最后登录时间")

    class Meta:
        db_table = 'user'
        verbose_name = "用户"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.username


class Product(models.Model):
    """商品实体"""
    class StatusChoices(models.TextChoices):
        PENDING = 'PENDING', '待审核'
        APPROVED = 'APPROVED', '审核通过'
        OFF_SHELF = 'OFF_SHELF', '已下架'
        REJECTED = 'REJECTED', '审核驳回'

    product_id = models.CharField(max_length=50, primary_key=True, verbose_name="商品ID")
    product_name = models.CharField(max_length=200, verbose_name="商品名称")
    category = models.CharField(max_length=100, verbose_name="商品分类")
    description = models.TextField(verbose_name="详情描述")
    image_url = models.URLField(max_length=500, verbose_name="商品图片地址")  # URLField更适合存地址
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="单价")
    stock = models.IntegerField(default=0, verbose_name="库存数量")
    
    # 发布者用户ID：外键，关联USER (USER ||--o{ PRODUCT)
    publisher = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='published_products', 
        verbose_name="发布者用户"
    )
    
    product_status = models.CharField(
        max_length=20, 
        choices=StatusChoices.choices, 
        default=StatusChoices.PENDING, 
        verbose_name="商品状态"
    )
    
    publish_time = models.DateTimeField(auto_now_add=True, verbose_name="发布时间")
    review_time = models.DateTimeField(null=True, blank=True, verbose_name="审核时间")

    class Meta:
        db_table = 'product'
        verbose_name = "商品"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.product_name


class RegisterReview(models.Model):
    """注册审查实体"""
    class ResultChoices(models.TextChoices):
        APPROVED = 'APPROVED', '审核通过'
        REJECTED = 'REJECTED', '审核驳回'

    review_id = models.CharField(max_length=50, primary_key=True, verbose_name="审查记录ID")
    
    # 待审核用户ID：1对1关系 (USER ||--|| REGISTER_REVIEW)
    pending_user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE, 
        related_name='register_review', 
        verbose_name="待审核用户"
    )
    
    # 审查管理员ID：外键，关联USER (USER ||--o{ REGISTER_REVIEW)
    admin = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        related_name='performed_register_reviews', 
        verbose_name="审查管理员"
    )
    
    result = models.CharField(max_length=20, choices=ResultChoices.choices, verbose_name="审查结果")
    opinion = models.TextField(null=True, blank=True, verbose_name="审查意见")
    review_time = models.DateTimeField(auto_now_add=True, verbose_name="审查时间")

    class Meta:
        db_table = 'register_review'
        verbose_name = "注册审查记录"
        verbose_name_plural = verbose_name


class ProductReview(models.Model):
    """商品审查实体"""
    class ResultChoices(models.TextChoices):
        APPROVED = 'APPROVED', '审核通过'
        REJECTED = 'REJECTED', '审核驳回'

    review_id = models.CharField(max_length=50, primary_key=True, verbose_name="审查记录ID")
    
    # 待审核商品ID：1对1关系 (PRODUCT ||--|| PRODUCT_REVIEW)
    pending_product = models.OneToOneField(
        Product, 
        on_delete=models.CASCADE, 
        related_name='product_review', 
        verbose_name="待审核商品"
    )
    
    # 审查管理员ID：外键，关联USER (USER ||--o{ PRODUCT_REVIEW)
    admin = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        related_name='performed_product_reviews', 
        verbose_name="审查管理员"
    )
    
    result = models.CharField(max_length=20, choices=ResultChoices.choices, verbose_name="审查结果")
    opinion = models.TextField(null=True, blank=True, verbose_name="审查意见")
    review_time = models.DateTimeField(auto_now_add=True, verbose_name="审查时间")

    class Meta:
        db_table = 'product_review'
        verbose_name = "商品审查记录"
        verbose_name_plural = verbose_name


class Order(models.Model):
    """订单实体"""
    class StatusChoices(models.TextChoices):
        PENDING_PAY = 'PENDING_PAY', '待付款'
        PENDING_SHIP = 'PENDING_SHIP', '已付款待出货'
        SHIPPED = 'SHIPPED', '已出货待收货'
        COMPLETED = 'COMPLETED', '已收货交易完成'
        CANCELED = 'CANCELED', '已取消'

    order_id = models.CharField(max_length=50, primary_key=True, verbose_name="订单ID")
    
    # 买家用户ID：关联USER (USER ||--o{ ORDER 下单)
    buyer = models.ForeignKey(
        User, 
        on_delete=models.PROTECT, 
        related_name='buy_orders', 
        verbose_name="买家"
    )
    
    # 卖家用户ID：关联USER (USER ||--o{ ORDER 接单出货)
    seller = models.ForeignKey(
        User, 
        on_delete=models.PROTECT, 
        related_name='sell_orders', 
        verbose_name="卖家"
    )
    
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, verbose_name="订单总金额")
    address_snapshot = models.CharField(max_length=255, verbose_name="收货地址快照")
    phone_snapshot = models.CharField(max_length=20, verbose_name="联系电话快照")
    
    order_status = models.CharField(
        max_length=20, 
        choices=StatusChoices.choices, 
        default=StatusChoices.PENDING_PAY, 
        verbose_name="订单状态"
    )
    
    order_time = models.DateTimeField(auto_now_add=True, verbose_name="下单时间")
    ship_time = models.DateTimeField(null=True, blank=True, verbose_name="出货时间")
    receive_time = models.DateTimeField(null=True, blank=True, verbose_name="收货时间")

    class Meta:
        db_table = 'order'
        verbose_name = "订单"
        verbose_name_plural = verbose_name

    def __str__(self):
        return f"Order {self.order_id}"


class OrderDetail(models.Model):
    """订单明细实体"""
    detail_id = models.CharField(max_length=50, primary_key=True, verbose_name="订单明细ID")
    
    # 订单ID：关联ORDER (ORDER ||--o{ ORDER_DETAIL)
    order = models.ForeignKey(
        Order, 
        on_delete=models.CASCADE, 
        related_name='details', 
        verbose_name="所属订单"
    )
    
    # 商品ID：关联PRODUCT (PRODUCT ||--o{ ORDER_DETAIL)
    product = models.ForeignKey(
        Product, 
        on_delete=models.PROTECT, 
        related_name='order_details', 
        verbose_name="商品"
    )
    
    quantity = models.IntegerField(verbose_name="购买数量")
    price_snapshot = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="下单单价快照")
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, verbose_name="小计金额")

    class Meta:
        db_table = 'order_detail'
        verbose_name = "订单明细"
        verbose_name_plural = verbose_name


class Message(models.Model):
    """留言实体"""
    message_id = models.CharField(max_length=50, primary_key=True, verbose_name="留言ID")
    
    # 留言用户ID：关联USER (USER ||--o{ MESSAGE)
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='messages', 
        verbose_name="留言用户"
    )
    
    # 关联商品ID：关联PRODUCT (PRODUCT ||--o{ MESSAGE)
    product = models.ForeignKey(
        Product, 
        on_delete=models.CASCADE, 
        related_name='messages', 
        verbose_name="关联商品"
    )
    
    content = models.TextField(verbose_name="留言内容")
    message_time = models.DateTimeField(auto_now_add=True, verbose_name="留言时间")
    
    reply_content = models.TextField(null=True, blank=True, verbose_name="回复内容")
    reply_time = models.DateTimeField(null=True, blank=True, verbose_name="回复时间")

    class Meta:
        db_table = 'message'
        verbose_name = "留言"
        verbose_name_plural = verbose_name

    def __str__(self):
        return f"Message {self.message_id} on Product {self.product_id}"