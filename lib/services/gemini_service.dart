import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _baseUrl = 'https://zym9863-gemini.deno.dev';
  static const String _apiEndpoint = '/v1/chat/completions';
  
  static const List<String> availableModels = [
    'gemini-2.5-pro-exp-03-25',
    'gemini-2.5-flash-preview-04-17',
  ];
  
  static const String defaultModel = 'gemini-2.5-pro-exp-03-25';
  
  String? _apiKey;
  String _currentModel = defaultModel;
  
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', apiKey);
  }
  
  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('gemini_api_key');
  }
  
  Future<String?> getApiKey() async {
    if (_apiKey == null) {
      await loadApiKey();
    }
    return _apiKey;
  }
  
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  String getCurrentModel() {
    return _currentModel;
  }

  void setCurrentModel(String model) {
    if (availableModels.contains(model)) {
      _currentModel = model;
    }
  }
  
  Future<String> sendMessage(String message, List<Map<String, dynamic>> history, {Function(String)? onChunk, String? imageBase64}) async {
    if (_apiKey == null) {
      throw Exception('API密钥未设置');
    }
    
    final url = Uri.parse('$_baseUrl$_apiEndpoint');
    
    // 构建用户消息内容
    dynamic userContent;
    
    if (imageBase64 != null) {
      // 如果有图片，构建包含图片的消息内容（符合OpenAI规范）
      userContent = [
        {"type": "text", "text": message},
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,$imageBase64"
          }
        }
      ];
    } else {
      // 纯文本消息
      userContent = message;
    }
    
    // 构建符合OpenAI规范的请求体
    final body = jsonEncode({
      'model': _currentModel,
      'messages': [
        ...history,
        {'role': 'user', 'content': userContent}
      ],
      'temperature': 1,
      'stream': true,
    });
    
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    });
    request.body = body;
    
    final response = await request.send();
    
    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('API请求失败: ${response.statusCode} $responseBody');
    }
    
    // 处理流式响应
    String fullContent = '';
    String buffer = '';
    
    await for (var chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      
      // 处理SSE格式数据
      while (buffer.contains('\n\n')) {
        final parts = buffer.split('\n\n');
        final eventData = parts[0];
        buffer = parts.sublist(1).join('\n\n');
        
        if (eventData.startsWith('data: ')) {
          final jsonData = eventData.substring(6).trim();
          
          // 处理流结束标记
          if (jsonData == '[DONE]') {
            continue;
          }
          
          try {
            final data = jsonDecode(jsonData);
            if (data['choices'] != null && data['choices'].isNotEmpty) {
              final delta = data['choices'][0]['delta'];
              if (delta != null && delta['content'] != null) {
                final content = delta['content'];
                fullContent += content;
                
                // 通知调用者新的内容块
                if (onChunk != null) {
                  onChunk(content);
                }
              }
            }
          } catch (e) {
            print('解析流式数据失败: $e, 数据: $jsonData');
          }
        }
      }
    }
    
    return fullContent;
  }
}