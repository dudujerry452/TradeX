import 'package:flutter/material.dart';
import 'icons.dart';
import 'api.dart';
import 'product_detail_page.dart';
import 'auth_manager.dart';

/// 收藏列表页面
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await AuthManager.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId ?? '';
      });
      if (userId != null && userId.isNotEmpty) {
        _loadFavorites();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
    }
  }

  Future<void> _loadFavorites() async {
    if (_currentUserId.isEmpty) return;

    setState(() => _isLoading = true);

    final result = await ApiService.getUserFavorites(_currentUserId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _favorites = result['data'] is List ? result['data'] : [];
        }
      });

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  Future<void> _removeFavorite(String productId) async {
    final result = await ApiService.removeFavorite(_currentUserId, productId);

    if (mounted) {
      if (result['success']) {
        setState(() {
          _favorites.removeWhere((f) => f['product_id'] == productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消收藏'),
            backgroundColor: Color(0xFFCE965B),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCE965B),
        elevation: 0,
        title: const Text(
          '我的收藏',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
              ),
            )
          : _favorites.isEmpty
              ? _buildEmptyView()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcons.heart(
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无收藏商品',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去发现喜欢的商品吧',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: const Color(0xFFCE965B),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          return _buildFavoriteCard(favorite);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(dynamic favorite) {
    final productName = favorite['product_name'] ?? '未知商品';
    final price = favorite['price'] ?? 0.0;
    final imageUrl = favorite['image_url'] ?? '';
    final productId = favorite['product_id'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: productId),
          ),
        );
      },
      child: Container(
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
            // 商品图片
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: HeroIcons.photo(
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: HeroIcons.shoppingBag(
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  // 取消收藏按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(productId),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 商品信息
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品名称
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2C),
                      ),
                    ),
                    const Spacer(),
                    // 价格
                    Text(
                      '¥${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCE965B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
