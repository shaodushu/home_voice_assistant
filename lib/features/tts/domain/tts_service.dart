import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tts_state.dart';

/// Provider for TTS service
final ttsServiceProvider = Provider<TTSService>((ref) {
  return PiperTTSService();
  // return PlatformTTSService(); // Alternative
});

/// Abstract TTS service interface
abstract class TTSService {
  /// Current TTS state
  TTSState get state;

  /// Stream of TTS state changes
  Stream<TTSState> get stateStream;

  /// Synthesize and speak text
  Future<void> speak(String text);

  /// Stop speaking
  Future<void> stop();

  /// Set voice parameters
  Future<void> setVoice({
    required String language,
    String? voice,
    double? speed,
    double? pitch,
  });

  /// Check if currently speaking
  bool get isSpeaking;

  /// Clean up
  void dispose();
}
