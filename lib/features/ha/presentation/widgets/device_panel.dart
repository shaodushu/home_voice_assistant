import 'package:flutter/material.dart';
import '../../domain/ha_entity.dart';
import 'entity_card.dart';

/// Device control panel - shows all HA entities grouped by category
class DevicePanel extends StatelessWidget {
  final List<HAEntity> entities;

  const DevicePanel({super.key, required this.entities});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupEntities(entities);

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 16),
            Text('没有找到设备',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Pull to refresh
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Common controls section
          _buildControlSection(
            context,
            title: '常用设备',
            entities: grouped['common'] ?? [],
            columns: 4,
          ),
          const SizedBox(height: 16),

          // Lights section
          if ((grouped['light'] ?? []).isNotEmpty) ...[
            _SectionHeader(title: '灯光'),
            const SizedBox(height: 8),
            _buildControlSection(
              context,
              entities: grouped['light']!,
              columns: 4,
            ),
            const SizedBox(height: 16),
          ],

          // Climate section
          if ((grouped['climate'] ?? []).isNotEmpty) ...[
            _SectionHeader(title: '空调/暖气'),
            const SizedBox(height: 8),
            _buildControlSection(
              context,
              entities: grouped['climate']!,
              columns: 2,
            ),
            const SizedBox(height: 16),
          ],

          // Covers section
          if ((grouped['cover'] ?? []).isNotEmpty) ...[
            _SectionHeader(title: '窗帘/门窗'),
            const SizedBox(height: 8),
            _buildControlSection(
              context,
              entities: grouped['cover']!,
              columns: 4,
            ),
            const SizedBox(height: 16),
          ],

          // Sensors section
          if ((grouped['sensor'] ?? []).isNotEmpty) ...[
            _SectionHeader(title: '传感器'),
            const SizedBox(height: 8),
            _buildControlSection(
              context,
              entities: grouped['sensor']!,
              columns: 3,
            ),
            const SizedBox(height: 16),
          ],

          // Other devices
          if ((grouped['other'] ?? []).isNotEmpty) ...[
            _SectionHeader(title: '其他设备'),
            const SizedBox(height: 8),
            _buildControlSection(
              context,
              entities: grouped['other']!,
              columns: 4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context, {
    String? title,
    required List<HAEntity> entities,
    int columns = 4,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: entities.length,
      itemBuilder: (context, index) {
        return EntityCard(entity: entities[index]);
      },
    );
  }

  Map<String, List<HAEntity>> _groupEntities(List<HAEntity> entities) {
    final grouped = <String, List<HAEntity>>{};

    for (final entity in entities) {
      // Skip hidden/disabled entities
      if (entity.entityId.startsWith('zone') ||
          entity.entityId.startsWith('scene') ||
          entity.entityId.startsWith('automation')) {
        continue;
      }

      final key = _getGroupKey(entity);
      grouped.putIfAbsent(key, () => []).add(entity);
    }

    // Sort entities by display name
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    return grouped;
  }

  String _getGroupKey(HAEntity entity) {
    if (entity.isLight) return 'light';
    if (entity.isClimate) return 'climate';
    if (entity.isCover) return 'cover';
    if (entity.isSensor || entity.isBinarySensor) return 'sensor';
    if (entity.isSwitch) return 'common';
    if (entity.isMediaPlayer || entity.isLock) return 'other';
    return 'other';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
