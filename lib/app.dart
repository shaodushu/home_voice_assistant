import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'features/ha/presentation/ha_controller.dart';
import 'features/voice/presentation/voice_controller.dart';
import 'features/voice/presentation/widgets/voice_button.dart';
import 'features/voice/presentation/widgets/voice_indicator.dart';
import 'features/ha/presentation/widgets/device_panel.dart';
import 'features/ha/presentation/widgets/entity_card.dart';
import 'features/chat/presentation/widgets/conversation_view.dart';
import 'shared/widgets/error_display.dart';

class HomeVoiceAssistantApp extends ConsumerStatefulWidget {
  const HomeVoiceAssistantApp({super.key});

  @override
  ConsumerState<HomeVoiceAssistantApp> createState() => _HomeVoiceAssistantAppState();
}

class _HomeVoiceAssistantAppState extends ConsumerState<HomeVoiceAssistantApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize HA connection on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(haControllerProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeTab(),
          _DevicesTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haState = ref.watch(haControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能语音助手'),
        centerTitle: true,
        actions: [
          if (haState.connectionStatus == ConnectionStatus.connected)
            IconButton(
              icon: const Icon(Icons.circle, color: Colors.green, size: 16),
              tooltip: 'Home Assistant 已连接',
              onPressed: null,
            )
          else if (haState.connectionStatus == ConnectionStatus.connecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.circle, color: Colors.red, size: 16),
              tooltip: 'Home Assistant 未连接',
              onPressed: () => ref.read(haControllerProvider.notifier).connect(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(haControllerProvider.notifier).refreshEntities(),
            tooltip: '刷新设备',
          ),
        ],
      ),
      body: Column(
        children: [
          // Voice Control Area
          Expanded(
            flex: 3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const VoiceIndicator(),
                  const SizedBox(height: 24),
                  VoiceButton(
                    onStart: () => ref.read(voiceControllerProvider.notifier).startListening(),
                    onStop: () => ref.read(voiceControllerProvider.notifier).stopListening(),
                    isListening: voiceState.isListening,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    voiceState.isListening ? '正在聆听...' : '点击说话',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: voiceState.isListening
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Recent conversation or status
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const ConversationView(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesTab extends ConsumerWidget {
  const _DevicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haState = ref.watch(haControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能设备'),
        centerTitle: true,
      ),
      body: haState.when(
        initial: () => const Center(child: Text('请先在设置中连接 Home Assistant')),
        loading: () => const Center(child: CircularProgressIndicator()),
        connected: (entities) => DevicePanel(entities: entities),
        error: (message) => ErrorDisplay(
          message: message,
          onRetry: () => ref.read(haControllerProvider.notifier).connect(),
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final haController = ref.read(haControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Home Assistant Settings
          _SectionHeader(title: 'Home Assistant 配置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('服务器地址'),
                  subtitle: Text(config.haBaseUrl.isEmpty ? '未设置' : config.haBaseUrl),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editConfig(context, 'ha_url', config.haBaseUrl, (v) {
                    haController.updateConfig(haBaseUrl: v);
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('访问令牌'),
                  subtitle: Text(
                    config.haToken.isEmpty ? '未设置' : '•' * 20,
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editConfig(context, 'ha_token', config.haToken, (v) {
                    haController.updateConfig(haToken: v);
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // LLM Settings
          _SectionHeader(title: 'LLM 配置'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('使用云端 LLM'),
                  subtitle: const Text('关闭则使用本地 Ollama'),
                  value: config.useCloudLLM,
                  onChanged: (v) => haController.updateConfig(useCloudLLM: v),
                ),
                if (config.useCloudLLM) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.api),
                    title: const Text('API Key'),
                    subtitle: Text(
                      config.openAIApiKey.isEmpty ? '未设置' : '•' * 20,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editConfig(context, 'api_key', config.openAIApiKey, (v) {
                      haController.updateConfig(openAIApiKey: v);
                    }),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud),
                    title: const Text('API Base URL'),
                    subtitle: Text(config.openAIBaseUrl.isEmpty ? '默认' : config.openAIBaseUrl),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editConfig(context, 'api_base_url', config.openAIBaseUrl, (v) {
                      haController.updateConfig(openAIBaseUrl: v);
                    }),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.model_training),
                  title: const Text('Ollama 模型'),
                  subtitle: Text(config.ollamaModel.isEmpty ? 'llama3.2' : config.ollamaModel),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editConfig(context, 'ollama_model', config.ollamaModel, (v) {
                    haController.updateConfig(ollamaModel: v);
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // TTS Settings
          _SectionHeader(title: '语音合成 (TTS)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('TTS 引擎'),
                  subtitle: Text(_ttsEngineName(config.ttsEngine)),
                  trailing: DropdownButton<String>(
                    value: config.ttsEngine,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'piper', child: Text('Piper (本地)')),
                      DropdownMenuItem(value: 'cosyvoice', child: Text('CosyVoice')),
                      DropdownMenuItem(value: 'platform', child: Text('系统TTS')),
                      DropdownMenuItem(value: 'ha_pipeline', child: Text('HA Pipeline')),
                    ],
                    onChanged: (v) {
                      if (v != null) haController.updateConfig(ttsEngine: v);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('语言'),
                  subtitle: Text(config.ttsLanguage == 'zh' ? '中文' : 'English'),
                  trailing: DropdownButton<String>(
                    value: config.ttsLanguage,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'zh', child: Text('中文')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) {
                      if (v != null) haController.updateConfig(ttsLanguage: v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Wake Word Settings
          _SectionHeader(title: '唤醒词'),
          Card(
            child: SwitchListTile(
              title: const Text('启用语音唤醒'),
              subtitle: const Text('说"嘿 助手"唤醒'),
              value: config.wakeWordEnabled,
              onChanged: (v) => haController.updateConfig(wakeWordEnabled: v),
            ),
          ),

          const SizedBox(height: 32),

          // Connection
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.wifi),
              label: Text(
                config.haBaseUrl.isEmpty || config.haToken.isEmpty
                    ? '请先填写 HA 配置'
                    : '连接到 Home Assistant',
              ),
              onPressed: (config.haBaseUrl.isNotEmpty && config.haToken.isNotEmpty)
                  ? () => haController.connect()
                  : null,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _ttsEngineName(String engine) {
    switch (engine) {
      case 'piper': return 'Piper (本地)';
      case 'cosyvoice': return 'CosyVoice';
      case 'platform': return '系统TTS';
      case 'ha_pipeline': return 'HA Pipeline';
      default: return engine;
    }
  }

  void _editConfig(BuildContext context, String title, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
