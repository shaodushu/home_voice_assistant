import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../domain/voice_state.dart';
import '../domain/voice_service.dart';

/// Audio capture service using the `record` package.
/// Captures mic audio and provides level/VAD callbacks.
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription? _amplitudeSub;
  StreamController<AudioLevel>? _levelController;

  /// Start capturing audio with VAD
  Future<Stream<List<int>>> startCapture({
    required int sampleRate,
    required void Function(double level) onAudioLevel,
    required VoidCallback onSpeechStart,
    required VoidCallback onSpeechEnd,
  }) async {
    _levelController = StreamController<AudioLevel>.broadcast();

    // Check permissions
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('麦克风权限未授予');
    }

    // Configure audio session
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      numChannels: 1,
      sampleRate: sampleRate,
      autoGain: true,
      noiseSuppress: true,
    );

    // Start recording to stream
    final stream = await _recorder.startStream(config);

    _isRecording = true;

    // Monitor audio levels for VAD
    _amplitudeSub = Stream.periodic(
      const Duration(milliseconds: 50),
      (_) => null,
    ).listen((_) async {
      try {
        final amplitude = await _recorder.getAmplitude();
        // Convert to 0.0 - 1.0 range
        final level = min(1.0, amplitude.current / 160.0);
        _levelController?.add(AudioLevel(
          level: level,
          timestamp: DateTime.now(),
        ));
        onAudioLevel(level);
      } catch (_) {}
    });

    return stream;
  }

  /// Get audio level stream for visualization
  Stream<AudioLevel> get audioLevelStream =>
      _levelController?.stream ?? const Stream.empty();

  /// Stop capture
  Future<void> stopCapture() async {
    _isRecording = false;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _levelController?.close();
    _levelController = null;

    try {
      await _recorder.stop();
    } catch (_) {}
  }

  void dispose() {
    stopCapture();
    _recorder.dispose();
  }
}
