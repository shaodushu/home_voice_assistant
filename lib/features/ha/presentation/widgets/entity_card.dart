import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/ha_entity.dart';
import '../ha_controller.dart';

/// Entity card widget - displays and controls a Home Assistant entity
class EntityCard extends ConsumerWidget {
  final HAEntity entity;

  const EntityCard({super.key, required this.entity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOn = entity.state == 'on' || entity.state == 'open';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Entity icon
              _buildIcon(theme, isOn),
              const SizedBox(height: 8),
              // Entity name
              Text(
                entity.displayName,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              // State
              Text(
                _stateText(entity),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOn
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme, bool isOn) {
    IconData icon;
    Color color;

    switch (entity.category) {
      case EntityCategory.switch_:
        icon = isOn ? Icons.lightbulb : Icons.lightbulb_outline;
        color = isOn ? Colors.amber : theme.colorScheme.onSurfaceVariant;
        break;
      case EntityCategory.sensor:
        icon = Icons.thermostat;
        color = theme.colorScheme.secondary;
        break;
      case EntityCategory.climate:
        icon = isOn ? Icons.ac_unit : Icons.ac_unit_outlined;
        color = isOn ? Colors.lightBlue : theme.colorScheme.onSurfaceVariant;
        break;
      case EntityCategory.cover:
        icon = isOn ? Icons.blinds_open : Icons.blinds_closed;
        color = isOn ? Colors.green : theme.colorScheme.onSurfaceVariant;
        break;
      case EntityCategory.lock:
        icon = isOn ? Icons.lock_open : Icons.lock;
        color = isOn ? Colors.red : Colors.green;
        break;
      case EntityCategory.mediaPlayer:
        icon = isOn ? Icons.play_circle : Icons.play_circle_outline;
        color = isOn ? Colors.purple : theme.colorScheme.onSurfaceVariant;
        break;
      case EntityCategory.other:
        icon = Icons.devices;
        color = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Icon(icon, size: 28, color: color);
  }

  String _stateText(HAEntity entity) {
    if (entity.isSensor) {
      final unit = entity.attributes['unit_of_measurement'] as String? ?? '';
      return '${entity.state}$unit';
    }
    if (entity.isClimate) {
      final currentTemp = entity.attributes['current_temperature'];
      if (currentTemp != null) return '$currentTemp°';
    }
    switch (entity.state) {
      case 'on': return '已开启';
      case 'off': return '已关闭';
      case 'open': return '已打开';
      case 'closed': return '已关闭';
      case 'unlocked': return '已解锁';
      case 'locked': return '已上锁';
      case 'home': return '在家';
      case 'not_home': return '离家';
      default: return entity.state;
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    final controller = ref.read(haControllerProvider.notifier);
    controller.toggleEntity(entity);
  }
}
