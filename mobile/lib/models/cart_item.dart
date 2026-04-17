/// 购物车商品模型
class CartItem {
  final String productId;
  final String productName;
  final double price;
  final String imageUrl;
  final String sellerId;
  final String sellerName;
  final int quantity;
  final int stock;
  final DateTime addedAt;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.sellerName,
    required this.quantity,
    required this.stock,
    required this.addedAt,
  });

  factory CartItem.fromProduct(
    Map<String, dynamic> product, {
    int quantity = 1,
  }) {
    return CartItem(
      productId: _asString(product['product_id']),
      productName: _asString(product['product_name'], fallback: '未知商品'),
      price: _asDouble(product['price']),
      imageUrl: _asString(product['image_url']),
      sellerId: _asString(product['publisher_id']),
      sellerName: _asString(product['publisher_name']),
      quantity: quantity < 1 ? 1 : quantity,
      stock: _asInt(product['stock']),
      addedAt: DateTime.now(),
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: _asString(json['product_id'] ?? json['productId']),
      productName: _asString(
        json['product_name'] ?? json['productName'],
        fallback: '未知商品',
      ),
      price: _asDouble(json['price']),
      imageUrl: _asString(json['image_url'] ?? json['imageUrl']),
      sellerId: _asString(json['seller_id'] ?? json['sellerId']),
      sellerName: _asString(json['seller_name'] ?? json['sellerName']),
      quantity: _asInt(json['quantity'], fallback: 1),
      stock: _asInt(json['stock']),
      addedAt: _asDateTime(json['added_at'] ?? json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'image_url': imageUrl,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'quantity': quantity,
      'stock': stock,
      'added_at': addedAt.toIso8601String(),
    };
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    double? price,
    String? imageUrl,
    String? sellerId,
    String? sellerName,
    int? quantity,
    int? stock,
    DateTime? addedAt,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_asString(value)) ?? 0.0;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_asString(value)) ?? fallback;
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
