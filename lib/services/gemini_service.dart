import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _baseUrl = 'https://zym9863-gemini.deno.dev';
  static const String _apiEndpoint = '/v1/chat/completions';
  
  static const List<String> availableModels = [
    'gemini-2.0-pro-exp-02-05',
    'gemini-2.0-flash-thinking-exp-01-21',
    'gemini-2.0-flash-001'
  ];
  
  static const String defaultModel = 'gemini-2.0-flash-thinking-exp-01-21';
  
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
  
  Future<String> sendMessage(String message, List<Map<String, dynamic>> history) async {
    if (_apiKey == null) {
      throw Exception('API密钥未设置');
    }
    
    final url = Uri.parse('$_baseUrl$_apiEndpoint');
    
    // 构建符合OpenAI规范的请求体
    final body = jsonEncode({
      'model': _currentModel,
      'messages': [
        ...history,
        {'role': 'user', 'content': message}
      ],
      'temperature': 0.7,
    });
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('API响应格式错误');
      }
    } else {
      throw Exception('API请求失败: ${response.statusCode} ${response.body}');
    }
  }
}