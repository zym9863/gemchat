import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageGenerationService {
  static const String _baseUrl = 'https://pollinations.ai/p/';
  
  bool _isEnabled = false;
  
  // 默认参数
  static const int defaultWidth = 512;
  static const int defaultHeight = 512;
  static const String defaultModel = 'flux';
  
  // 检查图像生成功能是否启用
  bool isEnabled() {
    return _isEnabled;
  }
  
  // 切换图像生成功能的开关状态
  void toggleImageGeneration() {
    _isEnabled = !_isEnabled;
    _saveSettings();
  }
  
  // 保存设置到本地存储
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('image_generation_enabled', _isEnabled);
  }
  
  // 从本地存储加载设置
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('image_generation_enabled') ?? false;
  }
  
  // 生成图像
  Future<String> generateImage(String prompt, {int width = defaultWidth, int height = defaultHeight, int? seed}) async {
    if (!_isEnabled) {
      throw Exception('图像生成功能未启用');
    }
    
    // 随机种子，如果未提供
    final actualSeed = seed ?? DateTime.now().millisecondsSinceEpoch % 10000;
    
    // 构建API URL
    String imageUrlString;
    
    if (kIsWeb) {
      // Web平台使用代理URL或CORS友好的URL格式
      // 方法1：使用CORS代理服务（如果有）
      // imageUrlString = 'https://your-cors-proxy.com/$_baseUrl${Uri.encodeComponent(prompt)}?width=$width&height=$height&seed=$actualSeed&model=${defaultModel}&nologo=true';
      
      // 方法2：使用pollinations.ai的替代URL格式（如果支持）
      imageUrlString = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}?width=$width&height=$height&seed=$actualSeed&nologo=true';
    } else {
      // 非Web平台使用原始URL
      imageUrlString = '$_baseUrl${Uri.encodeComponent(prompt)}?width=$width&height=$height&seed=$actualSeed&model=${defaultModel}&nologo=true';
    }
    
    try {
      // 返回图像URL，Flutter可以直接使用这个URL加载图像
      return imageUrlString;
    } catch (e) {
      throw Exception('生成图像失败: $e');
    }
  }
}