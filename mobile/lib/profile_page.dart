import 'package:flutter/material.dart';
import 'icons.dart';
import 'login_screen.dart';
import 'api.dart';
import 'favorites_page.dart';
import 'auth_manager.dart';
import 'pages/order/order_list_page.dart';

/// 我的页面 - 展示用户账户信息
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 用户信息（从本地存储加载）
  Map<String, dynamic> _userInfo = {
    'user_id': '',
    'username': '未登录',
    'email': '',
    'avatar': '',
    'role': 'user',
  };

  // 订单统计数据
  final Map<String, int> _orderStats = {
    '待付款': 2,
    '待发货': 1,
    '待收货': 3,
    '待评价': 0,
  };

  // 用户标签偏好数据
  List<dynamic> _tagPreferences = [];
  bool _isDebugExpanded = false;
  bool _isLoadingDebug = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    final user = await AuthManager.getUser();
    if (user != null && mounted) {
      setState(() {
        _userInfo = user;
      });
      _loadTagPreferences();
    }
  }

  Future<void> _loadTagPreferences() async {
    setState(() => _isLoadingDebug = true);

    final userId = _userInfo['user_id'];
    if (userId == null || userId.isEmpty) {
      setState(() => _isLoadingDebug = false);
      return;
    }

    final result = await ApiService.getUserTagPreferences(userId);

    if (mounted) {
      setState(() {
        _isLoadingDebug = false;
        if (result['success']) {
          _tagPreferences = result['data'] is List ? result['data'] : [];
        }
      });
    }
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FavoritesPage(),
      ),
    );
  }

  void _navigateToOrderList({int initialTab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderListPage(
          role: 'buyer',
        ),
      ),
    );
  }

  // 功能菜单列表
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': 'heart', 'title': '我的收藏', 'color': Colors.red},
    {'icon': 'clock', 'title': '浏览历史', 'color': Colors.blue},
    {'icon': 'map-pin', 'title': '收货地址', 'color': Colors.green},
    {'icon': 'bell', 'title': '消息通知', 'color': Colors.orange},
    {'icon': 'gift', 'title': '优惠券', 'color': Colors.purple},
    {'icon': 'currency-dollar', 'title': '我的钱包', 'color': Colors.amber},
    {'icon': 'cog', 'title': '设置', 'color': Colors.grey},
    {'icon': 'question', 'title': '帮助与反馈', 'color': Colors.teal},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部用户信息卡片
            SliverToBoxAdapter(
              child: _buildUserCard(),
            ),
            // 订单统计区域
            SliverToBoxAdapter(
              child: _buildOrderStats(),
            ),
            // Debug 区域
            SliverToBoxAdapter(
              child: _buildDebugPanel(),
            ),
            // 功能菜单列表
            SliverToBoxAdapter(
              child: _buildMenuGrid(),
            ),
            // 退出登录按钮
            SliverToBoxAdapter(
              child: _buildLogoutButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// 用户信息卡片
  Widget _buildUserCard() {
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
      child: Column(
        children: [
          Row(
            children: [
              // 头像
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _userInfo['avatar']?.isNotEmpty ?? false
                    ? ClipOval(
                        child: Image.network(
                          _userInfo['avatar'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : HeroIcons.user(
                        size: 35,
                        color: const Color(0xFFCE965B),
                      ),
              ),
              const SizedBox(width: 16),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userInfo['username'] ?? '用户',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userInfo['email'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 会员标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HeroIcons.star(
                            size: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '普通会员',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 编辑按钮
              GestureDetector(
                onTap: () {
                  // TODO: 编辑个人资料
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HeroIcons.pencil(
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 统计信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('关注', '12'),
              _buildDivider(),
              _buildStatItem('粉丝', '5'),
              _buildDivider(),
              _buildStatItem('获赞', '28'),
              _buildDivider(),
              _buildStatItem('收藏', '36'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
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

  /// 订单统计区域
  Widget _buildOrderStats() {
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
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的订单',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2C),
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToOrderList(),
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
          const SizedBox(height: 16),
          // 订单状态图标
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _orderStats.entries.map((entry) {
              return _buildOrderStatusItem(
                _getOrderIconName(entry.key),
                entry.key,
                entry.value > 0 ? entry.value.toString() : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getOrderIconName(String status) {
    switch (status) {
      case '待付款':
        return 'credit-card';
      case '待发货':
        return 'cube';
      case '待收货':
        return 'shopping-bag';
      case '待评价':
        return 'chat-bubble-left-ellipsis';
      default:
        return 'shopping-bag';
    }
  }

  Widget _buildOrderStatusItem(String iconName, String label, String? badge, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToOrderList(),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HeroIcons.icon(
                    iconName,
                    size: 24,
                    color: const Color(0xFFCE965B),
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Debug 面板 - 展示用户标签偏好数据
  Widget _buildDebugPanel() {
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
          // 标题栏（可点击展开/收起）
          GestureDetector(
            onTap: () {
              setState(() {
                _isDebugExpanded = !_isDebugExpanded;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Debug: 用户标签偏好',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2C),
                    ),
                  ),
                ),
                Icon(
                  _isDebugExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                // 刷新按钮
                GestureDetector(
                  onTap: _loadTagPreferences,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoadingDebug
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.purple),
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.purple,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // 展开的详细内容
          if (_isDebugExpanded) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            if (_tagPreferences.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无标签偏好数据',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _tagPreferences.map((tag) {
                  final tagName = tag['tag_name'] ?? '未知标签';
                  final score = (tag['score'] ?? 0.0).toDouble();
                  final category = tag['category'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tagName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A2C),
                                    ),
                                  ),
                                  if (category.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              // 分数进度条
                              LinearProgressIndicator(
                                value: score / 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.purple),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            score.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  /// 功能菜单网格
  Widget _buildMenuGrid() {
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
            '更多服务',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              return _buildMenuItem(
                item['icon'] as String,
                item['title'] as String,
                item['color'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String iconName, String title, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == '我的收藏') {
          _navigateToFavorites();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 功能开发中')),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: HeroIcons.icon(
                iconName,
                size: 24,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 退出登录按钮
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
          _showLogoutDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '退出登录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 清除登录态
              await AuthManager.clearLogin();
              // 跳转到登录页面
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
