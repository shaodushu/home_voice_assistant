#!/bin/bash
# Setup script for Home Voice Assistant

echo "=== Home Voice Assistant Setup ==="

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter not found. Please install Flutter SDK."
    echo "  https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "[OK] Flutter: $(flutter --version 2>&1 | head -1)"

# Install dependencies
echo ""
echo "Installing Flutter dependencies..."
flutter pub get

# Check Docker
if command -v docker &> /dev/null; then
    echo ""
    echo "[OK] Docker found"
    echo ""
    echo "Optional: Start local services?"
    echo "  docker compose up -d ollama piper"
else
    echo "[WARN] Docker not found - install for local LLM/TTS"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. flutter run"
echo "  2. Configure HA connection in Settings tab"
echo "  3. (Optional) Start local models: docker compose up -d"
