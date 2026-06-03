import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Home Assistant WebSocket client wrapping the HA WebSocket API
class HAWebSocketClient {
  WebSocketChannel? _channel;
  int _messageId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  final StreamController<HAEvent> _eventController =
      StreamController<HAEvent>.broadcast();

  bool _connected = false;
  String? _baseUrl;
  String? _token;
  String? _haVersion;
  Timer? _pingTimer;

  bool get isConnected => _connected;

  /// Stream of HA events (state_changed, etc.)
  Stream<HAEvent> get events => _eventController.stream;

  /// Connect to Home Assistant WebSocket API
  Future<void> connect({
    required String baseUrl,
    required String token,
  }) async {
    _baseUrl = baseUrl;
    _token = token;

    await disconnect();

    try {
      final wsUrl = _buildWsUrl(baseUrl);
      debugPrint('Connecting to HA WebSocket: $wsUrl');

      final ws = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      _channel = ws;
      _startPing();

      // Wait for auth_required
      final authRequired = await _channel!.stream.first;
      final authMsg = jsonDecode(authRequired as String) as Map<String, dynamic>;
      if (authMsg['type'] != 'auth_required') {
        throw HAException('Unexpected auth message: ${authMsg['type']}');
      }

      // Send auth
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'access_token': token,
      }));

      // Wait for auth_ok
      final authResult = await _channel!.stream.first;
      final authResultMsg = jsonDecode(authResult as String) as Map<String, dynamic>;
      if (authResultMsg['type'] != 'auth_ok') {
        final error = authResultMsg['message'] ?? 'Authentication failed';
        throw HAException('Auth failed: $error');
      }

      _connected = true;
      _eventController.add(const HAEvent(type: 'connected'));

      // Get HA version
      final result = await _sendCommand('get_config');
      _haVersion = result['version'] as String?;
      debugPrint('Connected to HA v$_haVersion');

      // Subscribe to state changes
      await _subscribeToEvents();

      // Start listening for messages
      _listenToMessages();
    } catch (e) {
      _connected = false;
      _eventController.add(HAEvent(type: 'error', data: {'message': e.toString()}));
      rethrow;
    }
  }

  /// Disconnect from Home Assistant
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _connected = false;

    await _channel?.sink.close();
    _channel = null;

    // Fail all pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(HAException('Connection closed'));
      }
    }
    _pendingRequests.clear();

    _eventController.add(const HAEvent(type: 'disconnected'));
  }

  /// Call a Home Assistant service
  Future<Map<String, dynamic>> callService({
    required String domain,
    required String service,
    String? entityId,
    Map<String, dynamic>? serviceData,
  }) async {
    final data = <String, dynamic>{
      'type': 'call_service',
      'domain': domain,
      'service': service,
    };

    if (serviceData != null && serviceData.isNotEmpty) {
      data['service_data'] = serviceData;
    }
    if (entityId != null) {
      data['target'] = {'entity_id': entityId};
    }

    return _sendCommand(data);
  }

  /// Get all states
  Future<List<Map<String, dynamic>>> getStates() async {
    final result = await _sendCommand('get_states');
    return List<Map<String, dynamic>>.from(result as List);
  }

  /// Get specific entity state
  Future<Map<String, dynamic>> getState(String entityId) async {
    return _sendCommand({
      'type': 'get_states',
      'entity_id': entityId,
    });
  }

  /// Get all areas
  Future<List<Map<String, dynamic>>> getAreas() async {
    final result = await _sendCommand({
      'type': 'get_areas',
    });
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get services registry
  Future<Map<String, dynamic>> getServices() async {
    return _sendCommand('get_services');
  }

  /// Render a template
  Future<String> renderTemplate(String template) async {
    final result = await _sendCommand({
      'type': 'render_template',
      'template': template,
    });
    return result['template'] as String? ?? '';
  }

  /// Ping (keep-alive)
  Future<void> ping() async {
    await _sendCommand('ping');
  }

  /// Run Assist pipeline (voice pipeline)
  Future<Stream<Map<String, dynamic>>> runAssistPipeline({
    required String startStage,
    String? endStage,
    Map<String, dynamic>? input,
    String? pipeline,
    String? conversationId,
    String? deviceId,
  }) async {
    final requestId = _messageId++;
    final data = <String, dynamic>{
      'id': requestId,
      'type': 'assist_pipeline/run',
      'start_stage': startStage,
      'end_stage': endStage ?? 'tts',
    };
    if (input != null) data['input'] = input;
    if (pipeline != null) data['pipeline'] = pipeline;
    if (conversationId != null) data['conversation_id'] = conversationId;
    if (deviceId != null) data['device_id'] = deviceId;

    _channel!.sink.add(jsonEncode(data));

    // Return a stream that listens for events related to this request
    final controller = StreamController<Map<String, dynamic>>();

    _eventController.stream.listen((event) {
      if (event.type == 'pipeline_event' &&
          event.data['request_id'] == requestId) {
        controller.add(event.data);
        if (event.data['type'] == 'run-end' ||
            event.data['type'] == 'error') {
          controller.close();
        }
      }
    });

    return controller.stream;
  }

  /// Send binary data (for audio streaming in Assist pipeline)
  Future<void> sendBinary(Uint8List data) async {
    if (_channel == null) throw HAException('Not connected');
    _channel!.sink.add(data);
  }

  // ---- Private helpers ----

  Future<dynamic> _sendCommand(dynamic command) async {
    if (_channel == null) {
      throw HAException('Not connected to Home Assistant');
    }

    final id = _messageId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final message = command is String
        ? {'id': id, 'type': command}
        : {'id': id, ...command as Map<String, dynamic>};

    _channel!.sink.add(jsonEncode(message));

    return completer.future.then((response) {
      if (response.containsKey('error')) {
        throw HAException(response['error']['message'] ?? 'Unknown error');
      }
      return response['result'] ?? response;
    });
  }

  Future<void> _subscribeToEvents() async {
    await _sendCommand({
      'type': 'subscribe_events',
      'event_type': 'state_changed',
    });
  }

  void _listenToMessages() {
    _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'event') {
            final event = msg['event'] as Map<String, dynamic>? ?? {};
            _eventController.add(HAEvent(
              type: event['event_type'] as String? ?? 'unknown',
              data: event['data'] as Map<String, dynamic>? ?? {},
              origin: event['origin'] as String?,
              timeFired: event['time_fired'] as String?,
            ));
          } else if (type == 'pipeline_event') {
            _eventController.add(HAEvent(
              type: 'pipeline_event',
              data: msg,
            ));
          } else if (type == 'result') {
            final id = msg['id'] as int?;
            final completer = _pendingRequests.remove(id);
            if (completer != null && !completer.isCompleted) {
              completer.complete(msg);
            }
          } else if (type == 'auth_required') {
            // Handled in connect()
          }
        } catch (e) {
          debugPrint('Error parsing HA message: $e');
        }
      },
      onError: (error) {
        debugPrint('HA WebSocket error: $error');
        _eventController.add(HAEvent(type: 'error', data: {'message': error.toString()}));
      },
      onDone: () {
        debugPrint('HA WebSocket closed');
        _connected = false;
        _eventController.add(const HAEvent(type: 'disconnected'));
      },
    );
  }

  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ping().catchError((_) {});
    });
  }

  String _buildWsUrl(String baseUrl) {
    var url = baseUrl.trim();
    // Remove trailing slash
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    // If it's an HTTP URL, convert to WebSocket
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'ws://');
    } else if (url.startsWith('https://')) {
      url = url.replaceFirst('https://', 'wss://');
    } else if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }

    return '$url/api/websocket';
  }
}

/// Event from Home Assistant
class HAEvent {
  final String type;
  final Map<String, dynamic> data;
  final String? origin;
  final String? timeFired;

  const HAEvent({
    required this.type,
    this.data = const {},
    this.origin,
    this.timeFired,
  });
}

class HAException implements Exception {
  final String message;
  const HAException(this.message);

  @override
  String toString() => 'HAException: $message';
}
