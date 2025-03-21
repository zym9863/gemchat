import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

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
}