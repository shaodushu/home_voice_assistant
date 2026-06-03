import 'dart:async';
import 'chat_message.dart';

/// Abstract chat service for LLM interactions
abstract class ChatService {
  /// Send a message and get response (streaming)
  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
    String? systemPrompt,
  });

  /// Send a message and get single response
  Future<String> sendMessageSync({
    required String message,
    required List<ChatMessage> history,
    String? systemPrompt,
  });

  /// Get available models
  Future<List<String>> getAvailableModels();
}
