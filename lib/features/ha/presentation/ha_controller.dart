import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ha_websocket_client.dart';
import '../data/ha_assist_pipeline.dart';
import '../domain/ha_entity.dart';
import '../../../core/config/app_config.dart';

// Provider for WebSocket client singleton
final haWebSocketProvider = Provider<HAWebSocketClient>((ref) {
  final client = HAWebSocketClient();
  ref.onDispose(() {
    client.disconnect();
  });
  return client;
});

// Provider for Assist Pipeline
final haAssistPipelineProvider = Provider<HAAssistPipeline>((ref) {
  final ws = ref.watch(haWebSocketProvider);
  return HAAssistPipeline(ws);
});

// HA Controller Provider
final haControllerProvider =
    StateNotifierProvider<HAController, HAState>((ref) {
  final config = ref.watch(appConfigProvider);
  final ws = ref.watch(haWebSocketProvider);
  final pipeline = ref.watch(haAssistPipelineProvider);
  return HAController(config: config, ws: ws, pipeline: pipeline, ref: ref);
});

/// Connection status
enum ConnectionStatus { initial, connecting, connected, error }

/// State
class HAState {
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
  final List<HAEntity> entities;
  final List<HAArea> areas;
  final String? haVersion;
  final bool isLoading;

  const HAState({
    this.connectionStatus = ConnectionStatus.initial,
    this.errorMessage,
    this.entities = const [],
    this.areas = const [],
    this.haVersion,
    this.isLoading = false,
  });

  HAState copyWith({
    ConnectionStatus? connectionStatus,
    String? errorMessage,
    List<HAEntity>? entities,
    List<HAArea>? areas,
    String? haVersion,
    bool? isLoading,
  }) {
    return HAState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: errorMessage,
      entities: entities ?? this.entities,
      areas: areas ?? this.areas,
      haVersion: haVersion ?? this.haVersion,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Widget-friendly when() pattern
  T when<T>({
    required T Function() initial,
    required T Function() loading,
    required T Function(List<HAEntity> entities) connected,
    required T Function(String message) error,
  }) {
    switch (connectionStatus) {
      case ConnectionStatus.initial:
        return initial();
      case ConnectionStatus.connecting:
        return loading();
      case ConnectionStatus.connected:
        return connected(entities);
      case ConnectionStatus.error:
        return error(errorMessage ?? 'Unknown error');
    }
  }
}

class HAController extends StateNotifier<HAState> {
  final HAWebSocketClient _ws;
  final HAAssistPipeline _pipeline;
  final AppConfigModel _config;
  final Ref _ref;
  StreamSubscription? _eventSub;

  HAController({
    required AppConfigModel config,
    required HAWebSocketClient ws,
    required HAAssistPipeline pipeline,
    required Ref ref,
  })  : _config = config,
        _ws = ws,
        _pipeline = pipeline,
        _ref = ref,
        super(const HAState());

  /// Connect to Home Assistant
  Future<void> connect() async {
    if (_config.haBaseUrl.isEmpty || _config.haToken.isEmpty) {
      state = state.copyWith(
        connectionStatus: ConnectionStatus.error,
        errorMessage: '请先配置 Home Assistant 地址和令牌',
      );
      return;
    }

    state = state.copyWith(
      connectionStatus: ConnectionStatus.connecting,
      errorMessage: null,
    );

    try {
      await _ws.connect(
        baseUrl: _config.haBaseUrl,
        token: _config.haToken,
      );

      // Load entities and areas
      await refreshEntities();

      // Subscribe to events
      _eventSub?.cancel();
      _eventSub = _ws.events.listen(_handleEvent);

      state = state.copyWith(
        connectionStatus: ConnectionStatus.connected,
        haVersion: state.haVersion,
      );
    } catch (e) {
      state = state.copyWith(
        connectionStatus: ConnectionStatus.error,
        errorMessage: '连接失败: ${e.toString()}',
      );
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    _eventSub?.cancel();
    await _ws.disconnect();
    state = state.copyWith(
      connectionStatus: ConnectionStatus.initial,
      entities: [],
    );
  }

  /// Refresh entities from HA
  Future<void> refreshEntities() async {
    state = state.copyWith(isLoading: true);
    try {
      final statesData = await _ws.getStates();
      final entities = statesData.map((json) => HAEntity.fromJson(json)).toList();

      List<HAArea> areas = [];
      try {
        final areasData = await _ws.getAreas();
        areas = areasData.map((json) => HAArea.fromJson(json)).toList();
      } catch (_) {
        // Areas might not be available in all HA versions
      }

      state = state.copyWith(
        entities: entities,
        areas: areas,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Failed to refresh entities: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Call a service on HA
  Future<bool> callService({
    required String domain,
    required String service,
    String? entityId,
    Map<String, dynamic>? serviceData,
  }) async {
    try {
      await _ws.callService(
        domain: domain,
        service: service,
        entityId: entityId,
        serviceData: serviceData,
      );
      return true;
    } catch (e) {
      debugPrint('Service call failed: $e');
      return false;
    }
  }

  /// Toggle a device on/off
  Future<bool> toggleEntity(HAEntity entity) async {
    return callService(
      domain: entity.domain,
      service: 'toggle',
      entityId: entity.entityId,
    );
  }

  /// Turn on a device
  Future<bool> turnOn(HAEntity entity) async {
    return callService(
      domain: entity.domain,
      service: 'turn_on',
      entityId: entity.entityId,
    );
  }

  /// Turn off a device
  Future<bool> turnOff(HAEntity entity) async {
    return callService(
      domain: entity.domain,
      service: 'turn_off',
      entityId: entity.entityId,
    );
  }

  /// Set brightness for light
  Future<bool> setBrightness(String entityId, int brightness) async {
    return callService(
      domain: 'light',
      service: 'turn_on',
      entityId: entityId,
      serviceData: {'brightness': brightness},
    );
  }

  /// Set temperature for climate
  Future<bool> setTemperature(String entityId, double temperature) async {
    return callService(
      domain: 'climate',
      service: 'set_temperature',
      entityId: entityId,
      serviceData: {'temperature': temperature},
    );
  }

  /// Process a text command using Assist Pipeline
  Future<String?> processTextCommand(String text) async {
    try {
      final result = await _pipeline.processTextCommand(text: text);
      return result.responseText;
    } catch (e) {
      debugPrint('Assist command failed: $e');
      return null;
    }
  }

  /// Update HA configuration
  void updateConfig({
    String? haBaseUrl,
    String? haToken,
    String? ttsEngine,
    String? ttsLanguage,
    bool? useCloudLLM,
    String? openAIApiKey,
    String? openAIBaseUrl,
    String? ollamaHost,
    String? ollamaModel,
    bool? wakeWordEnabled,
    bool? persistentConnection,
  }) {
    _ref.read(appConfigProvider.notifier).updateConfig(
      haBaseUrl: haBaseUrl,
      haToken: haToken,
      ttsEngine: ttsEngine,
      ttsLanguage: ttsLanguage,
      useCloudLLM: useCloudLLM,
      openAIApiKey: openAIApiKey,
      openAIBaseUrl: openAIBaseUrl,
      ollamaHost: ollamaHost,
      ollamaModel: ollamaModel,
      wakeWordEnabled: wakeWordEnabled,
      persistentConnection: persistentConnection,
    );
  }

  void _handleEvent(HAEvent event) {
    if (event.type == 'state_changed') {
      // Update entity state when it changes
      final entityData = event.data;
      if (entityData['entity_id'] != null) {
        final updatedEntity = HAEntity.fromJson({
          'entity_id': entityData['entity_id'],
          'state': entityData['new_state']?['state'],
          'attributes': entityData['new_state']?['attributes'] ?? {},
          'last_changed': entityData['new_state']?['last_changed'],
          'last_updated': entityData['new_state']?['last_updated'],
        });
        final updatedEntities = state.entities.map((e) {
          return e.entityId == updatedEntity.entityId ? updatedEntity : e;
        }).toList();
        state = state.copyWith(entities: updatedEntities);
      }
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
