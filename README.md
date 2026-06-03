# 智能语音居家助手 - Home Voice Assistant

基于 **Flutter** + **Home Assistant** 的智能语音家居控制系统，集成 **VAD + VSR/Whisper + LLM + TTS** 全链路语音交互。

## 架构

```
用户语音 → VAD (Silero) → STT (Whisper) → LLM (Ollama/OpenAI) → HA WebSocket API → 设备控制
                                                                         ↓
                                                                  TTS (Piper) → 语音回复
```

## 功能特色

- 🎙️ **语音控制**: 按住说话，VAD自动检测语音起止
- 🧠 **双模式LLM**: 本地 Ollama / 云端 OpenAI 兼容API
- 🏠 **Home Assistant 集成**: WebSocket实时连接，设备状态同步
- 🔊 **TTS语音反馈**: 支持 Piper(本地)/CosyVoice/系统TTS/HA Pipeline
- 📱 **跨平台**: Android / iOS / Linux / macOS / Windows
- 🔒 **隐私优先**: 支持完全离线运行

## 快速开始

### 1. 环境准备

```bash
# Flutter 3.27+ / Dart 3.6+
flutter --version

# 安装依赖
cd home_voice_assistant
flutter pub get
```

### 2. 配置 Home Assistant

1. 在 HA 中创建长期访问令牌：`个人资料 → 长期访问令牌`
2. 在 App 设置页面填写：
   - HA服务器地址: `http://homeassistant.local:8123`
   - 访问令牌

### 3. 部署本地 LLM (可选)

```bash
docker run -d --name ollama -p 11434:11434 ollama/ollama
ollama pull qwen2.5:3b
```

### 4. 部署 Piper TTS (可选)

```bash
docker run -d --name piper -p 5000:5000 rhasspy/piper
```

### 5. 运行

```bash
flutter run
```

## 项目结构

```
lib/
├── main.dart                          # 入口
├── app.dart                           # 主界面 (3 Tab)
├── core/config/app_config.dart        # 配置管理
├── features/
│   ├── voice/                         # 语音模块
│   │   ├── data/                      # VAD检测器 / 语音识别 / 音频采集
│   │   ├── domain/                    # 语音服务接口
│   │   └── presentation/             # 语音按钮 / 波形指示器
│   ├── ha/                            # Home Assistant 模块
│   │   ├── data/                      # WebSocket客户端 / Assist Pipeline
│   │   ├── domain/                    # 实体/区域模型
│   │   └── presentation/             # 设备面板 / 实体卡片
│   ├── chat/                          # LLM 对话模块
│   │   ├── data/                      # Ollama / OpenAI 客户端
│   │   ├── domain/                    # 消息/对话接口
│   │   └── presentation/             # 对话气泡
│   └── tts/                           # TTS 模块
│       ├── data/                      # Piper / 系统TTS
│       └── domain/                    # TTS接口/状态
└── shared/widgets/                    # 通用组件
```

## 组件说明

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| VAD | Silero VAD + 能量VAD回退 | 低延迟检测语音起止 |
| STT | HA Pipeline / Whisper / Ollama | 三级回退策略 |
| LLM | Ollama (Qwen2.5) / OpenAI | 支持function call |
| TTS | Piper / CosyVoice / 系统TTS | 本地优先 |
| HA | WebSocket API | 实时双向通信 |

## 许可

MIT
