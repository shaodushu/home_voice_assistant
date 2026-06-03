import 'package:flutter/material.dart';

/// Main voice control button - push to talk
class VoiceButton extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool isListening;

  const VoiceButton({
    super.key,
    required this.onStart,
    required this.onStop,
    required this.isListening,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.isListening;

    return GestureDetector(
      onTapDown: !isListening ? (_) => widget.onStart() : null,
      onTapUp: isListening ? (_) => widget.onStop() : null,
      onTapCancel: isListening ? widget.onStop : null,
      onLongPressStart: !isListening ? (_) => widget.onStart() : null,
      onLongPressEnd: isListening ? (_) => widget.onStop() : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isListening
                      ? [theme.colorScheme.primary, theme.colorScheme.tertiary]
                      : [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHighest],
                ),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(100),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                size: 36,
                color: isListening
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
