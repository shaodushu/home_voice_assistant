/// Voice processing state
enum ListeningState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// Voice processing result
class VoiceResult {
  final String text;
  final double confidence;
  final Duration duration;

  const VoiceResult({
    required this.text,
    this.confidence = 1.0,
    this.duration = Duration.zero,
  });
}

/// Voice processing configuration
class VoiceConfig {
  final bool vadEnabled;
  final double vadThreshold;
  final int silenceTimeoutMs;
  final int maxDurationSeconds;
  final String language;
  final bool useWakeWord;

  const VoiceConfig({
    this.vadEnabled = true,
    this.vadThreshold = 0.5,
    this.silenceTimeoutMs = 1500,
    this.maxDurationSeconds = 30,
    this.language = 'zh',
    this.useWakeWord = false,
  });
}

/// Audio level for visualization
class AudioLevel {
  final double level; // 0.0 - 1.0
  final DateTime timestamp;

  const AudioLevel({
    required this.level,
    required this.timestamp,
  });
}

/// VAD event types
enum VADEventType {
  speechStarted,
  speechEnded,
  silenceTimeout,
  noise,
}

/// VAD event model
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
