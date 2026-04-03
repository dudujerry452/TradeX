import 'package:flutter/material.dart';
import 'icons.dart';
import 'api.dart';
import 'product_detail_page.dart';
import 'auth_manager.dart';
import 'ai_chat_bottom_sheet.dart';

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
  final ScrollController _scrollController = ScrollController();

  // 商品数据
  List<dynamic> _products = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _categories = [];

  // 搜索相关状态
  bool _isSearching = false;     // 是否正在搜索模式
  String _searchQuery = '';      // 当前搜索关键词

  // 分页相关状态
  int _currentOffset = 0;        // 当前偏移量
  final int _pageSize = 10;      // 每页数量
  bool _isLoadingMore = false;   // 是否正在加载更多
  bool _hasMoreData = true;      // 是否还有更多数据

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // 切换Tab时重置分页状态
      setState(() {
        _currentOffset = 0;
        _hasMoreData = true;
        _products = [];
      });
      _loadProducts();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // 当滚动到底部附近时加载更多
    if (currentScroll >= maxScroll - 100) {
      if (_isSearching) {
        // 搜索模式下加载更多搜索结果
        if (!_isLoadingMore && _hasMoreData && !_isLoading) {
          _loadMoreSearchResults();
        }
      } else {
        // 根据当前Tab和分类状态决定加载更多
        if (!_isLoadingMore && _hasMoreData && !_isLoading) {
          if (_tabController.index == 1) {
            // 推荐Tab：如果选了特定分类，用搜索API；否则用推荐API
            if (_selectedCategory != 'all') {
              _loadMoreLatest();
            } else {
              _loadMoreRecommendations();
            }
          } else if (_tabController.index == 2) {
            // 最新Tab：使用搜索API加载更多
            _loadMoreLatest();
          }
        }
      }
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

    // 如果是刷新，重置分页状态
    if (refresh) {
      setState(() {
        _currentOffset = 0;
        _hasMoreData = true;
      });
    }

    setState(() => _isLoading = true);

    // 根据当前Tab决定加载策略
    switch (_tabController.index) {
      case 0: // 关注 - 占位符空页
      case 3: // 讨论 - 占位符空页
        setState(() {
          _products = [];
          _hasMoreData = false;
          _isLoading = false;
        });
        return;
      case 1: // 推荐
        // 如果选择了特定分类，使用搜索API获取该分类商品
        if (_selectedCategory != 'all') {
          await _loadLatestProducts();
        } else {
          await _loadRecommendations();
        }
        return;
      case 2: // 最新 - 使用搜索API（支持分类筛选和后端分页）
        await _loadLatestProducts();
        return;
    }
  }

  /// 加载最新商品（使用搜索API支持分类筛选）
  Future<void> _loadLatestProducts() async {
    // 计算当前页
    final offset = _currentOffset;

    final result = await ApiService.searchProducts(
      query: '', // 空查询返回所有商品
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      limit: _pageSize,
      offset: offset,
    );

    if (result['success']) {
      List<dynamic> items = [];
      var rawData = result['data'];
      if (rawData is List) {
        items = rawData;
      }

      // 按发布时间排序（最新优先）
      items.sort((a, b) {
        final timeA = a['publish_time'] ?? '';
        final timeB = b['publish_time'] ?? '';
        return timeB.toString().compareTo(timeA.toString());
      });

      setState(() {
        if (offset == 0) {
          // 首次加载或刷新
          _products = items;
        } else {
          // 加载更多：追加数据
          _products.addAll(items);
        }
        // 判断是否还有更多数据
        _hasMoreData = items.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
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

  /// 加载推荐（支持分页）
  Future<void> _loadRecommendations() async {
    final userId = await AuthManager.getUserId();

    Map<String, dynamic> result;
    if (userId != null) {
      // 已登录：获取个性化推荐
      result = await ApiService.getPersonalizedRecommendations(
        userId: userId,
        limit: _pageSize,
        offset: _currentOffset,
      );
    } else {
      // 未登录：获取热门推荐
      result = await ApiService.getTrendingRecommendations(
        limit: _pageSize,
        offset: _currentOffset,
      );
    }

    if (result['success']) {
      List<dynamic> items = [];
      var rawData = result['data'];
      if (rawData is List) {
        items = rawData;
      }

      // 推荐结果也支持分类过滤（如果是全部则不过滤）
      final filteredItems = _selectedCategory == 'all'
          ? items
          : items.where((item) {
              return item['category']?.toString().toLowerCase() ==
                  _selectedCategory.toLowerCase();
            }).toList();

      setState(() {
        if (_currentOffset == 0) {
          // 首次加载或刷新
          _products = filteredItems;
        } else {
          // 加载更多：追加数据
          _products.addAll(filteredItems);
        }
        // 判断是否还有更多数据
        _hasMoreData = items.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  /// 加载更多推荐
  Future<void> _loadMoreRecommendations() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentOffset += _pageSize;

    await _loadRecommendations();
  }

  /// 加载更多最新商品（使用搜索API）
  Future<void> _loadMoreLatest() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentOffset += _pageSize;

    await _loadLatestProducts();
  }

  /// 执行搜索
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchQuery = query;
      _isLoading = true;
      _products = [];
    });

    final token = await AuthManager.getToken();

    final result = await ApiService.searchProducts(
      query: query,
      limit: _pageSize,
      offset: 0,
      token: token,
    );

    if (result['success']) {
      List<dynamic> items = [];
      var rawData = result['data'];
      if (rawData is List) {
        items = rawData;
      }

      setState(() {
        _products = items;
        _hasMoreData = items.length >= _pageSize;
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

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _currentOffset = 0;
      _hasMoreData = true;
    });
    _loadProducts(refresh: true);
  }

  /// 加载更多搜索结果（分页）
  Future<void> _loadMoreSearchResults() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentOffset += _pageSize;

    final token = await AuthManager.getToken();

    final result = await ApiService.searchProducts(
      query: _searchQuery,
      limit: _pageSize,
      offset: _currentOffset,
      token: token,
    );

    if (result['success']) {
      List<dynamic> items = [];
      var rawData = result['data'];
      if (rawData is List) {
        items = rawData;
      }

      setState(() {
        _products.addAll(items);
        _hasMoreData = items.length >= _pageSize;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  /// 显示 AI 聊天弹窗
  void _showAiChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiChatBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadProducts(refresh: true),
          color: const Color(0xFFCE965B),
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
      ),
    );
  }

  /// 顶部Tab栏 (关注/推荐/最新/讨论) + 刷新按钮
  Widget _buildTopTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
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
          // 刷新按钮
          IconButton(
            onPressed: _isLoading ? null : () => _loadProducts(refresh: true),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFFCE965B)),
            tooltip: '刷新',
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
                      onSubmitted: (_) => _performSearch(),
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
                  // 搜索按钮
                  GestureDetector(
                    onTap: _performSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '搜索',
                        style: TextStyle(
                          color: const Color(0xFFCE965B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // AI导购按钮
          GestureDetector(
            onTap: () => _showAiChat(context),
            child: Container(
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
    // 关注和讨论Tab显示占位符（非搜索模式）
    if ((_tabController.index == 0 || _tabController.index == 3) && !_isSearching) {
      return _buildPlaceholderPage();
    }

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
              _isSearching ? '未找到相关商品' : '暂无商品',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearSearch,
                child: const Text(
                  '清除搜索',
                  style: TextStyle(color: Color(0xFFCE965B)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // 搜索状态提示
        if (_isSearching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$_searchQuery" 的搜索结果',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _clearSearch,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '清除',
                    style: TextStyle(
                      color: Color(0xFFCE965B),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // 商品网格
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _products.length + (_isLoadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              // 显示加载指示器
              if (index >= _products.length) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                    ),
                  ),
                );
              }
              final product = _products[index];
              return _buildProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  /// 占位符空页（关注和讨论）
  Widget _buildPlaceholderPage() {
    final isFollowing = _tabController.index == 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFollowing ? Icons.people_outline : Icons.forum_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            isFollowing ? '关注功能开发中' : '讨论功能开发中',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '敬请期待...',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 商品卡片
  Widget _buildProductCard(dynamic product) {
    // DEBUG: 打印原始数据
    print('DEBUG product: ${product['product_name']} keys=${product.keys.toList()}');

    final productName = product['product_name'] ?? '未知商品';
    final price = product['price'] ?? 0.0;
    final imageUrl = product['image_url'] ?? '';
    final category = product['category'] ?? '其他';
    final isFavorited = product['is_favorited'] ?? false;
    final relevanceScore = product['relevance_score'];
    final trendingScore = product['trending_score'];
    print('DEBUG trendingScore=$trendingScore');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: product['product_id']),
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
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
                    // 已收藏标记
                    if (isFavorited)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
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
                        // DEBUG: 用户关联度评分
                        if (relevanceScore != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '[R:${relevanceScore.toStringAsFixed(2)}]',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        // DEBUG: 热度评分
                        if (trendingScore != null)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '[H:${trendingScore.toStringAsFixed(0)}]',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        // DEBUG: 打印到控制台
                        if (trendingScore == null)
                          Text('NO-H', style: TextStyle(fontSize: 8, color: Colors.grey)),
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
