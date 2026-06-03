import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/voice_state.dart';
import '../domain/voice_service.dart';

/// Speech recognizer wrapper
///
/// Supports:
/// 1. whisper_ggml_plus - On-device Whisper.cpp
/// 2. Home Assistant Assist Pipeline - STT via HA
/// 3. Web API fallback (Whisper API / Ollama)
class SpeechRecognizer {
  RecognizerBackend _backend = RecognizerBackend.haPipeline;

  /// Use HA Assist Pipeline for STT
  Future<String?> transcribeViaHAPipeline({
    required Stream<List<int>> audioStream,
    required int sampleRate,
  }) async {
    // HA Assist pipeline handles STT server-side
    // Audio is sent via assist_pipeline/run WebSocket command
    debugPrint('HA Pipeline STT: streaming $sampleRate Hz audio');
    return null; // Transcibed through pipeline events
  }

  /// Use whisper_ggml_plus for on-device STT
  Future<VoiceResult?> transcribeOnDevice({
    required String audioPath,
    String language = 'zh',
  }) async {
    try {
      // When whisper_ggml_plus is available:
      // final whisper = Whisper();
      // await whisper.loadModel('assets/models/ggml-tiny.bin');
      // final result = await whisper.transcribe(
      //   audioPath,
      //   language: language,
      //   vadMode: WhisperVadMode.auto,
      // );
      // return VoiceResult(text: result.text, confidence: result.confidence);

      debugPrint('On-device STT: would transcribe $audioPath');
      return null;
    } catch (e) {
      debugPrint('On-device STT failed: $e');
      return null;
    }
  }

  /// Use Ollama's vision/audio model for transcription
  Future<VoiceResult?> transcribeViaOllama({
    required String audioPath,
    String ollamaHost = 'http://localhost:11434',
    String model = 'qwen2.5:3b',
  }) async {
    try {
      // Read audio file as base64
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) return null;

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$ollamaHost/api/generate'));
      request.headers.set('Content-Type', 'application/json');

      request.write(jsonEncode({
        'model': model,
        'prompt': '请将以下语音内容转录为文字。只返回转录的文字:',
        'images': [base64Audio],
        'stream': false,
      }));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      final text = data['response'] as String?;
      if (text != null && text.isNotEmpty) {
        return VoiceResult(text: text.trim());
      }
    } catch (e) {
      debugPrint('Ollama STT failed: $e');
    }
    return null;
  }

  void setBackend(RecognizerBackend backend) {
    _backend = backend;
  }
}

enum RecognizerBackend {
  haPipeline,
  onDevice,
  ollama,
}
