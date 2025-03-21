import 'package:shared_preferences/shared_preferences.dart';

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
    final imageUrl = Uri.parse('$_baseUrl${Uri.encodeComponent(prompt)}?width=$width&height=$height&seed=$actualSeed&model=${defaultModel}&nologo=true');
    
    try {
      // 返回图像URL，Flutter可以直接使用这个URL加载图像
      return imageUrl.toString();
    } catch (e) {
      throw Exception('生成图像失败: $e');
    }
  }
}