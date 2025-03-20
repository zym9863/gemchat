import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TavilyService {
  static const String _baseUrl = 'https://api.tavily.com';
  static const String _searchEndpoint = '/search';
  
  String? _apiKey;
  
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tavily_api_key', apiKey);
  }
  
  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('tavily_api_key');
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
  
  Future<Map<String, dynamic>> search(String query) async {
    if (_apiKey == null) {
      throw Exception('Tavily API密钥未设置');
    }
    
    final url = Uri.parse('$_baseUrl$_searchEndpoint');
    
    final body = jsonEncode({
      'query': query,
      'include_answer': true,
      'include_domains': [],
      'include_raw_content': false,
    });
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Tavily API请求失败: ${response.statusCode} ${response.body}');
    }
    
    return jsonDecode(response.body);
  }
}