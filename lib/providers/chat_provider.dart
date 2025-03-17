import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/gemini_service.dart';

class ChatProvider extends ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  String _errorMessage = '';
  String _streamingContent = '';
  bool _isCancelled = false;

  List<String> get availableModels => GeminiService.availableModels;
  String get currentModel => _geminiService.getCurrentModel();

  void setCurrentModel(String model) {
    _geminiService.setCurrentModel(model);
    notifyListeners();
  }

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get currentSession => _currentSessionId != null 
      ? _sessions.firstWhere((s) => s.id == _currentSessionId, orElse: () => _createNewSession('新对话'))
      : null;
  List<ChatMessage> get messages => currentSession?.messages.cast<ChatMessage>() ?? [];
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get streamingContent => _streamingContent;

  ChatProvider() {
    _loadSessions();
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
  
  void addUserMessage(String content) {
    if (content.trim().isEmpty) return;
    if (currentSession == null) {
      createNewSession();
    }
    
    final message = ChatMessage.fromUser(content);
    final updatedMessages = [...currentSession!.messages, message];
    _updateCurrentSession(messages: updatedMessages);
    
    // 自动发送到API获取回复
    sendMessageToGemini(content);
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

  Future<void> sendMessageToGemini(String content) async {
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
      
      // 发送请求到API，使用流式回调
      final response = await _geminiService.sendMessage(
        content, 
        history,
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