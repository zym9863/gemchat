import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/gemini_service.dart';
import '../services/tavily_service.dart';
import '../services/image_generation_service.dart';

class ChatProvider extends ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final TavilyService _tavilyService = TavilyService();
  final ImageGenerationService _imageGenerationService = ImageGenerationService();
  final List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  String _errorMessage = '';
  String _streamingContent = '';
  bool _isCancelled = false;
  bool _isWebSearchEnabled = false; // 控制是否启用联网搜索
  bool _isImageGenerationEnabled = false; // 控制是否启用图像生成功能
  String _searchQuery = ''; // 搜索关键词

  List<String> get availableModels => GeminiService.availableModels;
  String get currentModel => _geminiService.getCurrentModel();

  void setCurrentModel(String model) {
    _geminiService.setCurrentModel(model);
    notifyListeners();
  }

  // 获取搜索关键词
  String get searchQuery => _searchQuery;
  
  // 设置搜索关键词
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  // 获取过滤后的会话列表
  List<ChatSession> get sessions {
    // 首先按置顶状态和更新时间排序会话列表（置顶的在最前，然后是按时间降序）
    final sortedSessions = List<ChatSession>.from(_sessions);
    sortedSessions.sort((a, b) {
      // 首先按置顶状态排序
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      // 然后按更新时间降序排序
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    if (_searchQuery.isEmpty) {
      return List.unmodifiable(sortedSessions);
    }
    
    // 根据搜索关键词过滤会话
    final filteredSessions = sortedSessions.where((session) {
      // 在会话标题中搜索
      if (session.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return true;
      }
      
      // 在会话消息内容中搜索
      for (final message in session.messages) {
        if (message is ChatMessage && 
            message.content.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return true;
        }
      }
      
      return false;
    }).toList();
    
    return List.unmodifiable(filteredSessions);
  }
  ChatSession? get currentSession => _currentSessionId != null 
      ? _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => _createNewSession('新对话'))
      : null;
  List<ChatMessage> get messages => currentSession?.messages.cast<ChatMessage>() ?? [];
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get streamingContent => _streamingContent;

  ChatProvider() {
    _loadSessions();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    await _imageGenerationService.loadSettings();
    notifyListeners();
  }
  
  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList('chat_sessions') ?? [];
    
    if (sessionsJson.isNotEmpty) {
      try {
        _sessions.clear();
        for (var sessionStr in sessionsJson) {
          final sessionMap = jsonDecode(sessionStr);
          _sessions.add(ChatSession.fromJson(sessionMap));
        }
        
        // 加载当前会话ID
        _currentSessionId = prefs.getString('current_session_id') ?? _sessions.first.id;
        notifyListeners();
      } catch (e) {
        print('加载会话数据失败: $e');
        _initDefaultSession();
      }
    } else {
      _initDefaultSession();
    }
  }
  
  void _initDefaultSession() {
    if (_sessions.isEmpty) {
      final newSession = _createNewSession('新对话');
      _sessions.add(newSession);
      _currentSessionId = newSession.id;
      notifyListeners();
    }
  }
  
  ChatSession _createNewSession(String title) {
    return ChatSession.create(title);
  }

  Future<bool> hasApiKey() async {
    return await _geminiService.hasApiKey();
  }

  Future<void> setApiKey(String apiKey) async {
    await _geminiService.setApiKey(apiKey);
    notifyListeners();
  }
  
  Future<bool> hasTavilyApiKey() async {
    return await _tavilyService.hasApiKey();
  }

  Future<void> setTavilyApiKey(String apiKey) async {
    await _tavilyService.setApiKey(apiKey);
    notifyListeners();
  }
  
  bool get isWebSearchEnabled => _isWebSearchEnabled;
  bool get isImageGenerationEnabled => _imageGenerationService.isEnabled();
  
  void toggleWebSearch() {
    _isWebSearchEnabled = !_isWebSearchEnabled;
    
    // 如果启用了网络搜索，则禁用图像生成功能
    if (_isWebSearchEnabled && _imageGenerationService.isEnabled()) {
      _imageGenerationService.toggleImageGeneration();
    }
    
    notifyListeners();
  }
  
  void toggleImageGeneration() {
    _imageGenerationService.toggleImageGeneration();
    
    // 如果启用了图像生成功能，则禁用网络搜索
    if (_imageGenerationService.isEnabled() && _isWebSearchEnabled) {
      _isWebSearchEnabled = false;
    }
    
    notifyListeners();
  }
  
  // 图像生成功能
  
  // 获取当前选择的尺寸选项
  String getCurrentImageSizeOption() {
    return _imageGenerationService.getCurrentSizeOption();
  }
  
  // 获取所有可用的尺寸选项
  List<String> getAvailableImageSizeOptions() {
    return _imageGenerationService.getAvailableSizeOptions();
  }
  
  // 设置当前尺寸选项
  void setCurrentImageSizeOption(String sizeOption) {
    _imageGenerationService.setCurrentSizeOption(sizeOption);
    notifyListeners();
  }
  
  // 生成图像
  Future<String> generateImage(String prompt) async {
    if (!isImageGenerationEnabled) {
      throw Exception('图像生成功能未启用');
    }
    return await _imageGenerationService.generateImage(prompt);
  }

  void createNewSession() {
    final newSession = _createNewSession('新对话');
    _sessions.add(newSession);
    _currentSessionId = newSession.id;
    _saveSessions();
    notifyListeners();
  }
  
  void switchSession(String sessionId) {
    if (_sessions.any((s) => s.id == sessionId)) {
      _currentSessionId = sessionId;
      _saveSessions();
      notifyListeners();
    }
  }
  
  void addUserMessage(String content, {String? mediaType, String? mediaPath}) {
    if (content.trim().isEmpty && mediaPath == null) return;
    if (currentSession == null) {
      createNewSession();
    }
    
    final message = ChatMessage.fromUser(content, mediaType: mediaType, mediaPath: mediaPath);
    final updatedMessages = [...currentSession!.messages, message];
    _updateCurrentSession(messages: updatedMessages);
    
    // 自动发送到API获取回复
    sendMessageToGemini(content, mediaType: mediaType, mediaPath: mediaPath);
  }
  
  // 添加带图片的用户消息
  void addUserMessageWithImage(String content, String imagePath) {
    addUserMessage(content, mediaType: 'image', mediaPath: imagePath);
  }
  
  // 添加AI生成的图像消息
  Future<void> addGeneratedImageMessage(String prompt) async {
    if (!isImageGenerationEnabled) {
      throw Exception('图像生成功能未启用');
    }
    
    if (currentSession == null) {
      createNewSession();
    }
    
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
      
      // 添加用户提示消息
      final userMessage = ChatMessage.fromUser('生成图像: $prompt');
      final updatedMessages = [...currentSession!.messages, userMessage];
      _updateCurrentSession(messages: updatedMessages);
      
      // 更新会话标题（如果是第一条消息）
      if (currentSession!.messages.length <= 1) {
        final title = prompt.length > 20 ? '${prompt.substring(0, 20)}...' : prompt;
        _updateCurrentSession(title: title);
      }
      
      // 创建一个临时的AI消息用于显示加载状态
      final tempAiMessage = ChatMessage.fromAI('正在生成图像...');
      final updatedMessagesWithTemp = [...updatedMessages, tempAiMessage];
      _updateCurrentSession(messages: updatedMessagesWithTemp);
      
      // 调用图像生成服务
      final imageUrl = await generateImage(prompt);
      
      // 创建包含图像URL的AI回复
      final aiMessage = ChatMessage.fromAI(
        '![]($imageUrl)\n\n这是根据你的描述"$prompt"生成的图像。'
      );
      
      // 更新消息列表，替换临时消息
      final messages = [...updatedMessages, aiMessage];
      _updateCurrentSession(messages: messages);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      
      // 如果生成失败，添加错误消息
      if (currentSession != null) {
        final messages = [...currentSession!.messages];
        final errorMessage = ChatMessage.fromAI('图像生成失败: ${e.toString()}');
        messages[messages.length - 1] = errorMessage;
        _updateCurrentSession(messages: messages);
      }
      
      notifyListeners();
    }
  }
  
  void _updateCurrentSession({List<dynamic>? messages, String? title}) {
    if (_currentSessionId == null) return;
    
    final index = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (index >= 0) {
      final updatedSession = _sessions[index].copyWith(
        messages: messages,
        title: title,
        updatedAt: DateTime.now(),
      );
      _sessions[index] = updatedSession;
      _saveSessions();
      notifyListeners();
    }
  }
  
  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = _sessions.map((session) => jsonEncode(session.toJson())).toList();
      await prefs.setStringList('chat_sessions', sessionsJson);
      
      // 保存当前会话ID
      if (_currentSessionId != null) {
        await prefs.setString('current_session_id', _currentSessionId!);
      }
    } catch (e) {
      print('保存会话数据失败: $e');
    }
  }

  // 取消当前正在进行的AI回复
  void cancelAIResponse() {
    if (_isLoading) {
      _isCancelled = true;
      _isLoading = false;
      
      // 如果已经有部分回复，保留它并标记为已取消
      if (_streamingContent.isNotEmpty && currentSession != null) {
        final messages = [...currentSession!.messages];
        final aiMessage = ChatMessage.fromAI('${_streamingContent}\n\n_[回复已终止]_');
        messages[messages.length - 1] = aiMessage;
        _updateCurrentSession(messages: messages);
      }
      
      _streamingContent = '';
      notifyListeners();
    }
  }

  Future<void> sendMessageToGemini(String content, {String? mediaType, String? mediaPath}) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _streamingContent = '';
      _isCancelled = false;
      notifyListeners();
      
      // 转换消息历史为API所需格式
      final history = _convertMessagesToHistory();
      
      // 创建一个临时的AI消息用于流式显示
      final tempAiMessage = ChatMessage.fromAI(_streamingContent);
      final updatedMessagesWithTemp = [...currentSession!.messages, tempAiMessage];
      _updateCurrentSession(messages: updatedMessagesWithTemp);
      
      // 处理图片（如果有）
      String? imageBase64;
      if (mediaType == 'image' && mediaPath != null) {
        try {
          // 检查是否是web平台上的base64图片数据
          if (mediaPath.startsWith('data:image/')) {
            // 从data URL中提取base64部分
            final base64String = mediaPath.split(',')[1];
            imageBase64 = base64String;
          } else {
            // 非web平台处理
            final file = await File(mediaPath).readAsBytes();
            imageBase64 = base64Encode(file);
          }
        } catch (e) {
          throw Exception('读取图片失败: $e');
        }
      }
      
      // 处理联网搜索
      String enhancedContent = content;
      if (_isWebSearchEnabled && mediaType != 'image') {
        try {
          // 更新临时消息，显示正在搜索
          _streamingContent = "正在进行联网搜索...";
          final updatedTempMessage = ChatMessage.fromAI(_streamingContent);
          final updatedMessages = [...currentSession!.messages];
          updatedMessages[updatedMessages.length - 1] = updatedTempMessage;
          _updateCurrentSession(messages: updatedMessages);
          
          // 调用Tavily API进行搜索
          final searchResult = await _tavilyService.search(content);
          
          // 构建增强的提示，包含搜索结果
          if (searchResult.containsKey('results') && searchResult['results'] is List) {
            final results = searchResult['results'] as List;
            if (results.isNotEmpty) {
              // 更新临时消息，显示搜索完成
              _streamingContent = "搜索完成，正在生成回复...";
              final updatedTempMessage = ChatMessage.fromAI(_streamingContent);
              final updatedMessages = [...currentSession!.messages];
              updatedMessages[updatedMessages.length - 1] = updatedTempMessage;
              _updateCurrentSession(messages: updatedMessages);
              
              // 构建包含搜索结果的增强提示
              enhancedContent = """用户问题: $content

以下是来自互联网的相关信息:
""";
              
              // 添加最多10个搜索结果
              final maxResults = results.length > 10 ? 10 : results.length;
              for (int i = 0; i < maxResults; i++) {
                final result = results[i];
                if (result.containsKey('content') && result.containsKey('url')) {
                  enhancedContent += """\n来源 ${i+1}: ${result['url']}
${result['content']}\n""";
                }
              }
              
              enhancedContent += """\n请根据以上信息回答用户的问题，如果信息不足，请基于你已有的知识回答。回答时不要逐条引用来源，而是综合所有信息给出流畅的回答。""";
            }
          }
        } catch (e) {
          print('联网搜索失败: $e');
          // 搜索失败时，使用原始内容继续
          _streamingContent = "联网搜索失败，使用离线模式回答...";
          final updatedTempMessage = ChatMessage.fromAI(_streamingContent);
          final updatedMessages = [...currentSession!.messages];
          updatedMessages[updatedMessages.length - 1] = updatedTempMessage;
          _updateCurrentSession(messages: updatedMessages);
        }
      }
      
      // 发送请求到API，使用流式回调
      final response = await _geminiService.sendMessage(
        enhancedContent, 
        history,
        imageBase64: imageBase64,
        onChunk: (chunk) {
          // 如果已取消，不再处理新的内容块
          if (_isCancelled) return;
          
          // 更新流式内容
          _streamingContent += chunk;
          
          // 更新临时消息的内容
          final updatedTempMessage = ChatMessage.fromAI(_streamingContent);
          final updatedMessages = [...currentSession!.messages];
          updatedMessages[updatedMessages.length - 1] = updatedTempMessage;
          _updateCurrentSession(messages: updatedMessages);
        }
      );
      
      // 如果在响应完成前已取消，则不更新最终消息
      if (_isCancelled) return;
      
      // 流式响应完成后，用完整响应替换临时消息
      final aiMessage = ChatMessage.fromAI(response);
      final messages = [...currentSession!.messages];
      messages[messages.length - 1] = aiMessage;
      _updateCurrentSession(messages: messages);
      
      // 更新会话标题（如果是第一条消息）
      if (currentSession!.messages.length <= 2) {
        final title = content.length > 20 ? '${content.substring(0, 20)}...' : content;
        _updateCurrentSession(title: title);
      }
      
      _isLoading = false;
      _streamingContent = '';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _streamingContent = '';
      notifyListeners();
    }
  }

  // 将消息历史转换为API所需的格式
  List<Map<String, dynamic>> _convertMessagesToHistory() {
    if (currentSession == null || currentSession!.messages.isEmpty) {
      return [];
    }
    
    // 只取最近的10条消息作为上下文
    final messages = currentSession!.messages.cast<ChatMessage>();
    final recentMessages = messages.length > 10 
        ? messages.sublist(messages.length - 10) 
        : messages;
    
    return recentMessages.map((msg) => {
      'role': msg.isUser ? 'user' : 'assistant',
      'content': msg.content
    }).toList();
  }

  void clearChat() {
    if (currentSession != null) {
      _updateCurrentSession(messages: []);
    }
    _errorMessage = '';
    notifyListeners();
  }
  
  // 编辑用户消息
  void editUserMessage(int messageIndex, String newContent) {
    if (currentSession == null || messageIndex < 0 || messageIndex >= currentSession!.messages.length) {
      return;
    }
    
    final messages = List<ChatMessage>.from(currentSession!.messages);
    final oldMessage = messages[messageIndex];
    
    // 确保只能编辑用户消息
    if (!oldMessage.isUser) return;
    
    // 替换用户消息
    messages[messageIndex] = ChatMessage.fromUser(newContent);
    
    // 移除该消息之后的所有消息（因为上下文已经改变）
    if (messageIndex < messages.length - 1) {
      messages.removeRange(messageIndex + 1, messages.length);
    }
    
    _updateCurrentSession(messages: messages);
    
    // 发送更新后的消息到API
    sendMessageToGemini(newContent);
  }
  
  // 重新生成AI回复
  void regenerateAIResponse(int messageIndex) {
    if (currentSession == null || messageIndex <= 0 || messageIndex >= currentSession!.messages.length) {
      return;
    }
    
    final messages = List<ChatMessage>.from(currentSession!.messages);
    final aiMessage = messages[messageIndex];
    
    // 确保只能重新生成AI消息
    if (aiMessage.isUser) return;
    
    // 获取前一条用户消息
    final userMessage = messages[messageIndex - 1];
    
    // 移除当前AI回复
    messages.removeAt(messageIndex);
    _updateCurrentSession(messages: messages);
    
    // 重新发送用户消息到API
    sendMessageToGemini(userMessage.content);
  }
  
  // 重命名会话标题
  void renameSession(String sessionId, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      final updatedSession = _sessions[index].copyWith(title: newTitle);
      _sessions[index] = updatedSession;
      _saveSessions();
      notifyListeners();
    }
  }
  
  // 切换会话的置顶状态
  void toggleSessionPin(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      final session = _sessions[index];
      final updatedSession = session.copyWith(isPinned: !session.isPinned);
      _sessions[index] = updatedSession;
      _saveSessions();
      notifyListeners();
    }
  }
  
  void deleteSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      _sessions.removeAt(index);
      
      // 如果删除的是当前会话，切换到其他会话或创建新会话
      if (_currentSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          _currentSessionId = _sessions.first.id;
        } else {
          createNewSession();
          return; // createNewSession已经调用了_saveSessions
        }
      }
      
      _saveSessions();
      notifyListeners();
    }
  }
}