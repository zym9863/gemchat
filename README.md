# GemChat

中文 | [English](README_EN.md)

基于Flutter开发的Gemini AI聊天应用，提供简洁美观的界面和丰富的功能。

![GemChat应用图标](assets/image_fx_.jpg)

## 功能特点

- 🤖 集成Gemini AI模型，支持智能对话
- 💬 多会话管理，轻松切换不同的对话
- 🌓 支持亮色/暗色主题切换
- 🔄 多种Gemini模型可选
  - gemini-2.0-pro-exp-02-05
  - gemini-2.0-flash-thinking-exp-01-21
  - gemini-2.0-flash-001
- 📋 Markdown格式支持，美观展示AI回复
- 🔊 聊天音效，提供交互反馈
- 🖼️ 图片功能
  - 图片上传：支持图片识别和分析
  - 图片生成：基于Pollinations.AI，支持文本生成图像
- 🌐 联网搜索功能，通过Tavily API获取实时信息
- ✏️ 消息编辑和重新生成功能
- 🔄 流式响应，实时显示AI回复
- 🔑 API密钥管理，支持Gemini和Tavily双API配置

## 安装要求

- Flutter SDK ^3.7.0
- Dart SDK ^3.7.0
- Android/iOS/Web/Windows/macOS/Linux平台支持

## 开始使用

### 1. 获取代码

```bash
git clone https://github.com/zym9863/gemchat.git
cd gemchat
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行应用

```bash
flutter run
```

### 4. 设置API密钥

首次启动应用时，需要设置Gemini API密钥。您可以从Google AI Studio获取API密钥。

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
│   ├── chat_message.dart  # 聊天消息模型
│   └── chat_session.dart  # 聊天会话模型
├── providers/             # 状态管理
│   └── chat_provider.dart # 聊天状态提供者
├── screens/               # 界面
│   ├── api_key_screen.dart # API密钥设置界面
│   ├── chat_screen.dart   # 主聊天界面
│   └── platform_utils.dart # 平台工具类
├── services/              # 服务
│   ├── gemini_service.dart # Gemini API服务
│   ├── image_generation_service.dart # 图片生成服务
│   └── tavily_service.dart # Tavily搜索服务
├── theme/                 # 主题
│   └── app_theme.dart     # 应用主题设置
└── widgets/               # 自定义组件
    └── custom_image_builder.dart # 自定义图片构建器
```

## 主要依赖

- provider: ^6.1.2 - 状态管理
- http: ^1.3.0 - 网络请求
- shared_preferences: ^2.5.2 - 本地存储
- flutter_markdown: ^0.7.6+2 - Markdown渲染
- file_picker: ^9.0.2 - 文件选择

## 贡献指南

欢迎提交问题和功能请求！如果您想贡献代码，请遵循以下步骤：

1. Fork项目
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开Pull Request

## 许可证

[MIT License](LICENSE)
