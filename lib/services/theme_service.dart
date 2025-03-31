import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'is_dark_mode';
  static const String _fontSizeKey = 'font_size';

  // 保存主题模式
  static Future<bool> saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_themeKey, isDarkMode);
  }

  // 获取保存的主题模式
  static Future<bool> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false; // 默认为浅色模式
  }
  
  // 保存字体大小
  static Future<bool> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setDouble(_fontSizeKey, fontSize);
  }
  
  // 获取保存的字体大小
  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 16.0; // 默认字体大小为16
  }
}