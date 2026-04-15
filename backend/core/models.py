from django.db import models

class User(models.Model):
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
    email = models.EmailField(max_length=254, unique=True, verbose_name="电子邮箱") 
    phone = models.EmailField(max_length=254, unique=True, verbose_name="电话号码") 
    encrypted_password = models.CharField(max_length=255, verbose_name="加密登录密码")
    real_name = models.CharField(max_length=100, verbose_name="真实姓名")
    id_card = models.CharField(max_length=18, unique=True, verbose_name="身份证号")
    phone_display = models.CharField(max_length=20, null=True, verbose_name="联系电话")
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


class Category(models.Model):
    """商品分类实体"""
    category_id = models.CharField(max_length=50, primary_key=True, verbose_name="分类ID")
    name = models.CharField(max_length=100, verbose_name="分类名称")
    description = models.TextField(blank=True, verbose_name="分类描述")
    sort_order = models.IntegerField(default=0, verbose_name="排序顺序")
    is_active = models.BooleanField(default=True, verbose_name="是否启用")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="创建时间")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="更新时间")

    class Meta:
        db_table = 'category'
        verbose_name = "商品分类"
        verbose_name_plural = "商品分类"
        ordering = ['sort_order', 'name']

    def __str__(self):
        return self.name


class Product(models.Model):
    """商品实体"""
    class StatusChoices(models.TextChoices):
        PENDING = 'PENDING', '待审核'
        APPROVED = 'APPROVED', '审核通过'
        OFF_SHELF = 'OFF_SHELF', '已下架'
        REJECTED = 'REJECTED', '审核驳回'

    product_id = models.CharField(max_length=50, primary_key=True, verbose_name="商品ID")
    product_name = models.CharField(max_length=200, verbose_name="商品名称")
    # 旧字段保留兼容
    category = models.CharField(max_length=100, blank=True, verbose_name="商品分类(旧)")
    # 新外键关联
    category_ref = models.ForeignKey(
        Category,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='products',
        verbose_name="所属分类"
    )
    description = models.TextField(verbose_name="详情描述")
    image_url = models.URLField(max_length=500, verbose_name="商品图片地址")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="单价")
    stock = models.IntegerField(default=0, verbose_name="库存数量")

    # 推荐系统字段
    view_count = models.IntegerField(default=0, verbose_name="浏览量")
    sales_count = models.IntegerField(default=0, verbose_name="销量")
    favorite_count = models.IntegerField(default=0, verbose_name="收藏数")
    avg_rating = models.FloatField(default=0.0, verbose_name="平均评分")

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

    # 新增物流相关字段
    logistics_company = models.CharField(max_length=100, blank=True, verbose_name="物流公司")
    logistics_number = models.CharField(max_length=100, blank=True, verbose_name="物流单号")
    logistics_info = models.JSONField(default=dict, blank=True, verbose_name="物流信息快照")
    cancel_reason = models.TextField(blank=True, verbose_name="取消原因")
    pay_time = models.DateTimeField(null=True, blank=True, verbose_name="付款时间")
    auto_receive_time = models.DateTimeField(null=True, blank=True, verbose_name="自动确认收货时间")

    class Meta:
        db_table = 'order'
        verbose_name = "订单"
        verbose_name_plural = verbose_name

    def __str__(self):
        return f"Order {self.order_id}"

    def can_transition_to(self, new_status):
        """检查状态是否允许转换"""
        valid_transitions = {
            'PENDING_PAY': ['PENDING_SHIP', 'CANCELED'],
            'PENDING_SHIP': ['SHIPPED', 'CANCELED'],
            'SHIPPED': ['COMPLETED', 'CANCELED'],
            'COMPLETED': [],
            'CANCELED': [],
        }
        return new_status in valid_transitions.get(self.order_status, [])


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


class Tag(models.Model):
    """标签实体"""
    tag_id = models.CharField(max_length=50, primary_key=True, verbose_name="标签ID")
    tag_name = models.CharField(max_length=100, unique=True, verbose_name="标签名称")
    category = models.CharField(max_length=100, verbose_name="标签分类")
    usage_count = models.IntegerField(default=0, verbose_name="使用次数")
    create_time = models.DateTimeField(auto_now_add=True, verbose_name="创建时间")

    class Meta:
        db_table = 'tag'
        verbose_name = "标签"
        verbose_name_plural = verbose_name

    def __str__(self):
        return self.tag_name


class ProductTag(models.Model):
    """商品标签关联实体"""
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='product_tags',
        verbose_name="商品"
    )
    tag = models.ForeignKey(
        Tag,
        on_delete=models.CASCADE,
        related_name='tagged_products',
        verbose_name="标签"
    )
    weight = models.FloatField(default=1.0, verbose_name="标签权重")
    tagged_time = models.DateTimeField(auto_now_add=True, verbose_name="打标时间")

    class Meta:
        db_table = 'product_tag'
        verbose_name = "商品标签关联"
        verbose_name_plural = verbose_name
        unique_together = ['product', 'tag']

    def __str__(self):
        return f"{self.product.product_name} - {self.tag.tag_name}"


class UserTagPreference(models.Model):
    """用户标签偏好实体"""
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='tag_preferences',
        verbose_name="用户"
    )
    tag = models.ForeignKey(
        Tag,
        on_delete=models.CASCADE,
        related_name='user_preferences',
        verbose_name="标签"
    )
    score = models.FloatField(default=0.0, verbose_name="偏好分数")
    update_time = models.DateTimeField(auto_now=True, verbose_name="更新时间")

    class Meta:
        db_table = 'user_tag_preference'
        verbose_name = "用户标签偏好"
        verbose_name_plural = verbose_name
        unique_together = ['user', 'tag']

    def __str__(self):
        return f"{self.user.username} - {self.tag.tag_name}"


class ProductFavorite(models.Model):
    """商品收藏实体"""
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='favorites',
        verbose_name="用户"
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='favorited_by',
        verbose_name="商品"
    )
    favorited_time = models.DateTimeField(auto_now_add=True, verbose_name="收藏时间")

    class Meta:
        db_table = 'product_favorite'
        verbose_name = "商品收藏"
        verbose_name_plural = verbose_name
        unique_together = ['user', 'product']

    def __str__(self):
        return f"{self.user.username} - {self.product.product_name}"


class OrderLog(models.Model):
    """订单操作日志"""
    class ActionChoices(models.TextChoices):
        CREATE = 'CREATE', '创建订单'
        PAY = 'PAY', '支付订单'
        SHIP = 'SHIP', '卖家发货'
        RECEIVE = 'RECEIVE', '确认收货'
        CANCEL = 'CANCEL', '取消订单'
        AUTO_COMPLETE = 'AUTO_COMPLETE', '自动完成'

    log_id = models.CharField(max_length=50, primary_key=True, verbose_name="日志ID")
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='logs',
        verbose_name="所属订单"
    )
    operator = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_logs',
        verbose_name="操作人"
    )
    action = models.CharField(max_length=20, choices=ActionChoices.choices, verbose_name="操作类型")
    from_status = models.CharField(max_length=20, null=True, blank=True, verbose_name="原状态")
    to_status = models.CharField(max_length=20, verbose_name="新状态")
    remark = models.TextField(blank=True, verbose_name="备注")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="操作时间")

    class Meta:
        db_table = 'order_log'
        verbose_name = "订单操作日志"
        verbose_name_plural = verbose_name
        ordering = ['-created_at']

    def __str__(self):
        return f"Log {self.log_id} for Order {self.order_id}"


class Notification(models.Model):
    """用户通知"""
    class TypeChoices(models.TextChoices):
        ORDER = 'ORDER', '订单通知'
        SYSTEM = 'SYSTEM', '系统通知'
        MESSAGE = 'MESSAGE', '消息通知'

    notification_id = models.CharField(max_length=50, primary_key=True, verbose_name="通知ID")
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notifications',
        verbose_name="接收用户"
    )
    type = models.CharField(max_length=20, choices=TypeChoices.choices, verbose_name="通知类型")
    title = models.CharField(max_length=200, verbose_name="通知标题")
    content = models.TextField(verbose_name="通知内容")
    related_order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications',
        verbose_name="关联订单"
    )
    is_read = models.BooleanField(default=False, verbose_name="是否已读")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="创建时间")

    class Meta:
        db_table = 'notification'
        verbose_name = "用户通知"
        verbose_name_plural = verbose_name
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification {self.notification_id} for {self.user.username}"


class ChatMessage(models.Model):
    """聊天消息实体"""
    message_id = models.CharField(max_length=50, primary_key=True, verbose_name="消息ID")

    # 发送者
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_chat_messages',
        verbose_name="发送者"
    )

    # 接收者
    receiver = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_chat_messages',
        verbose_name="接收者"
    )

    # 关联商品（可选）
    related_product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='chat_messages',
        verbose_name="关联商品"
    )

    # 关联订单（可选）
    related_order = models.ForeignKey(
        Order,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='chat_messages',
        verbose_name="关联订单"
    )

    content = models.TextField(verbose_name="消息内容")
    is_read = models.BooleanField(default=False, verbose_name="是否已读")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="创建时间")

    class Meta:
        db_table = 'chat_message'
        verbose_name = "聊天消息"
        verbose_name_plural = "聊天消息"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['sender', 'receiver']),
            models.Index(fields=['receiver', 'is_read']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"Chat {self.message_id}: {self.sender.username} -> {self.receiver.username}"