/// TTS playback state
enum TTSPlaybackState {
  idle,
  speaking,
  paused,
  error,
}

/// TTS service state
class TTSState {
  final TTSPlaybackState playbackState;
  final String? currentText;
  final String? errorMessage;
  final double progress; // 0.0 - 1.0

  const TTSState({
    this.playbackState = TTSPlaybackState.idle,
    this.currentText,
    this.errorMessage,
    this.progress = 0.0,
  });

  TTSState copyWith({
    TTSPlaybackState? playbackState,
    String? currentText,
    String? errorMessage,
    double? progress,
  }) {
    return TTSState(
      playbackState: playbackState ?? this.playbackState,
      currentText: currentText ?? this.currentText,
      errorMessage: errorMessage,
      progress: progress ?? this.progress,
    );
  }

  bool get isSpeaking => playbackState == TTSPlaybackState.speaking;
  bool get isIdle => playbackState == TTSPlaybackState.idle;
}
