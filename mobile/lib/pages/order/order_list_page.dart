import 'dart:async';
import 'package:flutter/material.dart';
import '../../icons.dart';
import '../../services/order_service.dart';
import 'order_detail_page.dart';

class OrderListPage extends StatefulWidget {
  final String role; // 'buyer' or 'seller'

  const OrderListPage({
    super.key,
    this.role = 'buyer',
  });

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['全部', '待付款', '待发货', '待收货', '已完成'];
  final List<String?> _statusFilters = [null, 'PENDING_PAY', 'PENDING_SHIP', 'SHIPPED', 'COMPLETED'];

  final Map<int, List<dynamic>> _ordersMap = {};
  final Map<int, bool> _loadingMap = {};
  final Map<int, bool> _hasMoreMap = {};
  int _limit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadOrders(0, refresh: true);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final index = _tabController.index;
      if (_ordersMap[index] == null || _ordersMap[index]!.isEmpty) {
        _loadOrders(index, refresh: true);
      }
    }
  }

  Future<void> _loadOrders(int tabIndex, {bool refresh = false}) async {
    if (_loadingMap[tabIndex] == true && !refresh) return;

    setState(() {
      _loadingMap[tabIndex] = true;
    });

    try {
      final result = await OrderService.getOrders(
        status: _statusFilters[tabIndex],
        role: widget.role,
        limit: _limit,
        offset: refresh ? 0 : (_ordersMap[tabIndex]?.length ?? 0),
      );

      final orders = result['orders'] ?? [];
      final total = result['total'] ?? 0;

      setState(() {
        if (refresh || _ordersMap[tabIndex] == null) {
          _ordersMap[tabIndex] = orders;
        } else {
          _ordersMap[tabIndex]!.addAll(orders);
        }
        _hasMoreMap[tabIndex] = (_ordersMap[tabIndex]?.length ?? 0) < total;
        _loadingMap[tabIndex] = false;
      });
    } catch (e) {
      setState(() {
        _loadingMap[tabIndex] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
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

  List<Widget> _buildActionButtons(dynamic order) {
    final status = order['order_status'];
    final orderId = order['order_id'];
    final isBuyer = widget.role == 'buyer';
    final buttons = <Widget>[];

    if (isBuyer) {
      // 买家按钮
      switch (status) {
        case 'PENDING_PAY':
          buttons.add(
            OutlinedButton(
              onPressed: () => _cancelOrder(orderId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('取消订单'),
            ),
          );
          buttons.add(const SizedBox(width: 8));
          buttons.add(
            ElevatedButton(
              onPressed: () => _payOrder(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE965B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('去付款'),
            ),
          );
          break;
        case 'PENDING_SHIP':
          buttons.add(
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCE965B),
                side: const BorderSide(color: Color(0xFFCE965B)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('提醒发货'),
            ),
          );
          break;
        case 'SHIPPED':
          buttons.add(
            OutlinedButton(
              onPressed: () => _showLogistics(order),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('查看物流'),
            ),
          );
          buttons.add(const SizedBox(width: 8));
          buttons.add(
            ElevatedButton(
              onPressed: () => _receiveOrder(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE965B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('确认收货'),
            ),
          );
          break;
        case 'COMPLETED':
          buttons.add(
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('再次购买'),
            ),
          );
          break;
      }
    } else {
      // 卖家按钮
      switch (status) {
        case 'PENDING_SHIP':
          buttons.add(
            ElevatedButton(
              onPressed: () => _showShipDialog(orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE965B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('发货'),
            ),
          );
          break;
        case 'SHIPPED':
          buttons.add(
            OutlinedButton(
              onPressed: () => _showLogistics(order),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('修改物流'),
            ),
          );
          break;
      }
    }

    return buttons;
  }

  Future<void> _payOrder(String orderId) async {
    try {
      await OrderService.payOrder(orderId);
      _refreshCurrentTab();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支付失败: $e')),
        );
      }
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认取消'),
        content: const Text('确定要取消这个订单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await OrderService.cancelOrder(orderId);
        _refreshCurrentTab();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('订单已取消')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('取消失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _receiveOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认收货'),
        content: const Text('确认已收到商品吗？确认后款项将打给卖家。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再等等'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE965B),
              foregroundColor: Colors.white,
            ),
            child: const Text('确认收货'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await OrderService.receiveOrder(orderId);
        _refreshCurrentTab();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('确认收货成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _showShipDialog(String orderId) async {
    final companyController = TextEditingController();
    final numberController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('填写物流信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: companyController,
              decoration: const InputDecoration(
                labelText: '物流公司',
                hintText: '如：顺丰速运',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: '物流单号',
                hintText: '请输入物流单号',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE965B),
              foregroundColor: Colors.white,
            ),
            child: const Text('确认发货'),
          ),
        ],
      ),
    );

    if (result == true &&
        companyController.text.isNotEmpty &&
        numberController.text.isNotEmpty) {
      try {
        await OrderService.shipOrder(
          orderId,
          logisticsCompany: companyController.text,
          logisticsNumber: numberController.text,
        );
        _refreshCurrentTab();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发货成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发货失败: $e')),
          );
        }
      }
    }
  }

  void _showLogistics(dynamic order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('物流信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('物流公司: ${order['logistics_company'] ?? '暂无'}'),
            const SizedBox(height: 8),
            Text('物流单号: ${order['logistics_number'] ?? '暂无'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _refreshCurrentTab() {
    _loadOrders(_tabController.index, refresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.role == 'buyer' ? '我的订单' : '卖出的订单',
          style: const TextStyle(
            color: Color(0xFF1A1A2C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFCE965B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFCE965B),
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (index) {
          return RefreshIndicator(
            onRefresh: () => _loadOrders(index, refresh: true),
            color: const Color(0xFFCE965B),
            child: _buildOrderList(index),
          );
        }),
      ),
    );
  }

  Widget _buildOrderList(int tabIndex) {
    final orders = _ordersMap[tabIndex] ?? [];
    final isLoading = _loadingMap[tabIndex] ?? false;

    if (isLoading && orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcons.icon(
              'shopping-bag',
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无订单',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length + ((_hasMoreMap[tabIndex] ?? false) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _loadOrders(tabIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE965B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('加载更多'),
              ),
            ),
          );
        }

        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final products = order['products'] ?? [];
    final firstProduct = products.isNotEmpty ? products[0] : null;
    final productCount = products.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              orderId: order['order_id'],
            ),
          ),
        ).then((_) => _refreshCurrentTab());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            // 订单头部：ID + 状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订单号: ${order['order_id'].toString().substring(order['order_id'].toString().length - 8)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['order_status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusText(order['order_status']),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(order['order_status']),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // 商品信息
            if (firstProduct != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      firstProduct['image_url'] ?? '',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
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
                          firstProduct['product_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${firstProduct['price']} x ${firstProduct['quantity']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (productCount > 1)
                          Text(
                            '等 $productCount 件商品',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            // 金额和操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '实付款: ¥${order['total_amount']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2C),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildActionButtons(order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
