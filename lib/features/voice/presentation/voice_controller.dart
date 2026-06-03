import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/voice_state.dart';
import '../domain/voice_service.dart';
import '../data/audio_capture_service.dart';
import '../data/vad_detector.dart';
import '../data/speech_recognizer.dart';
import '../../ha/presentation/ha_controller.dart';
import '../../tts/domain/tts_service.dart';

/// Provider for voice controller
final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceUIState>((ref) {
  return VoiceController(ref: ref);
});

/// UI state for voice interaction
class VoiceUIState {
  final ListeningState listeningState;
  final double audioLevel;
  final String? lastTranscript;
  final String? lastResponse;
  final String? errorMessage;
  final List<AudioLevel> recentLevels;

  const VoiceUIState({
    this.listeningState = ListeningState.idle,
    this.audioLevel = 0.0,
    this.lastTranscript,
    this.lastResponse,
    this.errorMessage,
    this.recentLevels = const [],
  });

  VoiceUIState copyWith({
    ListeningState? listeningState,
    double? audioLevel,
    String? lastTranscript,
    String? lastResponse,
    String? errorMessage,
    List<AudioLevel>? recentLevels,
  }) {
    return VoiceUIState(
      listeningState: listeningState ?? this.listeningState,
      audioLevel: audioLevel ?? this.audioLevel,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastResponse: lastResponse ?? this.lastResponse,
      errorMessage: errorMessage ?? this.errorMessage,
      recentLevels: recentLevels ?? this.recentLevels,
    );
  }

  bool get isListening => listeningState == ListeningState.listening;
  bool get isProcessing => listeningState == ListeningState.processing;
  bool get isSpeaking => listeningState == ListeningState.speaking;
  bool get isIdle => listeningState == ListeningState.idle;
}

class VoiceController extends StateNotifier<VoiceUIState> {
  final Ref _ref;
  final AudioCaptureService _audioCapture = AudioCaptureService();
  final VADDetector _vad = VADDetector();
  final SpeechRecognizer _recognizer = SpeechRecognizer();

  StreamSubscription? _vadSub;
  StreamSubscription? _audioStreamSub;
  StreamController<List<int>>? _audioBuffer;

  bool _isActive = false;
  List<AudioLevel> _recentLevels = [];
  static const int _maxLevels = 50;

  VoiceController({required Ref ref})
      : _ref = ref,
        super(const VoiceUIState()) {
    _vadSub = _vad.events.listen(_handleVADEvent);
  }

  /// Start listening for voice commands
  Future<void> startListening() async {
    if (_isActive) return;
    _isActive = true;

    state = state.copyWith(
      listeningState: ListeningState.listening,
      errorMessage: null,
    );

    try {
      final audioStream = await _audioCapture.startCapture(
        sampleRate: 16000,
        onAudioLevel: _onAudioLevel,
        onSpeechStart: () {},
        onSpeechEnd: () {},
      );

      _audioBuffer = StreamController<List<int>>.broadcast();
      _audioStreamSub = audioStream.listen(
        (data) {
          _audioBuffer?.add(data);

          // Simple energy-based VAD on PCM data
          if (data.isNotEmpty) {
            final pcmData = _bytesToInt16List(data);
            if (pcmData.isNotEmpty) {
              final rms = _calculateRMS(pcmData);
              final level = (rms / 32768.0).clamp(0.0, 1.0);
              _vad.processLevel(level);
            }
          }
        },
        onError: (e) {
          debugPrint('Audio stream error: $e');
          _handleError('音频采集错误: $e');
        },
      );
    } catch (e) {
      _isActive = false;
      _handleError('启动录音失败: $e');
    }
  }

  /// Stop listening and process audio
  Future<void> stopListening() async {
    if (!_isActive) return;

    state = state.copyWith(listeningState: ListeningState.processing);

    await _audioCapture.stopCapture();
    await _audioStreamSub?.cancel();
    _isActive = false;

    try {
      final wsClient = _ref.read(haWebSocketProvider);
      if (wsClient.isConnected) {
        final pipeline = _ref.read(haAssistPipelineProvider);
        final result = await pipeline.processTextCommand(
          text: state.lastTranscript ?? '',
        );

        if (result.success && result.responseText != null) {
          state = state.copyWith(
            listeningState: ListeningState.speaking,
            lastResponse: result.responseText,
          );
          await _playResponse(result.responseText!);
          state = state.copyWith(listeningState: ListeningState.idle);
        } else {
          state = state.copyWith(
            listeningState: ListeningState.idle,
            errorMessage: result.error ?? '无法处理语音指令',
          );
        }
      } else {
        await _processWithLocalLLM();
      }
    } catch (e) {
      _handleError('处理失败: $e');
    }
  }

  Future<void> _processWithLocalLLM() async {
    state = state.copyWith(listeningState: ListeningState.idle);
  }

  Future<void> _playResponse(String text) async {
    try {
      final ttsService = _ref.read(ttsServiceProvider);
      await ttsService.speak(text);
    } catch (e) {
      debugPrint('TTS playback failed: $e');
    }
  }

  Future<void> cancelListening() async {
    _isActive = false;
    await _audioCapture.stopCapture();
    await _audioStreamSub?.cancel();
    _vad.reset();
    state = state.copyWith(listeningState: ListeningState.idle);
  }

  void _onAudioLevel(double level) {
    _recentLevels = [
      ..._recentLevels,
      AudioLevel(level: level, timestamp: DateTime.now()),
    ];
    if (_recentLevels.length > _maxLevels) {
      _recentLevels = _recentLevels.sublist(_recentLevels.length - _maxLevels);
    }

    state = state.copyWith(
      audioLevel: level,
      recentLevels: List.from(_recentLevels),
    );
  }

  void _handleVADEvent(VADEvent event) {
    switch (event.type) {
      case VADEventType.speechStarted:
        debugPrint('Speech started');
        break;
      case VADEventType.speechEnded:
      case VADEventType.silenceTimeout:
        debugPrint('Speech ended (${event.type})');
        if (_isActive) stopListening();
        break;
      case VADEventType.noise:
        break;
    }
  }

  void _handleError(String message) {
    state = state.copyWith(
      listeningState: ListeningState.error,
      errorMessage: message,
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (state.listeningState == ListeningState.error) {
        state = state.copyWith(listeningState: ListeningState.idle);
      }
    });
  }

  double _calculateRMS(List<int> samples) {
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return (sum / samples.length).clamp(0.0, 32768.0);
  }

  List<int> _bytesToInt16List(List<int> bytes) {
    if (bytes.length < 2) return [];
    final samples = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      samples.add((bytes[i + 1] << 8) | (bytes[i] & 0xFF));
    }
    return samples;
  }

  @override
  void dispose() {
    _vadSub?.cancel();
    _audioStreamSub?.cancel();
    _audioBuffer?.close();
    _audioCapture.dispose();
    _vad.dispose();
    super.dispose();
  }
}
