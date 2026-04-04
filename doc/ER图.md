erDiagram
    %% ------------------------------ 实体间关系定义 ------------------------------
    USER ||--o{ PRODUCT : "发布"
    USER ||--|| REGISTER_REVIEW : "接受注册审查"
    USER ||--o{ REGISTER_REVIEW : "执行注册审查"
    PRODUCT ||--|| PRODUCT_REVIEW : "接受商品审查"
    USER ||--o{ PRODUCT_REVIEW : "执行商品审查"
    USER ||--o{ ORDER : "下单"
    USER ||--o{ ORDER : "接单出货"
    ORDER ||--o{ ORDER_DETAIL : "包含"
    PRODUCT ||--o{ ORDER_DETAIL : "对应"
    USER ||--o{ MESSAGE : "发布留言"
    PRODUCT ||--o{ MESSAGE : "关联留言"
    PRODUCT ||--o{ PRODUCT_TAG : "拥有"
    TAG ||--o{ PRODUCT_TAG : "标记"
    USER ||--o{ USER_TAG_PREFERENCE : "偏好"
    TAG ||--o{ USER_TAG_PREFERENCE : "被偏好"
    USER ||--o{ PRODUCT_FAVORITE : "收藏"
    PRODUCT ||--o{ PRODUCT_FAVORITE : "被收藏"
    ORDER ||--o{ ORDER_LOG : "记录"
    USER ||--o{ ORDER_LOG : "操作"
    USER ||--o{ NOTIFICATION : "接收"
    CATEGORY ||--o{ PRODUCT : "包含"

    %% ------------------------------ 实体与属性定义 ------------------------------
    USER {
        string user_id PK "用户ID（主键）"
        string username "用户名"
        string email "电子邮箱"
        string phone "电话号码"
        string encrypted_password "加密登录密码"
        string real_name "真实姓名"
        string id_card "身份证号"
        string phone_display "联系电话"
        string address "收货地址"
        string role "用户角色（枚举：普通用户/系统管理员）"
        string register_status "注册状态（枚举：待审核/审核通过/审核驳回）"
        datetime register_time "注册时间"
        datetime last_login_time "最后登录时间"
    }

    PRODUCT {
        string product_id PK "商品ID（主键）"
        string product_name "商品名称"
        string category "商品分类"
        string description "详情描述"
        string image_url "商品图片地址（必填）"
        decimal price "单价"
        int stock "库存数量"
        string publisher_id FK "发布者用户ID（外键，关联USER.user_id）"
        string product_status "商品状态（枚举：待审核/审核通过/已下架/审核驳回）"
        datetime publish_time "发布时间"
        datetime review_time "审核时间"
        int view_count "浏览量"
        int sales_count "销量"
        int favorite_count "收藏数"
        float avg_rating "平均评分"
    }

    REGISTER_REVIEW {
        string review_id PK "审查记录ID（主键）"
        string pending_user_id FK "待审核用户ID（外键，关联USER.user_id）"
        string admin_id FK "审查管理员ID（外键，关联USER.user_id）"
        string result "审查结果（枚举：审核通过/审核驳回）"
        string opinion "审查意见"
        datetime review_time "审查时间"
    }

    PRODUCT_REVIEW {
        string review_id PK "审查记录ID（主键）"
        string pending_product_id FK "待审核商品ID（外键，关联PRODUCT.product_id）"
        string admin_id FK "审查管理员ID（外键，关联USER.user_id）"
        string result "审查结果（枚举：审核通过/审核驳回）"
        string opinion "审查意见"
        datetime review_time "审查时间"
    }

    ORDER {
        string order_id PK "订单ID（主键）"
        string buyer_id FK "买家用户ID（外键，关联USER.user_id）"
        string seller_id FK "卖家用户ID（外键，关联USER.user_id）"
        decimal total_amount "订单总金额"
        string address_snapshot "收货地址快照"
        string phone_snapshot "联系电话快照"
        string order_status "订单状态（枚举：待付款/待发货/已发货/已完成/已取消）"
        datetime order_time "下单时间"
        datetime pay_time "付款时间"
        datetime ship_time "发货时间"
        datetime receive_time "收货时间"
        datetime auto_receive_time "自动确认收货时间"
        string logistics_company "物流公司"
        string logistics_number "物流单号"
        string cancel_reason "取消原因"
    }

    ORDER_DETAIL {
        string detail_id PK "订单明细ID（主键）"
        string order_id FK "订单ID（外键，关联ORDER.order_id）"
        string product_id FK "商品ID（外键，关联PRODUCT.product_id）"
        int quantity "购买数量"
        decimal price_snapshot "下单单价快照"
        decimal subtotal "小计金额"
    }

    MESSAGE {
        string message_id PK "留言ID（主键）"
        string user_id FK "留言用户ID（外键，关联USER.user_id）"
        string product_id FK "关联商品ID（外键，关联PRODUCT.product_id）"
        string content "留言内容"
        datetime message_time "留言时间"
        string reply_content "回复内容"
        datetime reply_time "回复时间"
    }

    TAG {
        string tag_id PK "标签ID（主键）"
        string tag_name "标签名称（唯一）"
        string category "标签分类（如:风格/品牌/场景）"
        int usage_count "使用次数（热度）"
        datetime create_time "创建时间"
    }

    PRODUCT_TAG {
        string product_id FK "商品ID（外键，关联PRODUCT.product_id）"
        string tag_id FK "标签ID（外键，关联TAG.tag_id）"
        float weight "标签权重(0-1,用于推荐排序)"
        datetime tagged_time "打标时间"
    }

    USER_TAG_PREFERENCE {
        string user_id FK "用户ID（外键，关联USER.user_id）"
        string tag_id FK "标签ID（外键，关联TAG.tag_id）"
        float score "偏好分数(基于点击/购买计算)"
        datetime update_time "更新时间"
    }

    PRODUCT_FAVORITE {
        string user_id FK "用户ID（外键，关联USER.user_id）"
        string product_id FK "商品ID（外键，关联PRODUCT.product_id）"
        datetime favorited_time "收藏时间"
    }

    CATEGORY {
        string category_id PK "分类ID（主键）"
        string name "分类名称"
        string description "分类描述"
        int sort_order "排序序号"
        bool is_active "是否启用"
    }

    ORDER_LOG {
        string log_id PK "日志ID（主键）"
        string order_id FK "订单ID（外键，关联ORDER.order_id）"
        string operator_id FK "操作人ID（外键，关联USER.user_id）"
        string action "操作类型（CREATE/PAY/SHIP/RECEIVE/CANCEL）"
        string from_status "原状态"
        string to_status "新状态"
        string remark "备注"
        datetime created_at "操作时间"
    }

    NOTIFICATION {
        string notification_id PK "通知ID（主键）"
        string user_id FK "用户ID（外键，关联USER.user_id）"
        string type "通知类型（ORDER/SYSTEM/MESSAGE）"
        string title "标题"
        string content "内容"
        string related_order_id FK "关联订单ID"
        bool is_read "是否已读"
        datetime created_at "创建时间"
    }
