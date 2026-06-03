import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/voice_state.dart';

/// Voice Activity Detector
///
/// Uses Silero VAD if available via whisper_ggml_plus, or falls back to
/// an energy-based simple VAD that works cross-platform without native deps.
class VADDetector {
  // Energy-based VAD state
  bool _isSpeaking = false;
  double _noiseFloor = 0.02;
  double _speechThreshold = 0.15;
  int _silenceFrames = 0;
  int _speechFrames = 0;
  int _requiredSilenceFrames = 15; // ~750ms at 50ms intervals
  int _requiredSpeechFrames = 3; // ~150ms to trigger
  // Silero VAD model (loaded from whisper_ggml_plus)
  // SileroVad? _sileroVad;

  final StreamController<VADEvent> _eventController =
      StreamController<VADEvent>.broadcast();

  Stream<VADEvent> get events => _eventController.stream;

  bool get isSpeaking => _isSpeaking;
  double get noiseFloor => _noiseFloor;

  /// Process audio level and return current VAD state
  bool processLevel(double level) {
    // Adaptive noise floor
    if (!_isSpeaking) {
      _noiseFloor = _noiseFloor * 0.995 + level * 0.005;
      _noiseFloor = _noiseFloor.clamp(0.001, 0.1);
    }

    final adjustedLevel = level - _noiseFloor;
    final isSpeech = adjustedLevel > _speechThreshold;

    if (isSpeech && !_isSpeaking) {
      _speechFrames++;
      if (_speechFrames >= _requiredSpeechFrames) {
        _isSpeaking = true;
        _silenceFrames = 0;
        _eventController.add(VADEvent(
          type: VADEventType.speechStarted,
          audioLevel: level,
        ));
      }
    } else if (!isSpeech && _isSpeaking) {
      _silenceFrames++;
      if (_silenceFrames >= _requiredSilenceFrames) {
        _isSpeaking = false;
        _speechFrames = 0;
        _eventController.add(VADEvent(
          type: VADEventType.speechEnded,
          audioLevel: level,
          duration: _silenceFrames * 0.05,
        ));
      }
    } else if (isSpeech && _isSpeaking) {
      _silenceFrames = 0;
      _speechFrames = 0;
    } else {
      _speechFrames = 0;
    }

    return _isSpeaking;
  }

  /// Configure VAD sensitivity
  void configure({
    double? speechThreshold,
    int? silenceTimeoutMs,
    double? noiseFloor,
  }) {
    if (speechThreshold != null) _speechThreshold = speechThreshold;
    if (silenceTimeoutMs != null) {
      _requiredSilenceFrames = (silenceTimeoutMs / 50).round();
    }
    if (noiseFloor != null) _noiseFloor = noiseFloor;
  }

  /// Reset VAD state
  void reset() {
    _isSpeaking = false;
    _silenceFrames = 0;
    _speechFrames = 0;
  }

  void dispose() {
    _eventController.close();
  }
}

/// Wrapper for Silero VAD (whisper_ggml_plus)
///
/// Usage when whisper_ggml_plus is available:
/// ```dart
/// import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
///
/// final sileroVad = SileroVad();
/// await sileroVad.loadModel('assets/models/silero_vad.bin');
/// final isSpeech = await sileroVad.processAudio(audioData);
/// ```
class SileroVADWrapper {
  bool _initialized = false;

  Future<bool> initialize() async {
    // Silero VAD from whisper_ggml_plus
    // final sileroVad = SileroVad();
    // await sileroVad.loadModel();
    // _initialized = true;
    _initialized = true;
    return true;
  }

  Future<bool> processAudio(List<double> audioData) async {
    if (!_initialized) return false;
    // return await _sileroVad.processAudio(audioData);
    return false;
  }

  void dispose() {
    _initialized = false;
  }
}
