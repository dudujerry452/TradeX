import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'login_screen.dart';

/// 我的页面 - 展示用户账户信息
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 用户信息（实际项目中应该从登录状态或本地存储获取）
  Map<String, dynamic> _userInfo = {
    'username': 'tradeX用户',
    'email': 'user@tradex.com',
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

  // 功能菜单列表
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': CupertinoIcons.heart, 'title': '我的收藏', 'color': Colors.red},
    {'icon': CupertinoIcons.clock, 'title': '浏览历史', 'color': Colors.blue},
    {'icon': CupertinoIcons.location, 'title': '收货地址', 'color': Colors.green},
    {'icon': CupertinoIcons.bell, 'title': '消息通知', 'color': Colors.orange},
    {'icon': CupertinoIcons.gift, 'title': '优惠券', 'color': Colors.purple},
    {'icon': CupertinoIcons.money_yen_circle, 'title': '我的钱包', 'color': Colors.amber},
    {'icon': CupertinoIcons.settings, 'title': '设置', 'color': Colors.grey},
    {'icon': CupertinoIcons.question_circle, 'title': '帮助与反馈', 'color': Colors.teal},
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
                    : Icon(
                        CupertinoIcons.person_fill,
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
                          Icon(
                            CupertinoIcons.star_fill,
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
                  child: const Icon(
                    CupertinoIcons.pencil,
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
                onTap: () {
                  // TODO: 查看全部订单
                },
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
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
                _getOrderIcon(entry.key),
                entry.key,
                entry.value > 0 ? entry.value.toString() : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getOrderIcon(String status) {
    switch (status) {
      case '待付款':
        return CupertinoIcons.creditcard;
      case '待发货':
        return CupertinoIcons.cube_box;
      case '待收货':
        return CupertinoIcons.cube;
      case '待评价':
        return CupertinoIcons.chat_bubble_text;
      default:
        return CupertinoIcons.bag;
    }
  }

  Widget _buildOrderStatusItem(IconData icon, String label, String? badge) {
    return GestureDetector(
      onTap: () {
        // TODO: 跳转到对应订单列表
      },
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
                child: Icon(
                  icon,
                  color: const Color(0xFFCE965B),
                  size: 24,
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
                item['icon'] as IconData,
                item['title'] as String,
                item['color'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color) {
    return GestureDetector(
      onTap: () {
        // TODO: 跳转到对应功能页面
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title 功能开发中')),
        );
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
            child: Icon(
              icon,
              color: color,
              size: 24,
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
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              // 跳转到登录页面
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            isDestructiveAction: true,
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
