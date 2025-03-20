import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _geminiApiKeyController = TextEditingController();
  final TextEditingController _tavilyApiKeyController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    // 使用公开方法获取API密钥
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final hasGeminiKey = await chatProvider.hasApiKey();
    final hasTavilyKey = await chatProvider.hasTavilyApiKey();
    
    if (hasGeminiKey || hasTavilyKey) {
      // 如果有API密钥，我们可以通过服务获取它
      // 这里不能直接访问私有成员_geminiService和_tavilyService
      // 暂时不显示API密钥，因为我们没有提供获取API密钥的公开方法
    }
  }

  Future<void> _saveGeminiApiKey() async {
    final apiKey = _geminiApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'Gemini API密钥不能为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.setApiKey(apiKey);
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gemini API密钥已保存')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveTavilyApiKey() async {
    final apiKey = _tavilyApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'Tavily API密钥不能为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.setTavilyApiKey(apiKey);
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tavily API密钥已保存')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _tavilyApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置API密钥'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gemini API密钥设置
              const Text(
                '请输入您的Gemini API密钥',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _geminiApiKeyController,
                decoration: const InputDecoration(
                  hintText: '输入Gemini API密钥',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveGeminiApiKey,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存Gemini API密钥'),
              ),
              const SizedBox(height: 8),
              const Text(
                '您可以从Google AI Studio获取Gemini API密钥:\nhttps://aistudio.google.com/',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              
              const Divider(height: 40),
              
              // Tavily API密钥设置
              const Text(
                '请输入您的Tavily API密钥（用于联网搜索）',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tavilyApiKeyController,
                decoration: const InputDecoration(
                  hintText: '输入Tavily API密钥',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTavilyApiKey,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存Tavily API密钥'),
              ),
              const SizedBox(height: 8),
              const Text(
                '您可以从Tavily官网获取API密钥:\nhttps://tavily.com/',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}