import 'package:flutter/material.dart';
import '../../icons.dart';
import '../../services/seller_service.dart';
import '../../services/order_service.dart';
import 'my_products_page.dart';
import '../order/order_list_page.dart';

/// 卖家中心主页
class SellerCenterPage extends StatefulWidget {
  const SellerCenterPage({super.key});

  @override
  State<SellerCenterPage> createState() => _SellerCenterPageState();
}

class _SellerCenterPageState extends State<SellerCenterPage> {
  Map<String, dynamic> _stats = {
    'on_sale_count': 0,
    'pending_ship_count': 0,
    'today_sales': 0.0,
    'total_sales': 0.0,
  };
  bool _isLoadingStats = true;

  List<dynamic> _recentOrders = [];
  bool _isLoadingOrders = true;

  List<dynamic> _recentProducts = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStats(),
      _loadRecentOrders(),
      _loadRecentProducts(),
    ]);
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final result = await SellerService.getSellerStats().timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'success': false, 'message': '请求超时'},
      );
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          if (result['success']) {
            _stats = result['data'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final result = await OrderService.getOrders(
        role: 'seller',
        limit: 3,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'orders': []},
      );
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          _recentOrders = result['orders'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _loadRecentProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final result = await SellerService.getMyProducts(limit: 3).timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'success': false, 'products': []},
      );
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          if (result['success']) {
            _recentProducts = result['products'] ?? [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING_PAY':
        return Colors.amber;
      case 'PENDING_SHIP':
        return Colors.blue;
      case 'SHIPPED':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING_PAY':
        return '待付款';
      case 'PENDING_SHIP':
        return '待发货';
      case 'SHIPPED':
        return '待收货';
      case 'COMPLETED':
        return '已完成';
      case 'CANCELED':
        return '已取消';
      default:
        return status;
    }
  }

  String _getProductStatusText(String status) {
    switch (status) {
      case 'APPROVED':
        return '在售';
      case 'OFF_SHELF':
        return '已下架';
      case 'PENDING':
        return '待审核';
      case 'REJECTED':
        return '未通过';
      default:
        return status;
    }
  }

  Color _getProductStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'OFF_SHELF':
        return Colors.grey;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToMyProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyProductsPage()),
    ).then((_) => _loadData());
  }

  void _navigateToOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrderListPage(role: 'seller'),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '卖家中心',
          style: TextStyle(
            color: Color(0xFF1A1A2C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFCE965B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 统计数据卡片
              _buildStatsCard(),
              const SizedBox(height: 12),
              // 快捷入口网格
              _buildQuickAccessGrid(),
              const SizedBox(height: 12),
              // 最近订单
              _buildRecentOrdersSection(),
              const SizedBox(height: 12),
              // 最近商品
              _buildRecentProductsSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 统计数据卡片（渐变背景）
  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCE965B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _isLoadingStats
          ? const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          : Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.store, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '今日数据',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '在售商品',
                      _stats['on_sale_count'].toString(),
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      '待发货',
                      _stats['pending_ship_count'].toString(),
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      '今日收入',
                      '¥${_stats['today_sales'].toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  /// 快捷入口网格
  Widget _buildQuickAccessGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快捷入口',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAccessItem(
                'cube',
                '我的商品',
                const Color(0xFFCE965B),
                _navigateToMyProducts,
              ),
              _buildQuickAccessItem(
                'credit-card',
                '订单管理',
                Colors.blue,
                _navigateToOrders,
              ),
              _buildQuickAccessItem(
                'star',
                '数据中心',
                Colors.green,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据中心功能开发中')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem(
    String iconName,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: HeroIcons.icon(
                iconName,
                size: 28,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 最近订单区域
  Widget _buildRecentOrdersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近订单',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2C),
                ),
              ),
              GestureDetector(
                onTap: _navigateToOrders,
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    HeroIcons.chevronRight(
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingOrders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                ),
              ),
            )
          else if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HeroIcons.icon(
                      'shopping-bag',
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无订单',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recentOrders
                  .take(3)
                  .map((order) => _buildOrderItem(order))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(dynamic order) {
    final products = order['products'] ?? [];
    final firstProduct = products.isNotEmpty ? products[0] : null;
    final productCount = products.length;

    return GestureDetector(
      onTap: _navigateToOrders,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                firstProduct?['image_url'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image, color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstProduct?['product_name'] ?? '未知商品',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (productCount > 1)
                    Text(
                      '等 $productCount 件商品',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['order_status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(order['order_status']),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(order['order_status']),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${order['total_amount']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order['buyer_id'].toString().substring(0, 8),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 最近商品区域
  Widget _buildRecentProductsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近商品',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2C),
                ),
              ),
              GestureDetector(
                onTap: _navigateToMyProducts,
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    HeroIcons.chevronRight(
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingProducts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                ),
              ),
            )
          else if (_recentProducts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HeroIcons.icon(
                      'cube',
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无商品',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recentProducts
                  .take(3)
                  .map((product) => _buildProductItem(product))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProductItem(dynamic product) {
    return GestureDetector(
      onTap: _navigateToMyProducts,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product['image_url'] ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image, color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['product_name'] ?? '未知商品',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '库存 ${product['stock']} · 销量 ${product['sales_count']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getProductStatusColor(product['product_status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getProductStatusText(product['product_status']),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getProductStatusColor(product['product_status']),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${product['price']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['view_count']} 浏览',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
