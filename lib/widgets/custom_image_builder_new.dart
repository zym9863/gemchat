import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../screens/platform_utils.dart';
import 'package:flutter/services.dart';

/// 自定义图像构建器，用于在Markdown中渲染图像
class CustomImageBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // 获取图像URL
    final String? imageUrl = element.attributes['src'];
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    // 获取alt文本作为图像描述
    final String alt = element.attributes['alt'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图像容器
        Stack(
          children: [
            Container(
              constraints: const BoxConstraints(
                maxWidth: 400, // 限制最大宽度
                maxHeight: 300, // 限制最大高度
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain, // 保持原始比例
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.red[100],
                      child: Text(
                        '图像加载失败: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 添加保存按钮
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Builder(
                  builder: (BuildContext context) => IconButton(
                    icon: const Icon(Icons.save_alt, color: Colors.white, size: 20),
                    tooltip: '保存图像',
                    onPressed: () => _saveImage(context, imageUrl),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ),
          ],
        ),
        // 如果有alt文本，显示为图像描述
        if (alt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              alt,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
  
  // 保存图像的方法
  Future<void> _saveImage(BuildContext context, String imageUrl) async {
    try {
      // 显示加载指示器
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        const SnackBar(content: Text('正在下载图像...')),
      );
      
      // 下载图像
      final response = await http.get(Uri.parse(imageUrl));
      final imageBytes = response.bodyBytes;
      
      if (PlatformUtils.isWeb) {
        // Web平台使用FilePicker保存
        _saveImageOnWeb(imageBytes, scaffold);
      } else if (Platform.isAndroid) {
        // Android平台保存到相册
        _saveImageToGalleryOnAndroid(imageBytes, scaffold);
      } else {
        // 其他平台使用文件选择器保存
        _saveImageWithFilePicker(imageBytes, scaffold);
      }
    } catch (e) {
      // 显示错误信息
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存图像失败: $e')),
      );
    }
  }
  
  // Web平台保存图像
  void _saveImageOnWeb(Uint8List imageBytes, ScaffoldMessengerState scaffold) {
    // Web平台无法直接保存文件，通常会触发浏览器下载
    // 这里可以使用第三方库如file_saver或universal_html实现
    // 由于Flutter Web的限制，这里只显示提示信息
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(content: Text('Web平台暂不支持直接保存，请右键图像选择"另存为"')),
    );
  }
  
  // 使用FilePicker保存图像
  Future<void> _saveImageWithFilePicker(Uint8List imageBytes, ScaffoldMessengerState scaffold) async {
    try {
      // 使用FilePicker选择保存位置
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '保存图像',
        fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      
      if (outputFile != null) {
        // 保存文件
        final file = File(outputFile);
        await file.writeAsBytes(imageBytes);
        
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(content: Text('图像已保存到: $outputFile')),
        );
      } else {
        // 用户取消了保存操作
        scaffold.hideCurrentSnackBar();
      }
    } catch (e) {
      _showErrorMessage(scaffold, '保存失败: $e');
    }
  }
  
  // Android平台保存图像到相册
  Future<void> _saveImageToGalleryOnAndroid(Uint8List imageBytes, ScaffoldMessengerState scaffold) async {
    try {
      // 获取临时目录路径
      final tempDir = await getTemporaryDirectory();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      
      // 保存到临时文件
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      // 使用平台通道保存到相册
      const platform = MethodChannel('com.example.gemchat/gallery');
      try {
        // 调用原生方法保存图片到相册
        final result = await platform.invokeMethod('saveImageToGallery', {
          'filePath': filePath,
          'fileName': fileName,
        });
        
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(content: Text('图像已保存到相册')),
        );
      } on PlatformException catch (e) {
        // 如果平台通道不可用，尝试使用FilePicker作为备选方案
        _saveImageWithFilePicker(imageBytes, scaffold);
      }
    } catch (e) {
      _showErrorMessage(scaffold, '保存到相册失败: $e');
    }
  }
  
  // 显示错误信息
  void _showErrorMessage(ScaffoldMessengerState scaffold, String message) {
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}