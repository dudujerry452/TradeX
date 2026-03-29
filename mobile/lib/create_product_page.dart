import 'package:flutter/material.dart';
import 'image_upload_service.dart';
import 'api.dart';
import 'auth_manager.dart';

/// 创建商品页面
class CreateProductPage extends StatefulWidget {
  const CreateProductPage({super.key});

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  // 分类与后端 seed 数据保持一致
  final List<Map<String, String>> _categories = [
    {'id': '手机数码', 'name': '手机数码'},
    {'id': '音频设备', 'name': '音频设备'},
    {'id': '电脑外设', 'name': '电脑外设'},
    {'id': '智能穿戴', 'name': '智能穿戴'},
    {'id': '生活家电', 'name': '生活家电'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 选择并上传图片
  /// 支持移动端和Web端
  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Web端和移动端统一处理
      final result = await ImageUploadService.uploadImage();

      if (result['success'] == true) {
        setState(() {
          _uploadedImageUrl = result['url'];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '上传失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传出错: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// 提交表单
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传商品图片')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 获取当前用户ID
    final userId = await AuthManager.getUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    final productData = {
      'product_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text),
      'stock': int.parse(_stockController.text),
      'category': _selectedCategory,
      'publisher_id': userId,
      'image_url': _uploadedImageUrl,
    };

    final result = await ApiService.createProduct(productData);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('商品发布成功')),
        );
        // 清空表单，让用户可以继续发布或切换到其他页面
        _formKey.currentState?.reset();
        _nameController.clear();
        _priceController.clear();
        _stockController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedCategory = null;
          _uploadedImageUrl = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '发布失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '发布商品',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitForm,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFCE965B)),
                    ),
                  )
                : const Text(
                    '发布',
                    style: TextStyle(
                      color: Color(0xFFCE965B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              _buildImageSection(),
              const SizedBox(height: 24),

              // 商品名称
              _buildLabel('商品名称'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('请输入商品名称'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入商品名称';
                  }
                  if (value.trim().length < 2) {
                    return '商品名称至少2个字符';
                  }
                  if (value.trim().length > 50) {
                    return '商品名称最多50个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 分类选择
              _buildLabel('商品分类'),
              const SizedBox(height: 8),
              _buildCategoryDropdown(),
              const SizedBox(height: 20),

              // 价格
              _buildLabel('价格'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                decoration: _inputDecoration('请输入价格').copyWith(
                  prefixText: '¥ ',
                  prefixStyle: const TextStyle(
                    color: Color(0xFFCE965B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入价格';
                  }
                  final price = double.tryParse(value);
                  if (price == null) {
                    return '请输入有效的价格';
                  }
                  if (price <= 0) {
                    return '价格必须大于0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 库存
              _buildLabel('库存'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _stockController,
                decoration: _inputDecoration('请输入库存数量'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入库存数量';
                  }
                  final stock = int.tryParse(value);
                  if (stock == null) {
                    return '请输入有效的库存数量';
                  }
                  if (stock < 0) {
                    return '库存不能为负数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 商品描述
              _buildLabel('商品描述'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('请输入商品描述，详细介绍商品的特点、使用情况等'),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入商品描述';
                  }
                  if (value.trim().length < 10) {
                    return '商品描述至少10个字符';
                  }
                  if (value.trim().length > 500) {
                    return '商品描述最多500个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 发布按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCE965B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '发布商品',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  /// 输入框统一样式
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
      ),
      filled: true,
      fillColor: const Color(0xFFF0F1F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFCE965B),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  /// 图片区域
  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _uploadedImageUrl != null
                ? const Color(0xFFCE965B)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: _isUploading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFFCE965B)),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '上传中...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _uploadedImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _uploadedImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF0F1F5),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '图片预览',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '点击上传商品图片',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '暂支持占位图',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// 分类下拉框
  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        hint: Text(
          '请选择分类',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        alignment: AlignmentDirectional.centerStart,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem<String>(
            value: category['id'],
            child: Text(category['name']!),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请选择商品分类';
          }
          return null;
        },
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCE965B)),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      ),
    );
  }
}
