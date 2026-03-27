import 'package:flutter/material.dart';
import 'icons.dart';
import 'api.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 0 表示 "用户名登录", 1 表示 "邮箱登录"
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 颜色配置
  final Color primaryColor = const Color(0xFFCE965B); // tradeX 橙色
  final Color primaryDark = const Color(0xFF07071F);  // 按钮深蓝色
  final Color bgColor = const Color(0xFFF5F6FA);      // 页面背景浅灰
  final Color cardColor = Colors.white;
  final Color inputBgColor = const Color(0xFFF0F1F5);

  void _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的登录信息')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      identifier: identifier,
      password: password,
      isEmail: _selectedTabIndex == 1,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // 登录成功
      final userData = result['data'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('欢迎回来, ${userData['username']}!')),
      );
      // 跳转到主页
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      // 登录失败，显示后端返回的错误信息 (401, 403等)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// 调试登录 - 使用管理员账号快速登录
  void _debugLogin() async {
    setState(() => _isLoading = true);

    final result = await ApiService.login(
      identifier: 'admin_root',
      password: 'hashed_admin_pw',
      isEmail: false,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      final userData = result['data'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('调试登录成功: ${userData['username']}')),
      );
      // 跳转到主页
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('调试登录失败: ${result['message']}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBar(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: _buildLoginCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 顶部导航栏 (模拟图中样式)
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 80), // 占位保持标题居中
          const Text(
            '登录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.more_horiz, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Container(width: 1, height: 12, color: Colors.grey.shade300),
                const SizedBox(width: 8),
                HeroIcons.globeAlt(size: 18, color: Colors.grey.shade600),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 核心登录卡片
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFD67F1F), // 接近图中的橙色
                borderRadius: BorderRadius.circular(20),
              ),
              child: HeroIcons.shoppingBag(size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),

          // 欢迎语
          Center(
            child: Column(
              children: [
                const Text(
                  'Welcome to',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2C)),
                ),
                Text(
                  'tradeX',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in to continue shopping',
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 切换 Tab (用户名/邮箱)
          _buildTabToggle(),
          const SizedBox(height: 20),

          // 表单区域
          Text(
            _selectedTabIndex == 0 ? 'Username' : 'Email',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2C)),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _identifierController,
            hintText: _selectedTabIndex == 0 ? 'Enter username' : 'Enter email',
            icon: HeroIcons.envelope(size: 20, color: Colors.blueGrey.shade300),
          ),
          const SizedBox(height: 20),

          const Text(
            'Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2C)),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hintText: 'Enter your password',
            icon: HeroIcons.lockClosed(size: 20, color: Colors.blueGrey.shade300),
            isPassword: true,
          ),
          const SizedBox(height: 30),

          // 登录按钮
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // 调试登录按钮
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _debugLogin,
              icon: HeroIcons.bugAnt(size: 18, color: Colors.white),
              label: const Text(
                '调试登录 (admin)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // 注册引导
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? ", style: TextStyle(color: Colors.blueGrey.shade600)),
                GestureDetector(
                  onTap: () {
                    // TODO: 跳转注册页面
                  },
                  child: const Text(
                    'Sign up for free',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 渲染自定义 Tab 切换器
  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton(0, '用户名登录')),
          Expanded(child: _buildTabButton(1, '邮箱登录')),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          _identifierController.clear(); // 切换时清空输入框
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF1A1A2C) : Colors.blueGrey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  // 渲染通用输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Widget icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: icon,
        ),
        filled: true,
        fillColor: inputBgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
