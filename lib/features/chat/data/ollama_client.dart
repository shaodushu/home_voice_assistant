import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/chat_service.dart';
import '../domain/chat_message.dart';

/// Ollama API client for local LLM inference
class OllamaClient implements ChatService {
  String _host;
  String _model;

  OllamaClient({
    String host = 'http://localhost:11434',
    String model = 'qwen2.5:3b',
  })  : _host = host,
        _model = model;

  set host(String h) => _host = h;
  set model(String m) => _model = m;
  String get model => _model;

  /// System prompt for home assistant tasks
  static const String defaultSystemPrompt = '''
你是一个智能家居语音助手，可以通过 Home Assistant 控制各种智能设备。
你可以：
1. 控制灯光（开/关、调亮度、调颜色）
2. 控制空调/暖气（开关、调温度、调模式）
3. 控制窗帘（开/关、停在某个位置）
4. 查询传感器状态（温度、湿度、门锁等）
5. 执行场景

请用中文回复，简洁明了。对于设备操作，请直接说明你执行了什么操作。
''';

  @override
  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    String? systemPrompt,
  }) async* {
    try {
      final messages = _buildMessages(message, history, systemPrompt);

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$_host/api/chat'));
      request.headers.set('Content-Type', 'application/json');

      // Stream: true for token-by-token streaming
      request.write(jsonEncode({
        'model': _model,
        'messages': messages,
        'stream': true,
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
        },
      }));

      final response = await request.close();

      await for (final chunk in response.transform(utf8.decoder)) {
        try {
          final line = jsonDecode(chunk) as Map<String, dynamic>;
          if (line['done'] == true) break;

          final content = line['message']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // Skip malformed JSON lines
        }
      }
    } catch (e) {
      debugPrint('Ollama error: $e');
      yield '抱歉，与语言模型通信时出错: $e';
    }
  }

  @override
  Future<String> sendMessageSync({
    required String message,
    required List<ChatMessage> history,
    String? systemPrompt,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessage(
      message: message,
      history: history,
      systemPrompt: systemPrompt,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  @override
  Future<List<String>> getAvailableModels() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_host/api/tags'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final models = data['models'] as List? ?? [];
      return models
          .map((m) => (m as Map<String, dynamic>)['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to get models: $e');
      return ['qwen2.5:3b', 'llama3.2:3b']; // Default fallback
    }
  }

  List<Map<String, dynamic>> _buildMessages(
    String message,
    List<ChatMessage> history,
    String? systemPrompt,
  ) {
    final messages = <Map<String, dynamic>>[];

    // System prompt
    messages.add({
      'role': 'system',
      'content': systemPrompt ?? defaultSystemPrompt,
    });

    // History
    for (final msg in history) {
      messages.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    // Current message
    messages.add({
      'role': 'user',
      'content': message,
    });

    return messages;
  }
}
