/// Home Assistant entity model
class HAEntity {
  final String entityId;
  final String state;
  final String? friendlyName;
  final String? areaId;
  final String? deviceClass;
  final Map<String, dynamic> attributes;
  final DateTime lastChanged;
  final DateTime lastUpdated;
  final String? icon;

  const HAEntity({
    required this.entityId,
    required this.state,
    this.friendlyName,
    this.areaId,
    this.deviceClass,
    this.attributes = const {},
    required this.lastChanged,
    required this.lastUpdated,
    this.icon,
  });

  factory HAEntity.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return HAEntity(
      entityId: json['entity_id'] as String? ?? '',
      state: json['state'] as String? ?? 'unknown',
      friendlyName: attrs['friendly_name'] as String?,
      areaId: attrs['area_id'] as String?,
      deviceClass: attrs['device_class'] as String?,
      attributes: attrs,
      lastChanged: DateTime.tryParse(json['last_changed'] as String? ?? '') ?? DateTime.now(),
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ?? DateTime.now(),
      icon: attrs['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'entity_id': entityId,
    'state': state,
    'attributes': {
      'friendly_name': friendlyName,
      'area_id': areaId,
      'device_class': deviceClass,
      ...attributes,
    },
    'last_changed': lastChanged.toIso8601String(),
    'last_updated': lastUpdated.toIso8601String(),
  };

  /// Get display name for the entity
  String get displayName => friendlyName ?? entityId;

  /// Get domain from entity_id (e.g., "light" from "light.living_room")
  String get domain => entityId.split('.').first;

  /// Check if entity is a specific type
  bool get isLight => domain == 'light';
  bool get isSwitch => domain == 'switch';
  bool get isSensor => domain == 'sensor';
  bool get isClimate => domain == 'climate';
  bool get isCover => domain == 'cover';
  bool get isLock => domain == 'lock';
  bool get isMediaPlayer => domain == 'media_player';
  bool get isBinarySensor => domain == 'binary_sensor';

  /// Entity category
  EntityCategory get category {
    if (isLight || isSwitch) return EntityCategory.switch_;
    if (isSensor || isBinarySensor) return EntityCategory.sensor;
    if (isClimate) return EntityCategory.climate;
    if (isCover) return EntityCategory.cover;
    if (isLock) return EntityCategory.lock;
    if (isMediaPlayer) return EntityCategory.mediaPlayer;
    return EntityCategory.other;
  }

  /// Get state as a numeric value (for sensors)
  double? get numericState => double.tryParse(state);
}

enum EntityCategory {
  switch_,
  sensor,
  climate,
  cover,
  lock,
  mediaPlayer,
  other,
}

/// Area/room model
class HAArea {
  final String areaId;
  final String name;
  final String? picture;

  const HAArea({
    required this.areaId,
    required this.name,
    this.picture,
  });

  factory HAArea.fromJson(Map<String, dynamic> json) {
    return HAArea(
      areaId: json['area_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      picture: json['picture'] as String?,
    );
  }
}

/// Service call request
class HAServiceCall {
  final String domain;
  final String service;
  final String? targetEntityId;
  final Map<String, dynamic>? serviceData;

  const HAServiceCall({
    required this.domain,
    required this.service,
    this.targetEntityId,
    this.serviceData,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'service': service,
    'target': {
      if (targetEntityId != null) 'entity_id': targetEntityId,
    },
    if (serviceData != null) 'service_data': serviceData,
  };
}
