import 'package:flutter/material.dart';
import '../../image_upload_service.dart';
import '../../services/seller_service.dart';
import '../../api.dart';

/// 编辑商品页面
class ProductEditPage extends StatefulWidget {
  final dynamic product;

  const ProductEditPage({
    super.key,
    required this.product,
  });

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _descriptionController;

  String? _selectedCategory;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _stockController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadCategories();
    _loadProductData();
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.getCategories();
    if (result['success'] && mounted) {
      var rawData = result['data'];
      if (rawData is List) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(rawData);
          _categories.removeWhere((c) => c['id'] == 'all');
        });
      }
    }
  }

  void _loadProductData() {
    final product = widget.product;
    _nameController.text = product['product_name'] ?? '';
    _priceController.text = product['price']?.toString() ?? '';
    _stockController.text = product['stock']?.toString() ?? '';
    _descriptionController.text = product['description'] ?? '';
    _selectedCategory = product['category'];
    _uploadedImageUrl = product['image_url'];
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
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

    final productData = {
      'product_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text),
      'stock': int.parse(_stockController.text),
      'category': _selectedCategory,
      'image_url': _uploadedImageUrl,
    };

    final result = await SellerService.updateProduct(
      widget.product['product_id'],
      productData,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('商品更新成功')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '更新失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '编辑商品',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
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
                    '保存',
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
                  if (price > 99999999.99) {
                    return '价格不能超过 99,999,999.99';
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

              // 保存按钮
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
                          '保存修改',
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
                    ],
                  ),
      ),
    );
  }

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
        disabledHint: _categories.isEmpty
            ? Text(
                '加载中...',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              )
            : null,
        alignment: AlignmentDirectional.centerStart,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
        items: _categories.isEmpty
            ? []
            : _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category['id']?.toString(),
                  child: Text(category['name']?.toString() ?? ''),
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
