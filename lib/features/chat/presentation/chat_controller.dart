import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/chat_message.dart';
import '../domain/chat_service.dart';
import '../data/ollama_client.dart';
import '../../../core/config/app_config.dart';
import '../../ha/domain/ha_entity.dart';
import '../../ha/presentation/ha_controller.dart';

/// Provider for chat controller
final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatUIState>((ref) {
  return ChatController(ref: ref);
});

/// Chat UI state
class ChatUIState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final bool isStreaming;

  const ChatUIState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isStreaming = false,
  });

  ChatUIState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool? isStreaming,
  }) {
    return ChatUIState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  HAEntity _findEntity(String domain) {
    return HAEntity(
      entityId: '$domain.default',
      state: '',
      lastChanged: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }
}

class ChatController extends StateNotifier<ChatUIState> {
  final Ref _ref;
  final OllamaClient _ollama = OllamaClient();
  StreamSubscription? _streamSub;

  ChatController({required Ref ref}) : _ref = ref, super(const ChatUIState()) {
    state = state.copyWith(messages: [
      ChatMessage.assistant('你好！我是你的智能家居助手。请问有什么可以帮助你的？'),
    ]);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage.user(text.trim());
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    final config = _ref.read(appConfigProvider);

    if (config.useCloudLLM) {
      await _processWithCloudLLM(text, config);
    } else {
      await _processWithLocalOllama(text, config);
    }
  }

  Future<void> _processWithLocalOllama(String text, AppConfigModel config) async {
    _ollama.host = config.ollamaHost;
    _ollama.model = config.ollamaModel;

    try {
      String? fullResponse;

      final stream = _ollama.sendMessage(
        message: text,
        history: state.messages.where((m) =>
          m.role == MessageRole.user || m.role == MessageRole.assistant
        ).toList(),
      );

      // Create initial assistant message
      final assistantMsg = ChatMessage.assistant('');
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        isStreaming: true,
      );

      await for (final chunk in stream) {
        fullResponse = (fullResponse ?? '') + chunk;
        final messages = List<ChatMessage>.from(state.messages);
        messages[messages.length - 1] = ChatMessage.assistant(fullResponse ?? '');
        state = state.copyWith(messages: messages, isStreaming: true);
      }

      await _processActions(fullResponse ?? '');
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _processWithCloudLLM(String text, AppConfigModel config) async {
    try {
      state = state.copyWith(isLoading: false, isStreaming: true);

      final assistantMsg = ChatMessage.assistant('');
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isStreaming: true,
      );

      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('${config.openAIBaseUrl}/chat/completions'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${config.openAIApiKey}');

      final messagesList = [
        {'role': 'system', 'content': OllamaClient.defaultSystemPrompt},
        ...state.messages
            .where((m) => m.role != MessageRole.system)
            .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            }),
      ];

      request.write(jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messagesList,
        'stream': true,
        'temperature': 0.7,
      }));

      final response = await request.close();
      String? fullResponse;

      await for (final chunk in response.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') break;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final content = json['choices']?[0]?['delta']?['content'] as String?;
              if (content != null) {
                fullResponse = (fullResponse ?? '') + content;
                final messages = List<ChatMessage>.from(state.messages);
                messages[messages.length - 1] = ChatMessage.assistant(fullResponse ?? '');
                state = state.copyWith(messages: messages);
              }
            } catch (_) {}
          }
        }
      }

      await _processActions(fullResponse ?? '');
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      state = state.copyWith(
        isStreaming: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _processActions(String response) async {
    final haController = _ref.read(haControllerProvider.notifier);
    if (response.contains('灯') || response.contains('光')) {
      if (response.contains('开') || response.contains('打开')) {
        // await haController.turnOn(state._findEntity('light'));
      } else if (response.contains('关') || response.contains('关闭')) {
        // await haController.turnOff(state._findEntity('light'));
      }
    }
  }

  void clearHistory() {
    state = state.copyWith(messages: [
      ChatMessage.assistant('你好！我是你的智能家居助手。请问有什么可以帮助你的？'),
    ]);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
