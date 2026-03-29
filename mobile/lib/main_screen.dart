import 'package:flutter/material.dart';
import 'icons.dart';
import 'discover_page.dart';
import 'create_product_page.dart';
import 'message_page.dart';
import 'profile_page.dart';

/// 主屏幕 - 包含底部导航栏
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DiscoverPage(),
    const CreateProductPage(),
    const MessagePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(_getIconWidget(0), '发现', 0),
                _buildNavItem(_getIconWidget(1), '发布', 1),
                _buildNavItem(_getIconWidget(2), '消息', 2),
                _buildNavItem(_getIconWidget(3), '我的', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getIconWidget(int index) {
    switch (index) {
      case 0:
        return HeroIcons.globeAlt();
      case 1:
        return HeroIcons.photo();
      case 2:
        return HeroIcons.chatBubble();
      case 3:
        return HeroIcons.user();
      default:
        return HeroIcons.globeAlt();
    }
  }

  Widget _buildNavItem(Widget iconWidget, String label, int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCE965B).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcons.icon(
              _getIconName(index),
              size: 24,
              color: isSelected ? const Color(0xFFCE965B) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFCE965B) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIconName(int index) {
    switch (index) {
      case 0:
        return 'globe-alt';
      case 1:
        return 'photo';
      case 2:
        return 'chat-bubble-left-ellipsis';
      case 3:
        return 'user';
      default:
        return 'globe-alt';
    }
  }
}
