import 'dart:async';
import 'package:flutter/material.dart';
import '../../icons.dart';
import '../../services/seller_service.dart';
import 'product_edit_page.dart';

class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['全部', '在售', '已下架', '待审核', '未通过'];
  final List<String?> _statusFilters = [null, 'APPROVED', 'OFF_SHELF', 'PENDING', 'REJECTED'];

  final Map<int, List<dynamic>> _productsMap = {};
  final Map<int, bool> _loadingMap = {};
  final Map<int, bool> _hasMoreMap = {};
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProducts(0, refresh: true);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final index = _tabController.index;
      if (_productsMap[index] == null || _productsMap[index]!.isEmpty) {
        _loadProducts(index, refresh: true);
      }
    }
  }

  Future<void> _loadProducts(int tabIndex, {bool refresh = false}) async {
    if (_loadingMap[tabIndex] == true && !refresh) return;

    setState(() {
      _loadingMap[tabIndex] = true;
    });

    try {
      final result = await SellerService.getMyProducts(
        status: _statusFilters[tabIndex],
        limit: _limit,
        offset: refresh ? 0 : (_productsMap[tabIndex]?.length ?? 0),
      );

      if (result['success']) {
        final products = result['products'] ?? [];
        final total = result['total'] ?? 0;

        setState(() {
          if (refresh || _productsMap[tabIndex] == null) {
            _productsMap[tabIndex] = products;
          } else {
            _productsMap[tabIndex]!.addAll(products);
          }
          _hasMoreMap[tabIndex] = (_productsMap[tabIndex]?.length ?? 0) < total;
          _loadingMap[tabIndex] = false;
        });
      } else {
        setState(() {
          _loadingMap[tabIndex] = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '加载失败')),
          );
        }
      }
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

  String _getStatusText(String status) {
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

  Future<void> _toggleProductStatus(String productId, String currentStatus) async {
    final newStatus = currentStatus == 'APPROVED' ? 'OFF_SHELF' : 'APPROVED';
    final actionText = newStatus == 'APPROVED' ? '上架' : '下架';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认$actionText'),
        content: Text('确定要$actionText该商品吗？'),
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
            child: Text('确定$actionText'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await SellerService.updateProductStatus(productId, newStatus);
        if (result['success']) {
          _refreshCurrentTab();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$actionText成功')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? '$actionText失败')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$actionText失败: $e')),
          );
        }
      }
    }
  }

  void _editProduct(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEditPage(product: product),
      ),
    ).then((_) => _refreshCurrentTab());
  }

  void _refreshCurrentTab() {
    _loadProducts(_tabController.index, refresh: true);
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
        title: const Text(
          '我的商品',
          style: TextStyle(
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
            onRefresh: () => _loadProducts(index, refresh: true),
            color: const Color(0xFFCE965B),
            child: _buildProductList(index),
          );
        }),
      ),
    );
  }

  Widget _buildProductList(int tabIndex) {
    final products = _productsMap[tabIndex] ?? [];
    final isLoading = _loadingMap[tabIndex] ?? false;

    if (isLoading && products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcons.icon(
              'cube',
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无商品',
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
      itemCount: products.length + ((_hasMoreMap[tabIndex] ?? false) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == products.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _loadProducts(tabIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE965B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('加载更多'),
              ),
            ),
          );
        }

        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(dynamic product) {
    final status = product['product_status'] ?? 'PENDING';

    return Container(
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
          // 商品头部：图片 + 信息 + 状态
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product['image_url'] ?? '',
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
                      product['product_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${product['price']} · 库存 ${product['stock']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildActionButtons(product),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(dynamic product) {
    final status = product['product_status'];
    final productId = product['product_id'];
    final buttons = <Widget>[];

    // 编辑按钮 - 所有状态都显示
    buttons.add(
      OutlinedButton(
        onPressed: () => _editProduct(product),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFCE965B),
          side: const BorderSide(color: Color(0xFFCE965B)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text('编辑'),
      ),
    );

    // 上架/下架按钮
    if (status == 'APPROVED') {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        OutlinedButton(
          onPressed: () => _toggleProductStatus(productId, status),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('下架'),
        ),
      );
    } else if (status == 'OFF_SHELF') {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        ElevatedButton(
          onPressed: () => _toggleProductStatus(productId, status),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCE965B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('上架'),
        ),
      );
    }

    return buttons;
  }
}
