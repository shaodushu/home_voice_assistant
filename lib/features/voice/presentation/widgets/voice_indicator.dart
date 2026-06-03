import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../voice_controller.dart';

/// Voice activity indicator with animated waveform
class VoiceIndicator extends ConsumerStatefulWidget {
  const VoiceIndicator({super.key});

  @override
  ConsumerState<VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends ConsumerState<VoiceIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    final theme = Theme.of(context);

    final isActive = voiceState.isListening || voiceState.isSpeaking;

    if (!isActive && voiceState.lastResponse == null) {
      return const SizedBox(height: 80);
    }

    return SizedBox(
      height: 80,
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: _WaveformPainter(
          levels: voiceState.recentLevels.map((l) => l.level).toList(),
          isActive: isActive,
          color: voiceState.isListening
              ? theme.colorScheme.primary
              : voiceState.isSpeaking
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.secondary,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final bool isActive;
  final Color color;

  _WaveformPainter({
    required this.levels,
    required this.isActive,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final barPaint = Paint()
      ..color = color.withAlpha(isActive ? 200 : 80)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / levels.length;
    final centerY = size.height / 2;

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final barHeight = max(2.0, level * size.height * 0.8);
      final x = i * barWidth;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, centerY),
            width: barWidth * 0.6,
            height: barHeight,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.isActive != isActive;
}
