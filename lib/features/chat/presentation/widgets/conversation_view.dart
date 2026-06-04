import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat_controller.dart';
import '../../domain/chat_message.dart';

/// Conversation view showing recent messages
class ConversationView extends ConsumerWidget {
  const ConversationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final theme = Theme.of(context);

    if (chatState.messages.isEmpty) {
      return Center(
        child: Text(
          '点击麦克风按钮开始语音控制\n或在下方输入文字指令',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Show last 3 messages
    final recentMessages = chatState.messages.length > 3
        ? chatState.messages.sublist(chatState.messages.length - 3)
        : chatState.messages;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recentMessages.length,
      itemBuilder: (context, index) {
        final msg = recentMessages[index];
        final isUser = msg.role == MessageRole.user;
        final isLast = index == recentMessages.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.smart_toy,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
              if (isUser)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
