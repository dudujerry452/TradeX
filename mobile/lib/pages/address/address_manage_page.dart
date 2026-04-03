import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../auth_manager.dart';

/// 地址管理页面
class AddressManagePage extends StatefulWidget {
  const AddressManagePage({super.key});

  @override
  State<AddressManagePage> createState() => _AddressManagePageState();
}

class _AddressManagePageState extends State<AddressManagePage> {
  // 地址信息
  String _address = '';
  String _phone = '';
  String _realName = '';
  bool _isLoading = false;
  bool _isSaving = false;

  // 控制器
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _realNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _realNameController.dispose();
    super.dispose();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthManager.getUser();
      if (user != null) {
        setState(() {
          _address = user['address'] ?? '';
          _phone = user['phone_display'] ?? user['phone'] ?? '';
          _realName = user['real_name'] ?? '';

          _addressController.text = _address;
          _phoneController.text = _phone;
          _realNameController.text = _realName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 保存地址信息
  Future<void> _saveAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入收货地址')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await AuthManager.getToken();
      if (token == null) {
        throw Exception('用户未登录');
      }

      await UserService.updateUserInfo(
        token: token,
        address: _addressController.text.trim(),
        phoneDisplay: _phoneController.text.trim(),
        realName: _realNameController.text.trim(),
      );

      // 更新本地存储的用户信息
      final user = await AuthManager.getUser();
      if (user != null) {
        user['address'] = _addressController.text.trim();
        user['phone_display'] = _phoneController.text.trim();
        user['real_name'] = _realNameController.text.trim();
        await AuthManager.saveLogin(token, user);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地址保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          '收货地址',
          style: TextStyle(
            color: Color(0xFF1A1A2C),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2C)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 提示信息
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '请填写准确的收货地址，以便卖家发货',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 收货人姓名
                  _buildInputLabel('收货人姓名'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _realNameController,
                    hintText: '请输入收货人姓名',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  // 联系电话
                  _buildInputLabel('联系电话'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hintText: '请输入联系电话',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // 收货地址
                  _buildInputLabel('详细地址'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _addressController,
                    hintText: '请输入详细收货地址（省市区街道门牌号）',
                    prefixIcon: Icons.location_on_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE965B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '保存地址',
                              style: TextStyle(
                                fontSize: 16,
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

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2C),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
