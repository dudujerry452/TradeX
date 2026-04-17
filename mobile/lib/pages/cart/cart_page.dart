import 'package:flutter/material.dart';

import '../../auth_manager.dart';
import '../../icons.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';

/// 购物车页面
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItem> _items = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final userId = await AuthManager.getUserId();
    if (!mounted) {
      return;
    }

    if (userId == null || userId.isEmpty) {
      setState(() {
        _currentUserId = '';
        _items = [];
        _isLoading = false;
      });
      return;
    }

    final items = await CartService.getItems();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentUserId = userId;
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    try {
      await CartService.updateQuantity(item.productId, quantity);
      await _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatError(e))));
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      await CartService.removeItem(item.productId);
      await _loadCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已从购物车移除'),
            backgroundColor: Color(0xFFCE965B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatError(e))));
      }
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空购物车'),
        content: const Text('确定要清空购物车吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await CartService.clearCart();
      await _loadCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('购物车已清空'),
            backgroundColor: Color(0xFFCE965B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatError(e))));
      }
    }
  }

  String _formatError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.replaceFirst('Exception: ', '')
        : text;
  }

  double _getTotalAmount() {
    return _items.fold<double>(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );
  }

  int _getTotalCount() {
    return _items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCE965B),
        elevation: 0,
        title: const Text(
          '购物车',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentUserId.isNotEmpty && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _clearCart,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCart,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
              ),
            )
          : _currentUserId.isEmpty
          ? _buildLoginHint()
          : _items.isEmpty
          ? _buildEmptyView()
          : RefreshIndicator(
              onRefresh: _loadCart,
              color: const Color(0xFFCE965B),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildCartItem(_items[index]);
                },
              ),
            ),
      bottomNavigationBar: _currentUserId.isNotEmpty && _items.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildLoginHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcons.shoppingCart(size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '请先登录后查看购物车',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '购物车内容会跟随账号保存',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcons.shoppingCart(size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '购物车还是空的',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '去商品详情页点击加入购物车吧',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final canIncrease = item.stock > 0 && item.quantity < item.stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 84,
              height: 84,
              color: Colors.grey.shade100,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: HeroIcons.photo(
                            size: 30,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: HeroIcons.shoppingBag(
                        size: 30,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.sellerName.isNotEmpty
                      ? '卖家：${item.sellerName}'
                      : '卖家：未知',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '¥${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCE965B),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.stock > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.stock > 0 ? '库存 ${item.stock}' : '库存不足',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.stock > 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.remove, size: 18),
                        color: Colors.grey.shade700,
                        onPressed: item.quantity > 1
                            ? () => _updateQuantity(item, item.quantity - 1)
                            : null,
                      ),
                    ),
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      child: Text(
                        item.quantity.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2C),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add, size: 18),
                        color: Colors.grey.shade700,
                        onPressed: canIncrease
                            ? () => _updateQuantity(item, item.quantity + 1)
                            : null,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _removeItem(item),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('移除'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalCount = _getTotalCount();
    final totalAmount = _getTotalAmount();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '共 $totalCount 件商品',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '合计 ¥${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCE965B),
                  ),
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _clearCart,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('清空购物车'),
            ),
          ],
        ),
      ),
    );
  }
}
