import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/tts_service.dart';
import '../domain/tts_state.dart';

/// Piper TTS - Local neural TTS engine
///
/// Piper runs locally with very low latency.
/// Can be run as a subprocess or connected via HTTP API.
class PiperTTSService implements TTSService {
  TTSState _state = const TTSState();
  final StreamController<TTSState> _stateController =
      StreamController<TTSState>.broadcast();

  // Piper can be invoked as a local HTTP server or subprocess
  String _piperUrl = 'http://localhost:5000';
  Process? _piperProcess;

  @override
  TTSState get state => _state;

  @override
  Stream<TTSState> get stateStream => _stateController.stream;

  @override
  bool get isSpeaking => _state.isSpeaking;

  /// Initialize with Piper URL
  void configure({String? piperUrl}) {
    if (piperUrl != null) _piperUrl = piperUrl;
  }

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    _updateState(TTSState(
      playbackState: TTSPlaybackState.speaking,
      currentText: text,
    ));

    try {
      // Option 1: HTTP API (piper as server)
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$_piperUrl/synthesize'));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'text': text,
        'voice': 'zh_CN-hf_female-medium', // Chinese voice model
      }));

      final response = await request.close();
      final audioBytes = await response.fold<List<int>>(
        [],
        (prev, chunk) => [...prev, ...chunk],
      );

      if (audioBytes.isNotEmpty) {
        // Save to temp file and play
        final tempFile = File(
          '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav',
        );
        await tempFile.writeAsBytes(audioBytes);
        await _playAudioFile(tempFile.path);
      }

      _updateState(const TTSState(playbackState: TTSPlaybackState.idle));
    } catch (e) {
      debugPrint('Piper TTS failed: $e');
      _updateState(TTSState(
        playbackState: TTSPlaybackState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> stop() async {
    // Stop audio playback
    _updateState(const TTSState(playbackState: TTSPlaybackState.idle));
  }

  @override
  Future<void> setVoice({
    required String language,
    String? voice,
    double? speed,
    double? pitch,
  }) async {
    // Configure voice parameters
    debugPrint('Piper TTS: set voice lang=$language voice=$voice');
  }

  Future<void> _playAudioFile(String path) async {
    // Use audioplayers or just_audio to playback
    // final player = AudioPlayer();
    // await player.setSourceDeviceFile(path);
    // await player.play();
    debugPrint('Playing audio: $path');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _updateState(TTSState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Start Piper as a subprocess
  Future<void> startPiperProcess({
    String piperPath = '/usr/local/bin/piper',
    String modelPath = 'models/zh_CN-hf_female-medium.onnx',
  }) async {
    try {
      _piperProcess = await Process.start(piperPath, [
        '--model', modelPath,
        '--output-raw',
        '--json-input',
      ]);
      debugPrint('Piper process started');
    } catch (e) {
      debugPrint('Failed to start Piper: $e');
    }
  }

  @override
  void dispose() {
    _piperProcess?.kill();
    _stateController.close();
  }
}
