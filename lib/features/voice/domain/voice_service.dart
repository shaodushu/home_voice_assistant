import 'dart:async';
import 'voice_state.dart';

/// Abstract voice service interface
abstract class VoiceService {
  /// Stream of audio levels for visualization
  Stream<AudioLevel> get audioLevelStream;

  /// Stream of VAD events
  Stream<VADEvent> get vadEventStream;

  /// Current listening state
  ListeningState get state;

  /// Start listening for voice input
  Future<void> startListening({
    VoiceConfig? config,
    VoidCallback? onSpeechStart,
    VoidCallback? onSpeechEnd,
    void Function(String text, double confidence)? onResult,
    void Function(String error)? onError,
  });

  /// Stop listening
  Future<String?> stopListening();

  /// Cancel current listening
  Future<void> cancelListening();

  /// Start wake word detection
  Future<void> startWakeWordDetection({
    void Function()? onWakeWord,
  });

  /// Stop wake word detection
  Future<void> stopWakeWordDetection();

  /// Clean up resources
  void dispose();
}

/// VAD (Voice Activity Detection) events
enum VADEventType {
  speechStarted,
  speechEnded,
  silenceTimeout,
  noise,
}

class VADEvent {
  final VADEventType type;
  final double audioLevel;
  final double? duration;

  const VADEvent({
    required this.type,
    required this.audioLevel,
    this.duration,
  });
}

typedef VoidCallback = void Function();
