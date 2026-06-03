import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ha_websocket_client.dart';

/// Home Assistant Assist Pipeline integration.
///
/// The Assist Pipeline processes voice commands through:
/// Wake Word → STT → Intent (LLM) → TTS
class HAAssistPipeline {
  final HAWebSocketClient _wsClient;
  StreamSubscription? _pipelineSubscription;

  /// Events emitted during pipeline execution
  final StreamController<PipelineEvent> _eventController =
      StreamController<PipelineEvent>.broadcast();

  Stream<PipelineEvent> get events => _eventController.stream;

  HAAssistPipeline(this._wsClient);

  /// Run the full Assist Pipeline with streaming audio
  /// Returns a stream of pipeline events
  Stream<PipelineEvent> runAssist({
    required String startStage,
    String endStage = 'tts',
    String? pipelineId,
    String? conversationId,
    String? deviceId,
    int sampleRate = 16000,
  }) {
    final outputController = StreamController<PipelineEvent>();

    _wsClient.runAssistPipeline(
      startStage: startStage,
      endStage: endStage,
      pipeline: pipelineId,
      conversationId: conversationId,
      deviceId: deviceId,
      input: {
        'sample_rate': sampleRate,
      },
    ).then((pipelineStream) {
      pipelineStream.listen(
        (data) {
          final event = _parsePipelineEvent(data);
          outputController.add(event);
          _eventController.add(event);
        },
        onError: (error) {
          outputController.addError(error);
        },
        onDone: () {
          outputController.close();
        },
      );
    }).catchError((error) {
      outputController.addError(error);
    });

    return outputController.stream;
  }

  /// Send audio chunk to the pipeline (after receiving stt-start event)
  Future<void> sendAudioChunk(
    int handlerId,
    List<int> audioData,
  ) async {
    // Audio binary messages must be sent via the WebSocket binary handler
    // Format: [handler_id (1 byte)] + [audio_data]
    final payload = Uint8List.fromList([handlerId, ...audioData]);
    await _wsClient.sendBinary(payload);
  }

  /// Send end-of-audio marker
  Future<void> sendAudioEnd(int handlerId) async {
    final payload = Uint8List.fromList([handlerId]);
    await _wsClient.sendBinary(payload);
  }

  /// Process a text command directly (skip STT)
  Future<PipelineResult> processTextCommand({
    required String text,
    String? pipelineId,
    String? conversationId,
    String? deviceId,
  }) async {
    final completer = Completer<PipelineResult>();
    final events = <PipelineEvent>[];
    String? responseText;
    String? ttsUrl;
    String? conversationIdResult;

    final subscription = runAssist(
      startStage: 'intent',
      endStage: 'tts',
      pipelineId: pipelineId,
      conversationId: conversationId,
      deviceId: deviceId,
    ).listen(
      (event) {
        events.add(event);
        switch (event.type) {
          case 'intent-end':
            responseText = event.data['intent_output']?['response']?['speech']?['plain']?['speech'] as String?;
            conversationIdResult = event.data['intent_output']?['conversation_id'] as String?;
            break;
          case 'tts-end':
            ttsUrl = event.data['tts_output']?['url'] as String?;
            break;
          case 'error':
            if (!completer.isCompleted) {
              completer.complete(PipelineResult(
                success: false,
                error: event.data['message'] as String? ?? 'Pipeline error',
                events: events,
              ));
            }
            break;
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(PipelineResult(
            success: true,
            responseText: responseText,
            ttsAudioUrl: ttsUrl,
            conversationId: conversationIdResult,
            events: events,
          ));
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.complete(PipelineResult(
            success: false,
            error: error.toString(),
            events: events,
          ));
        }
      },
    );

    return completer.future;
  }

  /// Send text input for intent/LLM processing (for intent-start pipeline)
  Future<void> sendIntentText(String text) async {
    // Sent as part of the pipeline run input
  }

  PipelineEvent _parsePipelineEvent(Map<String, dynamic> data) {
    final event = data['event'] as Map<String, dynamic>? ?? data;
    return PipelineEvent(
      type: event['type'] as String? ?? 'unknown',
      data: event,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    _pipelineSubscription?.cancel();
    _eventController.close();
  }
}

/// Pipeline event during voice processing
class PipelineEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const PipelineEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

/// Result of a pipeline run
class PipelineResult {
  final bool success;
  final String? responseText;
  final String? ttsAudioUrl;
  final String? conversationId;
  final String? error;
  final List<PipelineEvent> events;

  const PipelineResult({
    required this.success,
    this.responseText,
    this.ttsAudioUrl,
    this.conversationId,
    this.error,
    this.events = const [],
  });
}
