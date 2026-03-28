import 'package:flutter/material.dart';
import 'icons.dart';
import 'api.dart';
import 'auth_manager.dart';

/// 商品详情页面
class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? _product;
  List<dynamic> _tags = [];
  List<dynamic> _similarProducts = [];
  bool _isLoading = true;
  bool _isFavorited = false;
  bool _isFavoriteLoading = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    // 记录商品浏览
    ApiService.recordProductView(widget.productId);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await AuthManager.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId ?? '';
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 同时加载商品详情、标签和收藏状态
    final results = await Future.wait([
      ApiService.getProductDetail(widget.productId),
      ApiService.getProductTags(widget.productId),
      if (_currentUserId.isNotEmpty)
        ApiService.checkFavorite(_currentUserId, widget.productId)
      else
        Future.value({'success': false, 'isFavorited': false}),
      ApiService.getSimilarProducts(productId: widget.productId),
    ]);

    final productResult = results[0];
    final tagsResult = results[1];
    final favoriteResult = results[2];
    final similarResult = results[3];

    if (mounted) {
      setState(() {
        if (productResult['success']) {
          _product = productResult['data'];
        }
        if (tagsResult['success']) {
          _tags = tagsResult['data'] is List ? tagsResult['data'] : [];
        }
        if (favoriteResult['success']) {
          _isFavorited = favoriteResult['isFavorited'] ?? false;
        }
        if (similarResult['success']) {
          _similarProducts = similarResult['data'] is List ? similarResult['data'] : [];
        }
        _isLoading = false;
      });

      if (!productResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(productResult['message'])),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteLoading) return;

    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isFavoriteLoading = true);

    final result = _isFavorited
        ? await ApiService.removeFavorite(_currentUserId, widget.productId)
        : await ApiService.addFavorite(_currentUserId, widget.productId);

    if (mounted) {
      setState(() {
        _isFavoriteLoading = false;
        if (result['success']) {
          _isFavorited = !_isFavorited;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? const Color(0xFFCE965B) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
              ),
            )
          : _product == null
              ? _buildErrorView()
              : _buildContent(),
      bottomNavigationBar: _product != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE965B),
              foregroundColor: Colors.white,
            ),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // 顶部AppBar
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFFCE965B),
          flexibleSpace: FlexibleSpaceBar(
            background: _buildImageGallery(),
          ),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2C)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? Colors.red : const Color(0xFF1A1A2C),
                ),
                onPressed: _toggleFavorite,
              ),
            ),
          ],
        ),
        // 商品信息
        SliverToBoxAdapter(
          child: _buildProductInfo(),
        ),
        // 标签区域
        if (_tags.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildTagsSection(),
          ),
        // 商品描述
        SliverToBoxAdapter(
          child: _buildDescriptionSection(),
        ),
        // 相似商品区域
        if (_similarProducts.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSimilarProductsSection(),
          ),
        // 底部留白
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final imageUrl = _product?['image_url'] ?? '';
    return Container(
      color: Colors.grey.shade100,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: HeroIcons.photo(
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                );
              },
            )
          : Center(
              child: HeroIcons.shoppingBag(
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
    );
  }

  Widget _buildProductInfo() {
    final productName = _product?['product_name'] ?? '未知商品';
    final price = _product?['price'] ?? 0.0;
    final rating = _product?['avg_rating'] ?? 0.0;
    final salesCount = _product?['sales_count'] ?? 0;
    final viewCount = _product?['view_count'] ?? 0;
    final favoriteCount = _product?['favorite_count'] ?? 0;
    final stock = _product?['stock'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // 价格
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCE965B),
                ),
              ),
              const SizedBox(width: 12),
              if (stock > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '库存: $stock',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '暂时缺货',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 商品名称
          Text(
            productName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          const SizedBox(height: 16),
          // 统计信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('评分', rating > 0 ? rating.toStringAsFixed(1) : '暂无', Icons.star),
              _buildDivider(),
              _buildStatItem('销量', salesCount.toString(), Icons.shopping_cart),
              _buildDivider(),
              _buildStatItem('浏览', viewCount.toString(), Icons.visibility),
              _buildDivider(),
              _buildStatItem('收藏', favoriteCount.toString(), Icons.favorite),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildTagsSection() {
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
            '商品标签',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final tagName = tag['tag_name'] ?? '标签';
              final category = tag['category'] ?? '';
              return Chip(
                label: Text(tagName),
                backgroundColor: const Color(0xFFCE965B).withOpacity(0.1),
                labelStyle: const TextStyle(
                  color: Color(0xFFCE965B),
                  fontSize: 12,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = _product?['description'] ?? '暂无商品描述';

    return Container(
      margin: const EdgeInsets.all(16),
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
            '商品描述',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final stock = _product?['stock'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            // 收藏按钮
            GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _isFavorited
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _isFavoriteLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFCE965B)),
                          ),
                        )
                      : Icon(
                          _isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorited ? Colors.red : Colors.grey.shade600,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 加入购物车按钮
            Expanded(
              child: ElevatedButton(
                onPressed: stock > 0 ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE965B).withOpacity(0.1),
                  foregroundColor: const Color(0xFFCE965B),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '加入购物车',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 立即购买按钮
            Expanded(
              child: ElevatedButton(
                onPressed: stock > 0 ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE965B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '立即购买',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 相似商品区域
  Widget _buildSimilarProductsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            children: [
              const Text(
                '相似商品',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2C),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCE965B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '推荐',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFCE965B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _similarProducts.length,
              itemBuilder: (context, index) {
                final product = _similarProducts[index];
                return _buildSimilarProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 相似商品卡片
  Widget _buildSimilarProductCard(dynamic product) {
    final productName = product['product_name'] ?? '未知商品';
    final price = product['price'] ?? 0.0;
    final imageUrl = product['image_url'] ?? '';

    return GestureDetector(
      onTap: () {
        // 导航到商品详情页（替换当前页面以提供连续的相似商品浏览体验）
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              productId: product['product_id'],
            ),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 100,
                color: Colors.grey.shade100,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
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
            const SizedBox(height: 8),
            // 商品名称
            Text(
              productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2C),
              ),
            ),
            const SizedBox(height: 4),
            // 价格
            Text(
              '¥${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCE965B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
