import 'dart:async';
import 'package:flutter/material.dart';
import 'ai_chat_service.dart';
import 'product_detail_page.dart';

/// 聊天消息模型
class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.isUser,
    this.content = '',
    this.products = const [],
    this.isLoading = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 聊天底部弹窗
class AiChatBottomSheet extends StatefulWidget {
  const AiChatBottomSheet({super.key});

  @override
  State<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends State<AiChatBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isAiResponding = false;
  StreamSubscription<AiStreamEvent>? _streamSubscription;

  // 当前正在构建的 AI 消息
  ChatMessage? _currentAiMessage;

  @override
  void initState() {
    super.initState();
    // 添加欢迎消息
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'welcome',
          isUser: false,
          content:
              '你好！我是你的智能导购助手。\n\n告诉我你想买什么，比如 "我想买一台笔记本电脑" 或 "推荐一些适合运动的装备"，我会为你推荐合适的商品！',
        ),
      );
    });
  }

  /// 发送消息
  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isAiResponding) return;

    // 添加用户消息
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isUser: true,
          content: text,
        ),
      );
      _isAiResponding = true;
    });

    _inputController.clear();
    _scrollToBottom();

    // 发送请求并处理流式响应
    _sendAiRequest(text);
  }

  /// 发送 AI 请求
  void _sendAiRequest(String question) {
    _currentAiMessage = ChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      content: '',
      isLoading: true,
    );

    setState(() {
      _messages.add(_currentAiMessage!);
    });

    String accumulatedContent = '';
    List<Map<String, dynamic>> products = [];

    _streamSubscription =
        AiChatService.sendMessage(question: question, nResults: 3).listen(
          (event) {
            setState(() {
              if (event is MetaEvent) {
                products = event.products;
                _currentAiMessage = ChatMessage(
                  id: _currentAiMessage!.id,
                  isUser: false,
                  content: accumulatedContent,
                  products: products,
                  isLoading: true,
                );
                _updateLastMessage(_currentAiMessage!);
              } else if (event is TokenEvent) {
                accumulatedContent += event.token;
                _currentAiMessage = ChatMessage(
                  id: _currentAiMessage!.id,
                  isUser: false,
                  content: accumulatedContent,
                  products: products,
                  isLoading: true,
                );
                _updateLastMessage(_currentAiMessage!);
                _scrollToBottom();
              } else if (event is DoneEvent) {
                _currentAiMessage = ChatMessage(
                  id: _currentAiMessage!.id,
                  isUser: false,
                  content: accumulatedContent,
                  products: products,
                  isLoading: false,
                );
                _updateLastMessage(_currentAiMessage!);
                _isAiResponding = false;
              } else if (event is ErrorEvent) {
                _currentAiMessage = ChatMessage(
                  id: _currentAiMessage!.id,
                  isUser: false,
                  content: accumulatedContent.isEmpty
                      ? '抱歉，发生了错误: ${event.message}'
                      : accumulatedContent,
                  products: products,
                  isLoading: false,
                );
                _updateLastMessage(_currentAiMessage!);
                _isAiResponding = false;
              }
            });
          },
          onError: (error) {
            setState(() {
              _currentAiMessage = ChatMessage(
                id: _currentAiMessage!.id,
                isUser: false,
                content: '抱歉，网络连接出现问题，请稍后重试。',
                products: products,
                isLoading: false,
              );
              _updateLastMessage(_currentAiMessage!);
              _isAiResponding = false;
            });
          },
          onDone: () {
            setState(() {
              _isAiResponding = false;
            });
          },
        );
  }

  /// 更新最后一条消息
  void _updateLastMessage(ChatMessage message) {
    if (_messages.isNotEmpty) {
      _messages[_messages.length - 1] = message;
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 显示商品详情弹窗
  void _showProductDetail(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductDetailCard(product: product),
    );
  }

  String _sanitizeAiMessageContent(String content) {
    var result = content;

    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<!\])(/product/[A-Za-z0-9_\-]+)'),
      (match) => '',
    );
    result = result.replaceAllMapped(
      RegExp(r'https?://[^\s)]+'),
      (match) => '',
    );
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    result = result.replaceAll(RegExp(r'\s+([,，。.!?！？:：;；])'), r'$1');

    return result.trim();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动条指示器
          _buildHandleBar(),

          // 标题栏
          _buildHeader(),

          // 消息列表
          Expanded(child: _buildMessageList()),

          // 输入框区域
          _buildInputArea(bottomPadding),
        ],
      ),
    );
  }

  /// 拖动条指示器
  Widget _buildHandleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// 标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能导购',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2C),
                  ),
                ),
                Text(
                  '为你推荐最合适的商品',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 消息列表
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Column(
          children: [
            _buildChatBubble(message),
            // AI 消息下方显示商品卡片
            if (!message.isUser && message.products.isNotEmpty)
              _buildProductCardsRow(message.products),
          ],
        );
      },
    );
  }

  /// 聊天气泡
  Widget _buildChatBubble(ChatMessage message) {
    if (message.isUser) {
      // 用户消息 - 右侧，主色背景
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 60, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFCE965B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCE965B).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    } else {
      // AI 消息 - 左侧，灰色背景
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 头像
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 60, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: message.isLoading && message.content.isEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI 正在思考中...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _sanitizeAiMessageContent(message.content),
                        style: const TextStyle(
                          color: Color(0xFF1A1A2C),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 商品卡片横向滚动列表
  Widget _buildProductCardsRow(List<Map<String, dynamic>> products) {
    return Container(
      height: 170,
      margin: const EdgeInsets.only(left: 44, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  /// 商品卡片
  Widget _buildProductCard(Map<String, dynamic> product) {
    final productName = product['product_name'] ?? product['name'] ?? '未知商品';
    final price = product['price'] ?? 0.0;
    final category = product['category'] ?? '其他';
    final productId =
        product['product_id']?.toString() ?? product['id']?.toString() ?? '';
    final productUrl =
        product['product_url']?.toString() ?? product['url']?.toString() ?? '';
    final hasDetailLink = productId.isNotEmpty || productUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _showProductDetail(context, product),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 6),
            Text(
              '¥${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCE965B),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: hasDetailLink
                    ? () => _showProductDetail(context, product)
                    : null,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('查看详情'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFCE965B),
                  backgroundColor: const Color(0xFFCE965B).withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 输入框区域
  Widget _buildInputArea(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isAiResponding,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isAiResponding ? 'AI 正在回复中...' : '输入你想购买的商品...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isAiResponding ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isAiResponding
                    ? LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFCE965B), Color(0xFFD67F1F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isAiResponding
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFCE965B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// 商品详情卡片（内嵌在弹窗中）
class _ProductDetailCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductDetailCard({required this.product});

  @override
  Widget build(BuildContext context) {
    // 适配后端返回的字段名
    final productName = product['product_name'] ?? product['name'] ?? '未知商品';
    final price = product['price'] ?? 0.0;
    final category = product['category'] ?? '其他';
    final description = product['description'] ?? product['desc'] ?? '暂无描述';
    final productId =
        product['product_id']?.toString() ?? product['id']?.toString() ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 商品信息
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分类标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCE965B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCE965B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 商品名称
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2C),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 价格
                  Text(
                    '¥${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCE965B),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 描述
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 按钮区域
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (productId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProductDetailPage(productId: productId),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('查看详情'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCE965B),
                            side: const BorderSide(color: Color(0xFFCE965B)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('关闭'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCE965B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
