import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  /// 检查当前是否在web平台上运行
  static bool get isWeb => kIsWeb;

  /// 检查文件路径是否有效
  static bool isValidFilePath(String? path) {
    if (path == null || path.isEmpty) return false;
    
    // 在web平台上，文件路径可能是blob URL或data URL
    if (isWeb) {
      return path.startsWith('blob:') || path.startsWith('data:');
    }
    
    // 在其他平台上，检查文件是否存在
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }
}