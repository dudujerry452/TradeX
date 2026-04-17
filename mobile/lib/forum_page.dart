import 'package:flutter/material.dart';

import 'api.dart';
import 'auth_manager.dart';
import 'pages/forum/forum_post_composer_page.dart';

final RegExp _forumImageMarkdownRegex = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

bool _forumIsImageMarkdownLine(String line) {
  return _forumImageMarkdownRegex.hasMatch(line);
}

String? _forumExtractFirstImageUrl(String content) {
  for (final rawLine in content.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    final match = _forumImageMarkdownRegex.firstMatch(line);
    if (match != null) {
      final url = match.group(1)?.trim() ?? '';
      if (url.isNotEmpty) {
        return url;
      }
    }
  }
  return null;
}

List<String> _forumExtractImageUrls(String content, {String? coverImageUrl}) {
  final imageUrls = <String>[];
  final seenUrls = <String>{};

  void addUrl(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty || seenUrls.contains(url)) {
      return;
    }

    seenUrls.add(url);
    imageUrls.add(url);
  }

  addUrl(coverImageUrl);
  for (final match in _forumImageMarkdownRegex.allMatches(content)) {
    addUrl(match.group(1));
  }

  return imageUrls;
}

String _forumExtractPreviewText(String content, {int maxLength = 120}) {
  final lines = content.split(RegExp(r'\r?\n'));
  final buffer = StringBuffer();

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || _forumIsImageMarkdownLine(line)) {
      continue;
    }

    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(line);

    if (buffer.length >= maxLength) {
      break;
    }
  }

  final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return '暂无内容';
  }
  return text.length <= maxLength ? text : '${text.substring(0, maxLength)}...';
}

class ForumPage extends StatefulWidget {
  final bool embedded;

  const ForumPage({super.key, this.embedded = false});

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _tags = [];
  List<dynamic> _posts = [];

  String _selectedCategory = 'all';
  String? _selectedTag;
  String _ordering = '-published_at';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refreshPosts = true}) async {
    setState(() {
      _isLoading = true;
    });

    final categoriesResult = await ApiService.getForumCategories();
    final tagsResult = await ApiService.getForumTags();

    if (categoriesResult['success'] == true) {
      final rawCategories = categoriesResult['data'];
      if (rawCategories is List) {
        _categories = List<Map<String, dynamic>>.from(rawCategories);
      }
    }

    if (tagsResult['success'] == true) {
      final rawTags = tagsResult['data'];
      if (rawTags is List) {
        _tags = List<Map<String, dynamic>>.from(rawTags);
      }
    }

    if (refreshPosts) {
      await _fetchPosts();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _fetchPosts() async {
    final result = await ApiService.getForumPosts(
      query: _searchController.text.trim(),
      categoryId: _selectedCategory,
      tag: _selectedTag,
      ordering: _ordering,
      limit: 50,
      offset: 0,
    );

    if (result['success'] == true && mounted) {
      final rawPosts = result['data'];
      if (rawPosts is List) {
        setState(() {
          _posts = rawPosts;
        });
      }
    }

    return result;
  }

  Future<void> _refreshPosts() async {
    await _fetchPosts();
  }

  Future<void> _searchPosts() async {
    await _fetchPosts();
  }

  Future<void> _toggleLike(dynamic post) async {
    final token = await AuthManager.getToken();
    if (token == null) {
      _showSnackBar('请先登录');
      return;
    }

    final result = await ApiService.toggleForumPostLike(post['post_id']);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        post['is_liked'] = result['data']['liked'] ?? false;
        post['like_count'] = result['data']['like_count'] ?? post['like_count'];
      });
    }

    _showSnackBar(
      result['message'] ?? (result['success'] == true ? '操作成功' : '操作失败'),
    );
  }

  Future<void> _openComposer() async {
    final token = await AuthManager.getToken();
    if (token == null) {
      _showSnackBar('请先登录');
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostComposerPage(categories: _categories),
      ),
    );

    if (created == true) {
      await _refreshPosts();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) {
      return '刚刚';
    }
    return text.replaceFirst('T', ' ').split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: const Color(0xFFCE965B),
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('发帖', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    return Column(
      children: [
        _buildTopBar(),
        _buildSearchBar(),
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshPosts,
            color: const Color(0xFFCE965B),
            child: _posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.forum_outlined,
                        size: 72,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '暂无帖子，先发一条试试',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _buildPostCard(post);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFCE965B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.forum, color: Color(0xFFCE965B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TradeX 论坛',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '发帖、评论、点赞、搜索和分类筛选',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _openComposer,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCE965B),
              backgroundColor: const Color(0xFFCE965B).withOpacity(0.10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text(
              '发帖',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _refreshPosts,
            icon: const Icon(Icons.refresh, color: Color(0xFFCE965B)),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _searchPosts(),
                decoration: InputDecoration(
                  hintText: '搜索帖子、话题、关键词',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 6),
              child: TextButton(
                onPressed: _searchPosts,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFCE965B),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '搜索',
                  style: TextStyle(
                    color: Colors.white,
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

  Widget _buildFilterBar() {
    final sortOptions = <String, String>{
      '-published_at': '最新',
      'hot': '最热',
      '-like_count': '点赞最多',
      '-comment_count': '评论最多',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Row(
            children: [
              Text(
                '排序',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _ordering,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: sortOptions.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _ordering = value;
                        });
                        _searchPosts();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '分类',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = _selectedCategory == category['id'];
                return _buildFilterChip(
                  label: category['name']?.toString() ?? '',
                  selected: selected,
                  selectedTextColor: Colors.white,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['id'];
                      _selectedTag = null;
                    });
                    _searchPosts();
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _categories.length,
            ),
          ),
        ],
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '标签',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final tagName = tag['tag_name']?.toString() ?? '';
                final selected = _selectedTag == tagName;
                return _buildFilterChip(
                  label: tagName,
                  selected: selected,
                  selectedTextColor: const Color(0xFFCE965B),
                  onTap: () {
                    setState(() {
                      _selectedTag = selected ? null : tagName;
                    });
                    _searchPosts();
                  },
                  selectedFillColor: const Color(0xFFCE965B).withOpacity(0.14),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _tags.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedFillColor,
    Color? selectedTextColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected && selectedTextColor == Colors.white
            ? const LinearGradient(
                colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
              )
            : null,
        color: selected && selectedTextColor != Colors.white
            ? selectedFillColor
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFFCE965B).withOpacity(0.18)
                : Colors.black.withOpacity(0.04),
            blurRadius: selected ? 10 : 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: selected ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (selectedTextColor ?? Colors.white)
                  : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final tags = (post['tags'] as List?)?.cast<dynamic>() ?? [];
    final content = (post['content'] ?? '').toString();
    final preview = _forumExtractPreviewText(content);
    final coverImageUrl =
        (post['cover_image_url'] ?? '').toString().trim().isNotEmpty
        ? (post['cover_image_url'] ?? '').toString().trim()
        : (_forumExtractFirstImageUrl(content) ?? '');
    final postId = post['post_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumPostDetailPage(postId: postId),
          ),
        );
        await _refreshPosts();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            if (coverImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Image.network(
                    coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 42,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (coverImageUrl.isNotEmpty) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    post['title']?.toString() ?? '未命名帖子',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2C),
                    ),
                  ),
                ),
                if (post['is_pinned'] == true)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCE965B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '置顶',
                      style: TextStyle(color: Color(0xFFCE965B), fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (post['category_name'] != null)
                  Chip(
                    label: Text(post['category_name'].toString()),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFCE965B).withOpacity(0.08),
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      color: Color(0xFFCE965B),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ...tags.map(
                  (tag) => Chip(
                    label: Text(tag.toString()),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${post['author_name'] ?? '匿名'} · ${_formatTime(post['published_at'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                _buildStatPill(
                  Icons.remove_red_eye_outlined,
                  post['view_count'] ?? 0,
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: post['is_liked'] == true
                          ? const Color(0xFFCE965B).withOpacity(0.14)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          post['is_liked'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color: post['is_liked'] == true
                              ? const Color(0xFFCE965B)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (post['like_count'] ?? 0).toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: post['is_liked'] == true
                                ? const Color(0xFFCE965B)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildStatPill(
                  Icons.comment_outlined,
                  post['comment_count'] ?? 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class ForumPostDetailPage extends StatefulWidget {
  final String postId;

  const ForumPostDetailPage({super.key, required this.postId});

  @override
  State<ForumPostDetailPage> createState() => _ForumPostDetailPageState();
}

class _ForumPostDetailPageState extends State<ForumPostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final PageController _imagePageController = PageController();

  Map<String, dynamic>? _post;
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.getForumPostDetail(widget.postId);
    if (!mounted) return;

    if (result['success'] == true) {
      final shouldResetCarousel = _imagePageController.hasClients;
      setState(() {
        _post = Map<String, dynamic>.from(result['data']);
        _isLoading = false;
        _currentImageIndex = 0;
      });

      if (shouldResetCarousel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_imagePageController.hasClients) {
            return;
          }
          _imagePageController.jumpToPage(0);
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? '加载失败')));
    }
  }

  Future<void> _toggleLike() async {
    final token = await AuthManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    final result = await ApiService.toggleForumPostLike(widget.postId);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _post?['is_liked'] = result['data']['liked'] ?? false;
        _post?['like_count'] =
            result['data']['like_count'] ?? _post?['like_count'];
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message'] ?? (result['success'] == true ? '操作成功' : '操作失败'),
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    final token = await AuthManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    final content = _commentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入评论内容')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await ApiService.createForumComment(
      postId: widget.postId,
      content: content,
    );
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      _commentController.clear();
      await _loadPost();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论成功')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? '评论失败')));
    }
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) {
      return '刚刚';
    }
    return text.replaceFirst('T', ' ').split('.').first;
  }

  Widget _buildStatPill(IconData icon, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> imageUrls) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 240,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: PageView.builder(
          controller: _imagePageController,
          itemCount: imageUrls.length,
          onPageChanged: (index) {
            if (!mounted) {
              return;
            }

            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final imageUrl = imageUrls[index];
            return Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 44,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageIndicator(int imageCount) {
    return Column(
      children: [
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(imageCount, (index) {
              final isActive = index == _currentImageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFCE965B)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_currentImageIndex + 1} / $imageCount',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContentBlocks(String content) {
    final widgets = <Widget>[];
    final textBuffer = <String>[];

    void flushTextBuffer() {
      if (textBuffer.isEmpty) {
        return;
      }

      final text = textBuffer.join('\n').trim();
      if (text.isNotEmpty) {
        widgets.add(
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF2C2C38),
            ),
          ),
        );
      }
      textBuffer.clear();
    }

    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushTextBuffer();
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }

      final match = _forumImageMarkdownRegex.firstMatch(line);
      if (match != null) {
        final cleanedLine = rawLine
            .replaceAll(_forumImageMarkdownRegex, '')
            .trim();
        if (cleanedLine.isEmpty) {
          flushTextBuffer();
          continue;
        }

        textBuffer.add(cleanedLine);
        continue;
      }

      textBuffer.add(rawLine);
    }

    flushTextBuffer();

    if (widgets.isEmpty) {
      if (content.trim().isEmpty) {
        widgets.add(
          Text(
            '暂无内容',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF2C2C38),
            ),
          ),
        );
      }
    }

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final coverImageUrl = (_post?['cover_image_url'] ?? '').toString().trim();
    final content = _post?['content']?.toString() ?? '';
    final imageUrls = _forumExtractImageUrls(
      content,
      coverImageUrl: coverImageUrl.isNotEmpty
          ? coverImageUrl
          : _forumExtractFirstImageUrl(content),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('帖子详情'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2C),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
              ),
            )
          : _post == null
          ? const Center(child: Text('帖子不存在'))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPost,
                    color: const Color(0xFFCE965B),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 4,
                                width: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFCE965B),
                                      Color(0xFFD67F1F),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _post!['title']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2C),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    '${_post!['author_name'] ?? '匿名'} · ${_formatTime(_post!['published_at'])}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_post!['category_name'] != null)
                                    Chip(
                                      label: Text(
                                        _post!['category_name'].toString(),
                                      ),
                                      backgroundColor: const Color(
                                        0xFFCE965B,
                                      ).withOpacity(0.08),
                                      side: BorderSide.none,
                                      labelStyle: const TextStyle(
                                        color: Color(0xFFCE965B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (imageUrls.isNotEmpty) ...[
                                _buildImageCarousel(imageUrls),
                                _buildImageIndicator(imageUrls.length),
                                const SizedBox(height: 12),
                              ],
                              ..._buildContentBlocks(content),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  ...((_post!['tags'] as List?) ?? []).map(
                                    (tag) => Chip(
                                      label: Text(tag.toString()),
                                      backgroundColor: Colors.grey.shade100,
                                      side: BorderSide.none,
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildStatPill(
                                    Icons.remove_red_eye_outlined,
                                    _post!['view_count'] ?? 0,
                                  ),
                                  _buildStatPill(
                                    Icons.comment_outlined,
                                    _post!['comment_count'] ?? 0,
                                  ),
                                  InkWell(
                                    onTap: _toggleLike,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (_post!['is_liked'] == true)
                                            ? const Color(
                                                0xFFCE965B,
                                              ).withOpacity(0.14)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _post!['is_liked'] == true
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: _post!['is_liked'] == true
                                                ? const Color(0xFFCE965B)
                                                : Colors.grey.shade600,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '点赞 ${_post!['like_count'] ?? 0}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _post!['is_liked'] == true
                                                  ? const Color(0xFFCE965B)
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '评论',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2C),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_post!['comments'] as List?)?.length ?? 0} 条',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(((_post!['comments'] as List?) ?? [])).map(
                          (comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFCE965B,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Color(0xFFCE965B),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['author_name']
                                                      ?.toString() ??
                                                  '匿名',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A2C),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatTime(
                                                comment['created_at'],
                                              ),
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    comment['content']?.toString() ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 12 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: '写下你的评论',
                            filled: true,
                            fillColor: const Color(0xFFF5F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE965B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('发送'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ForumComposerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const _ForumComposerSheet({required this.categories});

  @override
  State<_ForumComposerSheet> createState() => _ForumComposerSheetState();
}

class _ForumComposerSheetState extends State<_ForumComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final tagNames = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final result = await ApiService.createForumPost(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      categoryId: _selectedCategoryId,
      tagNames: tagNames,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? '发帖失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '发布帖子',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '请输入标题'
                          : null,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentController,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '请输入内容'
                          : null,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: '分类',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.categories
                          .where((category) => category['id'] != 'all')
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: '标签（逗号分隔）',
                        hintText: '例如：经验分享, 求助, 测评',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE965B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('发布'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
