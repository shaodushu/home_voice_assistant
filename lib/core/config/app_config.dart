import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application configuration model
class AppConfigModel {
  final String haBaseUrl;
  final String haToken;
  final String ttsEngine;
  final String ttsLanguage;
  final bool useCloudLLM;
  final String openAIApiKey;
  final String openAIBaseUrl;
  final String ollamaHost;
  final String ollamaModel;
  final bool wakeWordEnabled;
  final bool persistentConnection;

  const AppConfigModel({
    this.haBaseUrl = '',
    this.haToken = '',
    this.ttsEngine = 'piper',
    this.ttsLanguage = 'zh',
    this.useCloudLLM = false,
    this.openAIApiKey = '',
    this.openAIBaseUrl = 'http://localhost:11434/v1',
    this.ollamaHost = 'http://localhost:11434',
    this.ollamaModel = 'qwen2.5:3b',
    this.wakeWordEnabled = false,
    this.persistentConnection = true,
  });

  AppConfigModel copyWith({
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
    return AppConfigModel(
      haBaseUrl: haBaseUrl ?? this.haBaseUrl,
      haToken: haToken ?? this.haToken,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      useCloudLLM: useCloudLLM ?? this.useCloudLLM,
      openAIApiKey: openAIApiKey ?? this.openAIApiKey,
      openAIBaseUrl: openAIBaseUrl ?? this.openAIBaseUrl,
      ollamaHost: ollamaHost ?? this.ollamaHost,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      persistentConnection: persistentConnection ?? this.persistentConnection,
    );
  }
}

/// Application configuration provider
final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfigModel>((ref) {
  return AppConfigNotifier();
});

class AppConfigNotifier extends StateNotifier<AppConfigModel> {
  AppConfigNotifier() : super(const AppConfigModel()) {
    _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    // In-memory storage for now; extend with SharedPreferences later
    // For production, use shared_preferences package
    try {
      final storage = _ConfigStorage();
      final config = await storage.load();
      if (config != null) state = config;
    } catch (e) {
      debugPrint('Failed to load config: $e');
    }
  }

  Future<void> _saveToDisk(AppConfigModel config) async {
    try {
      final storage = _ConfigStorage();
      await storage.save(config);
    } catch (e) {
      debugPrint('Failed to save config: $e');
    }
  }

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
    final newConfig = state.copyWith(
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
    state = newConfig;
    _saveToDisk(newConfig);
  }
}

/// Simple JSON-file-based config storage
class _ConfigStorage {
  Future<AppConfigModel?> load() async {
    // TODO: Implement with path_provider + dart:io for JSON persistence
    return null; // Returns null to use defaults
  }

  Future<void> save(AppConfigModel config) async {
    // TODO: Write config to JSON file
  }
}

/// App initialization
class AppInitializer {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
  }
}
