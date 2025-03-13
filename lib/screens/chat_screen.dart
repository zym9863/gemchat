import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'api_key_screen.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSidebarExpanded = true; // 控制侧边栏是否展开
  @override
  void initState() {
    super.initState();
    // 检查是否已设置API密钥
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKey();
    });
    
    // 添加键盘焦点监听
    _messageController.addListener(() {
      setState(() {});
    });
  }
  Future<void> _checkApiKey() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final hasKey = await chatProvider.hasApiKey();
    if (!hasKey) {
      // 如果未设置API密钥，导航到API密钥设置界面
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ApiKeyScreen(),
        ),
      );
    }
  }
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
  final chatProvider = Provider.of<ChatProvider>(context, listen: false);
  chatProvider.addUserMessage(message);
  _messageController.clear();
  // 滚动到底部
  Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
  }
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  // 切换侧边栏展开/折叠状态
  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }
  @override
  Widget build(BuildContext context) {
    final appTheme = Provider.of<AppTheme>(context);
    final isDarkMode = appTheme.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _toggleSidebar,
          tooltip: '切换侧边栏',
        ),
        title: Row(
          children: [
            const Text('Gemini Chat', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 16),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                return DropdownButton<String>(
                  value: chatProvider.currentModel,
                  items: chatProvider.availableModels.map((String model) {
                    return DropdownMenuItem<String>(
                      value: model,
                      child: Text(model, style: TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      chatProvider.setCurrentModel(newValue);
                    }
                  },
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 12),
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color),
                  dropdownColor: Theme.of(context).cardColor,
                );
              },
            ),
          ],
        ),
        actions: [
          // 主题切换按钮
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? '切换到浅色主题' : '切换到深色主题',
            onPressed: () {
              appTheme.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ApiKeyScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空聊天',
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).clearChat();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 侧边栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarExpanded ? 250 : 0,
            child: _isSidebarExpanded ? _buildSidebar() : null,
          ),
          // 垂直分隔线
          if (_isSidebarExpanded)
            VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
          // 聊天主界面
          Expanded(
            child: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final messages = chatProvider.messages;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageItem(message);
                  },
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.isLoading) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (chatProvider.errorMessage.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    chatProvider.errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SingleChildScrollView(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: '输入消息...',
                          prefixIcon: Icon(Icons.message_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          helperText: 'Enter键换行，Ctrl+Enter发送消息',
                          helperStyle: TextStyle(fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        scrollPhysics: BouncingScrollPhysics(),
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _messageController.text.trim().isEmpty ? null : _sendMessage,
                  tooltip: '发送消息',
                ),
              ],
            ),
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }
  Widget _buildMessageItem(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 消息内容
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: message.isUser
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[900]
                        : Colors.blue[100])
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200]),
                borderRadius: BorderRadius.circular(12.0),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息内容
                  message.isUser
                      ? Text(
                          message.content,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            code: TextStyle(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[200],
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[850]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          builders: {
                            'pre': CustomCodeBlockBuilder(
                              copyToClipboard: _copyToClipboard,
                              context: context,
                            ),
                          },
                        ),
                  // AI回复底部的按钮（仅在AI回复时显示）
                  if (!message.isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: '复制',
                            onPressed: () {
                              // 复制消息内容到剪贴板
                              _copyToClipboard(message.content);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 16,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            tooltip: '重新生成',
                            onPressed: () {
                              // 获取消息索引并重新生成
                              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                              final messages = chatProvider.messages;
                              final index = messages.indexOf(message);
                              if (index != -1) {
                                chatProvider.regenerateAIResponse(index);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 16,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 用户消息右侧的按钮（仅在用户消息时显示）
          if (message.isUser)
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: '复制',
                  onPressed: () {
                    // 复制消息内容到剪贴板
                    _copyToClipboard(message.content);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: '编辑',
                  onPressed: () {
                    // 打开编辑对话框
                    _showEditDialog(context, message);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
  // 复制内容到剪贴板
  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('复制成功')),
    );
  }
  // 显示编辑对话框
  void _showEditDialog(BuildContext context, ChatMessage message) {
    // 只允许编辑用户消息
    if (!message.isUser) return;
    
    final TextEditingController editController = TextEditingController(text: message.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: '编辑消息内容',
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty) {
                // 获取消息索引并更新
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                final messages = chatProvider.messages;
                final index = messages.indexOf(message);
                if (index != -1) {
                  chatProvider.editUserMessage(index, newContent);
                }
              }
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  // 构建侧边栏
  Widget _buildSidebar() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // 新建聊天按钮
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                chatProvider.createNewSession();
              },
              icon: const Icon(Icons.add),
              label: const Text('新建聊天'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          // 聊天会话列表
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final sessions = chatProvider.sessions;
                final currentSession = chatProvider.currentSession;
                
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isSelected = currentSession?.id == session.id;
                    
                    return ListTile(
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.blue[50],
                      leading: const Icon(Icons.chat_bubble_outline),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          Provider.of<ChatProvider>(context, listen: false)
                              .deleteSession(session.id);
                        },
                      ),
                      onTap: () {
                        Provider.of<ChatProvider>(context, listen: false)
                            .switchSession(session.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 自定义代码块构建器
class CustomCodeBlockBuilder extends MarkdownElementBuilder {
  final Function(String) copyToClipboard;
  final BuildContext context;

  CustomCodeBlockBuilder({
    required this.copyToClipboard,
    required this.context,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // 查找代码内容
    String codeContent = '';
    for (final child in element.children ?? []) {
      if (child is md.Element && child.tag == 'code') {
        codeContent = child.textContent;
        break;
      }
    }

    return Stack(
      children: [
        // 原始代码块
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 20), // 为复制按钮留出空间
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: SelectableText(
            codeContent,
            style: TextStyle(
              fontFamily: 'monospace',
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        // 复制按钮
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: '复制代码',
            onPressed: () => copyToClipboard(codeContent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 16,
            splashRadius: 16,
          ),
        ),
      ],
    );
  }
}