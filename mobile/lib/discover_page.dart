import 'package:flutter/material.dart';
import 'icons.dart';
import 'api.dart';

/// 发现页面 - 包含关注、推荐、最新、讨论四个Tab
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // 商品数据
  List<dynamic> _products = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _categories = [];
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // 切换Tab时重新加载数据
      setState(() {
        _currentPage = 1;
        _products = [];
      });
      _loadProducts();
    }
  }

  /// 获取当前Tab的排序方式
  String _getCurrentOrdering() {
    switch (_tabController.index) {
      case 0: // 关注
        return '-publish_time'; // 暂时按时间排序
      case 1: // 推荐
        return '-publish_time'; // 按时间排序
      case 2: // 最新
        return '-publish_time'; // 按发布时间倒序
      case 3: // 讨论
        return '-publish_time'; // 暂时按时间排序
      default:
        return '-publish_time';
    }
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.getCategories();
    if (result['success']) {
      var rawData = result['data'];
      if (rawData is List) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(rawData);
        });
      }
    }
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    setState(() => _isLoading = true);

    final result = await ApiService.getProducts();

    if (result['success']) {
      // 确保items是列表类型
      var rawItems = result['data']['items'];
      List<dynamic> items = [];

      if (rawItems is List) {
        items = rawItems;
      } else {
        // 如果返回的不是列表，记录错误并显示空列表
        print('API返回的不是列表: $rawItems');
        items = [];
      }

      // 在客户端进行排序（最新优先）
      items.sort((a, b) {
        // 如果有publish_time字段则按时间排序，否则保持原顺序
        final timeA = a['publish_time'] ?? '';
        final timeB = b['publish_time'] ?? '';
        return timeB.toString().compareTo(timeA.toString());
      });

      // 在客户端进行过滤（分类筛选）
      final filteredItems = _selectedCategory == 'all'
          ? items
          : items.where((item) {
              return item['category']?.toString().toLowerCase() ==
                  _selectedCategory.toLowerCase();
            }).toList();

      setState(() {
        _products = filteredItems;
        _hasMore = false; // 后端不支持分页
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // 顶部Tab栏
              SliverToBoxAdapter(
                child: _buildTopTabBar(),
              ),
              // 搜索框和AI按钮
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),
              // 分类横向滚动列表
              SliverToBoxAdapter(
                child: _buildCategoryList(),
              ),
            ];
          },
          body: _buildProductGrid(),
        ),
      ),
    );
  }

  /// 顶部Tab栏 (关注/推荐/最新/讨论)
  Widget _buildTopTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFFCE965B),
              indicatorWeight: 3,
              labelColor: const Color(0xFF1A1A2C),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: '关注'),
                Tab(text: '推荐'),
                Tab(text: '最新'),
                Tab(text: '讨论'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索框和AI按钮
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            flex: 3,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  HeroIcons.magnifyingGlass(
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索感兴趣的商品...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // AI导购按钮
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCE965B).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeroIcons.bolt(
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 分类横向滚动列表
  Widget _buildCategoryList() {
    if (_categories.isEmpty) {
      return const SizedBox(height: 60);
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category['id'];
              });
              _loadProducts(refresh: true);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCE965B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFCE965B)
                      : Colors.grey.shade200,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFCE965B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 商品网格展示
  Widget _buildProductGrid() {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcons.shoppingBag(
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无商品',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProducts(refresh: true),
      color: const Color(0xFFCE965B),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  /// 商品卡片
  Widget _buildProductCard(dynamic product) {
    final productName = product['product_name'] ?? '未知商品';
    final price = product['price'] ?? 0.0;
    final imageUrl = product['image_url'] ?? '';
    final category = product['category'] ?? '其他';

    return GestureDetector(
      onTap: () {
        // TODO: 跳转到商品详情页
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
              child: ClipRRect(
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
                    // 价格和分类
                    Row(
                      children: [
                        Text(
                          '¥${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFCE965B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
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
