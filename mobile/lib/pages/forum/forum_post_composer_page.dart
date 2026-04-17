import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api.dart';
import '../../auth_manager.dart';
import '../../image_upload_service.dart';

class ForumPostComposerPage extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const ForumPostComposerPage({super.key, this.categories = const []});

  @override
  State<ForumPostComposerPage> createState() => _ForumPostComposerPageState();
}

class _ForumPostComposerPageState extends State<ForumPostComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  final List<_ForumImageDraft> _selectedImages = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = false;
  bool _isPickingImages = false;
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (widget.categories.isNotEmpty) {
      _applyCategories(widget.categories);
      return;
    }

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final result = await ApiService.getForumCategories();
      if (result['success'] == true) {
        final rawCategories = result['data'];
        if (rawCategories is List) {
          _applyCategories(List<Map<String, dynamic>>.from(rawCategories));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  void _applyCategories(List<Map<String, dynamic>> categories) {
    final filtered = categories
        .where((category) => category['id'] != 'all')
        .toList();

    setState(() {
      _categories = filtered;
      _selectedCategoryId ??= filtered.isNotEmpty
          ? filtered.first['id']?.toString()
          : null;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) return;

    setState(() {
      _isPickingImages = true;
      _statusMessage = '正在选择图片';
    });

    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 1600,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final existingPaths = _selectedImages.map((item) => item.path).toSet();
      final drafts = <_ForumImageDraft>[];

      for (final pickedFile in pickedFiles) {
        if (existingPaths.contains(pickedFile.path) ||
            drafts.any((item) => item.path == pickedFile.path)) {
          continue;
        }

        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) {
          continue;
        }

        drafts.add(_ForumImageDraft(file: pickedFile, bytes: bytes));
      }

      if (drafts.isEmpty) {
        _showSnackBar('未添加新的图片');
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImages.addAll(drafts);
      });
    } catch (e) {
      _showSnackBar('选择图片失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImages = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  List<String> _buildTagNames() {
    return _tagsController.text
        .split(RegExp(r'[\n,，;；]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String _buildSubmissionContent(List<String> uploadedImageUrls) {
    final body = _contentController.text.trim();
    final extraImageUrls = uploadedImageUrls.skip(1).toList();

    final parts = <String>[];
    if (body.isNotEmpty) {
      parts.add(body);
    }

    if (extraImageUrls.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts.add('');
      }
      parts.addAll(extraImageUrls.map((url) => '![image]($url)'));
    }

    return parts.join('\n');
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final token = await AuthManager.getToken();
    if (token == null) {
      _showSnackBar('请先登录');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = _selectedImages.isNotEmpty
          ? '正在上传图片 0/${_selectedImages.length}'
          : '正在发布帖子';
    });

    try {
      final uploadedImageUrls = <String>[];
      for (var index = 0; index < _selectedImages.length; index++) {
        if (!mounted) return;

        setState(() {
          _statusMessage = '正在上传图片 ${index + 1}/${_selectedImages.length}';
        });

        final result = await ImageUploadService.uploadXFile(
          _selectedImages[index].file,
        );

        if (result['success'] != true) {
          throw Exception(result['message'] ?? '图片上传失败');
        }

        final url = result['url']?.toString().trim() ?? '';
        if (url.isEmpty) {
          throw Exception('图片上传失败，未返回有效地址');
        }

        uploadedImageUrls.add(url);
      }

      if (!mounted) return;

      setState(() {
        _statusMessage = '正在发布帖子';
      });

      final result = await ApiService.createForumPost(
        title: _titleController.text.trim(),
        content: _buildSubmissionContent(uploadedImageUrls),
        categoryId: _selectedCategoryId,
        tagNames: _buildTagNames(),
        coverImageUrl: uploadedImageUrls.isNotEmpty
            ? uploadedImageUrls.first
            : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message'] ?? '发帖失败');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = null;
        });
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCE965B).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '发布新帖子',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持多选图片，第一张会自动作为封面，其他图片会插入正文。',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeaderChip(icon: Icons.collections_outlined, label: '多图上传'),
              const SizedBox(width: 8),
              _buildHeaderChip(icon: Icons.sort_outlined, label: '自由排序'),
              const SizedBox(width: 8),
              _buildHeaderChip(icon: Icons.image_outlined, label: '封面自动生成'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImageGrid() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _selectedImages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return SizedBox(width: 150, child: _buildAddImageTile());
          }

          final draft = _selectedImages[index];
          final isCover = index == 0;

          return SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey.shade100),
                  Image.memory(
                    draft.bytes,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCover ? '封面' : '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: InkWell(
                      onTap: () => _removeImageAt(index),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddImageTile() {
    return InkWell(
      onTap: _isPickingImages ? null : _pickImages,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
        ),
        child: Center(
          child: _isPickingImages
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFCE965B),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 30,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '添加图片',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '图片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2C),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isPickingImages ? null : _pickImages,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFCE965B),
                  backgroundColor: const Color(0xFFCE965B).withOpacity(0.10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isPickingImages
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFCE965B),
                          ),
                        ),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text(
                  '添加图片',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '支持重复添加，多选不限张。第一张图片会作为封面。',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_selectedImages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 42,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '还没有添加图片',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            _buildImageGrid(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (_statusMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            minHeight: 4,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField() {
    if (_isLoadingCategories) {
      return const LinearProgressIndicator(
        minHeight: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
      );
    }

    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          '暂无可用分类，发布时可留空',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: '分类',
        labelStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFCE965B)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _categories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category['id']?.toString(),
              child: Text(category['name']?.toString() ?? ''),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
    );
  }

  Widget _buildTextFieldCard({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2C),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCE965B),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '发布帖子',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2C),
        elevation: 0.5,
        title: const Text('发布帖子'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text(
              '发布',
              style: TextStyle(
                color: Color(0xFFCE965B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildHeader(),
                  _buildLoadingIndicator(),
                  const SizedBox(height: 16),
                  _buildTextFieldCard(
                    title: '标题',
                    subtitle: '给你的帖子起一个清晰的标题',
                    child: TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '请输入标题'
                          : null,
                      decoration: InputDecoration(
                        hintText: '例如：分享一波我的开箱体验',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Color(0xFFCE965B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFieldCard(
                    title: '内容',
                    subtitle: '图片会自动插入到正文末尾',
                    child: TextFormField(
                      controller: _contentController,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '请输入内容'
                          : null,
                      minLines: 7,
                      maxLines: 12,
                      decoration: InputDecoration(
                        hintText: '分享你的想法、经验或问题...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Color(0xFFCE965B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFieldCard(
                    title: '分类',
                    subtitle: '选择一个最贴近内容的分类',
                    child: _buildCategoryField(),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFieldCard(
                    title: '标签',
                    subtitle: '多个标签请用逗号、中文逗号或换行分隔',
                    child: TextFormField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        hintText: '例如：经验分享, 求助, 测评',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          borderSide: BorderSide(color: Color(0xFFCE965B)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImageSection(),
                  const SizedBox(height: 20),
                  _buildPublishButton(),
                  const SizedBox(height: 12),
                  Text(
                    '发布后，正文中的图片会按顺序展示，首图会作为帖子封面。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(
                  child: SizedBox(
                    width: 120,
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFCE965B),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              '正在发布',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ForumImageDraft {
  final XFile file;
  final Uint8List bytes;

  const _ForumImageDraft({required this.file, required this.bytes});

  String get path => file.path;
}
