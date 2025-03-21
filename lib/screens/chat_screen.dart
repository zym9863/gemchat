import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../widgets/custom_image_builder.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'api_key_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'platform_utils.dart';
// 移除不存在的导入,使用自定义深色主题
final githubDarkTheme = {
  'root': TextStyle(
    backgroundColor: Color(0xFF0d1117),
    color: Color(0xFFc9d1d9),
  ),
  'keyword': TextStyle(color: Color(0xFFff7b72)),
  'string': TextStyle(color: Color(0xFFa5d6ff)),
  'comment': TextStyle(color: Color(0xFF8b949e)),
  'number': TextStyle(color: Color(0xFFd2a8ff)),
  'literal': TextStyle(color: Color(0xFFd2a8ff)),
  'tag': TextStyle(color: Color(0xFF7ee787)),
  'attr-name': TextStyle(color: Color(0xFF79c0ff)),
  'attr-value': TextStyle(color: Color(0xFFa5d6ff)),
  'punctuation': TextStyle(color: Color(0xFFc9d1d9)),
};

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _imagePromptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSidebarExpanded = true; // 控制侧边栏是否展开
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _soundEffectPath = 'sound-effect-1742042141417.mp3';
  String? _selectedImagePath; // 存储选择的图片路径
  Uint8List? _webImageData; // 存储web平台的图片数据
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
  // 播放音效
  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource(_soundEffectPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    // 如果没有文本且没有图片，则不发送
    if (message.isEmpty && _selectedImagePath == null) return;
    
    _playSound(); // 发送消息时播放音效
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 检查是否是图像生成模式
    if (chatProvider.isImageGenerationEnabled && _selectedImagePath == null) {
      // 调用ChatProvider中的方法生成图像
      chatProvider.addGeneratedImageMessage(message);
    } else if (_selectedImagePath != null) {
      // 如果有图片，则发送带图片的消息
      // 处理web平台的图片数据
      if (PlatformUtils.isWeb && _webImageData != null && _selectedImagePath!.startsWith('web_image:')) {
        // 将web平台的图片数据转换为base64格式
        final base64Image = base64Encode(_webImageData!);
        // 创建一个特殊的路径格式，包含base64数据
        final base64Path = 'data:image/jpeg;base64,$base64Image';
        chatProvider.addUserMessageWithImage(message, base64Path);
      } else {
        // 非web平台处理
        chatProvider.addUserMessageWithImage(message, _selectedImagePath!);
      }
      
      // 发送后清除已选择的图片
      setState(() {
        _selectedImagePath = null;
        _webImageData = null; // 清除web平台的图片数据
      });
    } else {
      // 发送纯文本消息
      chatProvider.addUserMessage(message);
    }
    
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
    _imagePromptController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  // 切换侧边栏展开/折叠状态
  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }
  
  // 生成图像
  void _generateImage() {
    final prompt = _imagePromptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入图像描述')),
      );
      return;
    }
    
    _playSound(); // 播放音效
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // 调用ChatProvider中的方法生成图像
    chatProvider.addGeneratedImageMessage(prompt);
    
    // 清空输入框
    _imagePromptController.clear();
    
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
                    // 如果是最后一条AI消息且正在加载中，显示流式内容
                    if (!message.isUser && 
                        index == messages.length - 1 && 
                        chatProvider.isLoading) {
                      return _buildMessageItem(message, isStreaming: true);
                    }
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('终止回复'),
                        onPressed: () {
                          chatProvider.cancelAIResponse();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
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
                // 图片上传按钮
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                      withData: PlatformUtils.isWeb, // 在web平台上获取文件数据
                    );
                    
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      String? path = file.path;
                      
                      // 在web平台上处理文件
                      if (PlatformUtils.isWeb) {
                        if (file.bytes != null) {
                          // 在web平台上，使用文件名作为标识
                          path = 'web_image:${file.name}';
                          // 可以在这里处理文件数据，例如转换为base64或其他格式
                          setState(() {
                            _selectedImagePath = path;
                            _webImageData = file.bytes; // 存储web平台的图片数据
                          });
                        }
                      } else if (path != null) {
                        // 非web平台处理
                        setState(() {
                          _selectedImagePath = path;
                        });
                      }
                      
                      if (path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('图片已选择')),
                        );
                      }
                    }
                  },
                  tooltip: '上传图片',
                ),
                // 显示已选择的图片预览
                if (_selectedImagePath != null)
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: PlatformUtils.isWeb && _webImageData != null
                                ? MemoryImage(_webImageData!) // 使用内存中的图片数据
                                : FileImage(File(_selectedImagePath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedImagePath = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      children: [
                        // 功能开关区域 - 重新设计
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 联网搜索开关
                              Consumer<ChatProvider>(
                                builder: (context, chatProvider, child) {
                                  return Row(
                                    children: [
                                      Switch(
                                        value: chatProvider.isWebSearchEnabled,
                                        onChanged: (value) async {
                                          if (value) {
                                            // 检查是否设置了Tavily API密钥
                                            final hasTavilyKey = await chatProvider.hasTavilyApiKey();
                                            if (!hasTavilyKey) {
                                              // 如果未设置API密钥，导航到API密钥设置界面
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('请先设置Tavily API密钥')),
                                              );
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => const ApiKeyScreen(),
                                                ),
                                              );
                                              return;
                                            }
                                          }
                                          chatProvider.toggleWebSearch();
                                        },
                                        activeColor: Colors.blue,
                                      ),
                                      Text(
                                        '联网搜索',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(width: 4),
                                      Tooltip(
                                        message: '启用联网搜索功能，需要设置Tavily API密钥',
                                        child: Icon(Icons.info_outline, size: 16),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              
                              // 图像生成开关
                              Consumer<ChatProvider>(
                                builder: (context, chatProvider, child) {
                                  return Row(
                                    children: [
                                      Switch(
                                        value: chatProvider.isImageGenerationEnabled,
                                        onChanged: (value) {
                                          chatProvider.toggleImageGeneration();
                                        },
                                        activeColor: Colors.blue,
                                      ),
                                      Text(
                                        '图像生成',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(width: 4),
                                      Tooltip(
                                        message: '启用AI图像生成功能',
                                        child: Icon(Icons.info_outline, size: 16),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            child: RawKeyboardListener(
                              focusNode: FocusNode(),
                              onKey: (RawKeyEvent event) {
                                if (event is RawKeyDownEvent &&
                                    event.isControlPressed &&
                                    event.logicalKey == LogicalKeyboardKey.enter) {
                                  _sendMessage();
                                  return;
                                }
                              },
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: Provider.of<ChatProvider>(context).isImageGenerationEnabled
                                      ? '输入图像描述...'
                                      : '输入消息...',
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
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      return Icon(
                        chatProvider.isImageGenerationEnabled
                            ? Icons.auto_awesome  // 图像生成模式使用不同图标
                            : Icons.send
                      );
                    },
                  ),
                  onPressed: _messageController.text.trim().isEmpty ? null : _sendMessage,
                  tooltip: Provider.of<ChatProvider>(context).isImageGenerationEnabled
                      ? '生成图像'
                      : '发送消息',
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
  Widget _buildMessageItem(ChatMessage message, {bool isStreaming = false}) {
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
                  // 显示图片（如果有）
                  if (message.isUser && message.mediaType == 'image' && message.mediaPath != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      constraints: BoxConstraints(
                        maxHeight: 200,
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlatformUtils.isWeb && message.mediaPath!.startsWith('data:image/')
                          ? Image.network(
                              message.mediaPath!,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(message.mediaPath!),
                              fit: BoxFit.contain,
                            ),
                      ),
                    ),
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
                      : isStreaming
                          // 流式响应时使用普通Text避免Markdown解析错误
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
                                // 限制图像最大宽度和高度
                                img: TextStyle(fontSize: 0), // 使用fontSize: 0避免图像下方出现空白
                              ),
                              builders: {
                                'pre': CustomCodeBlockBuilder(
                                  copyToClipboard: _copyToClipboard,
                                  context: context,
                                ),
                                // 添加自定义图像构建器
                                'img': CustomImageBuilder(),
                                
                              },
                            ),
                  // 显示打字指示器和终止按钮（仅在流式响应时显示）
                  if (!message.isUser && isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 8),
                              SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.stop_circle_outlined, size: 16),
                            label: Text('终止', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Provider.of<ChatProvider>(context, listen: false).cancelAIResponse();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red[400],
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
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
                  // 用户消息底部的按钮（仅在用户消息时显示）
                  if (message.isUser)
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
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            tooltip: '编辑',
                            onPressed: () {
                              // 显示编辑对话框
                              _showEditDialog(context, message);
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
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100],
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
    // 查找代码内容和语言
    String codeContent = '';
    String? language;
    
    for (final child in element.children ?? []) {
      if (child is md.Element && child.tag == 'code') {
        codeContent = child.textContent;
        // 尝试从class属性中获取语言
        final classAttr = child.attributes['class'];
        if (classAttr != null && classAttr.startsWith('language-')) {
          language = classAttr.substring('language-'.length);
        }
        break;
      }
    }

    // 检测代码语言（如果未指定）
    language = language ?? _detectLanguage(codeContent);

    return Stack(
      children: [
        // 代码块（带语法高亮）
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 语言标签
              if (language != null && language.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    language,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ),
              // 高亮代码
              HighlightView(
                codeContent,
                language: language ?? 'plaintext',
                theme: Theme.of(context).brightness == Brightness.dark
                    ? githubDarkTheme
                    : githubTheme,
                padding: EdgeInsets.zero,
                textStyle: TextStyle(fontFamily: 'monospace'),
              ),
            ],
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
  
  // 根据代码内容自动检测语言
  String? _detectLanguage(String code) {
    // 简单的语言检测逻辑
    if (code.contains('class') && code.contains('extends') && 
        (code.contains('{') && code.contains('}'))) {
      if (code.contains('import React') || code.contains('export default') || 
          code.contains('const') || code.contains('let')) {
        return 'javascript';
      } else if (code.contains('func') || code.contains('package main')) {
        return 'go';
      } else if (code.contains('public static void main')) {
        return 'java';
      } else if (code.contains('def ') || code.contains('import ') && !code.contains(';')) {
        return 'python';
      } else if (code.contains('using namespace') || code.contains('#include')) {
        return 'cpp';
      } else {
        return 'dart'; // 默认为dart，因为这是Flutter应用
      }
    } else if (code.contains('<html>') || code.contains('<!DOCTYPE html>')) {
      return 'html';
    } else if (code.contains('function') || code.contains('const ') || 
              code.contains('let ') || code.contains('var ')) {
      return 'javascript';
    } else if (code.contains('import ') && !code.contains(';') && 
              (code.contains('def ') || code.contains('print('))) {
      return 'python';
    } else if (code.contains('<?php')) {
      return 'php';
    } else if (code.contains('#include') || code.contains('int main()')) {
      return 'cpp';
    } else if (code.contains('package ') && code.contains('import ') && 
              code.contains(';')) {
      return 'java';
    } else if (code.contains('func ') && code.contains('package ')) {
      return 'go';
    } else if (code.contains('void main()') || code.contains('Widget build')) {
      return 'dart';
    }
    
    return 'plaintext';
  }
}