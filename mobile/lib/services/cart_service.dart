import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth_manager.dart';
import '../models/cart_item.dart';

/// 购物车本地存储服务
class CartService {
  static const String _storagePrefix = 'shopping_cart_items_';

  static String _storageKey(String userId) => '$_storagePrefix$userId';

  static Future<String?> _currentUserId() async {
    final userId = await AuthManager.getUserId();
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return userId;
  }

  static Future<List<CartItem>> _loadItemsForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_storageKey(userId)) ?? [];

    final items = <CartItem>[];
    for (final rawItem in rawItems) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map<String, dynamic>) {
          items.add(CartItem.fromJson(decoded));
        } else if (decoded is Map) {
          items.add(CartItem.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        continue;
      }
    }

    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  static Future<void> _saveItemsForUser(
    String userId,
    List<CartItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedItems = List<CartItem>.from(items)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    await prefs.setStringList(
      _storageKey(userId),
      normalizedItems.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<List<CartItem>> getItems() async {
    final userId = await _currentUserId();
    if (userId == null) {
      return [];
    }
    return _loadItemsForUser(userId);
  }

  static Future<int> getTotalCount() async {
    final items = await getItems();
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  static Future<double> getTotalAmount() async {
    final items = await getItems();
    return items.fold<double>(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );
  }

  static Future<void> addProduct(
    Map<String, dynamic> product, {
    int quantity = 1,
  }) async {
    await addItem(CartItem.fromProduct(product, quantity: quantity));
  }

  static Future<void> addItem(CartItem item) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('请先登录');
    }

    if (item.productId.isEmpty) {
      throw Exception('商品信息不完整');
    }

    if (item.quantity < 1) {
      throw Exception('加入数量必须大于 0');
    }

    if (item.stock <= 0) {
      throw Exception('商品库存不足');
    }

    final items = await _loadItemsForUser(userId);
    final index = items.indexWhere(
      (existing) => existing.productId == item.productId,
    );

    if (index >= 0) {
      final existing = items[index];
      final mergedQuantity = existing.quantity + item.quantity;
      final nextQuantity = item.stock > 0 && mergedQuantity > item.stock
          ? item.stock
          : mergedQuantity;

      items[index] = existing.copyWith(
        productName: item.productName.isNotEmpty
            ? item.productName
            : existing.productName,
        price: item.price > 0 ? item.price : existing.price,
        imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : existing.imageUrl,
        sellerId: item.sellerId.isNotEmpty ? item.sellerId : existing.sellerId,
        sellerName: item.sellerName.isNotEmpty
            ? item.sellerName
            : existing.sellerName,
        quantity: nextQuantity,
        stock: item.stock > 0 ? item.stock : existing.stock,
        addedAt: DateTime.now(),
      );
    } else {
      items.add(
        item.copyWith(
          quantity: item.stock > 0 && item.quantity > item.stock
              ? item.stock
              : item.quantity,
          addedAt: DateTime.now(),
        ),
      );
    }

    await _saveItemsForUser(userId, items);
  }

  static Future<void> updateQuantity(String productId, int quantity) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('请先登录');
    }

    final items = await _loadItemsForUser(userId);
    final index = items.indexWhere((item) => item.productId == productId);
    if (index < 0) {
      return;
    }

    if (quantity < 1) {
      items.removeAt(index);
    } else {
      final currentItem = items[index];
      final nextQuantity = currentItem.stock > 0 && quantity > currentItem.stock
          ? currentItem.stock
          : quantity;
      items[index] = currentItem.copyWith(quantity: nextQuantity);
    }

    await _saveItemsForUser(userId, items);
  }

  static Future<void> removeItem(String productId) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('请先登录');
    }

    final items = await _loadItemsForUser(userId);
    items.removeWhere((item) => item.productId == productId);
    await _saveItemsForUser(userId, items);
  }

  static Future<void> clearCart() async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw Exception('请先登录');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(userId));
  }
}
