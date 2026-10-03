#!/bin/bash
# 一键启动《元素纪元 2D》Godot 游戏窗口
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$GODOT_BIN" ]; then
    echo "🎮 正在启动《元素纪元 2D》..."
    "$GODOT_BIN" --path "$PROJECT_DIR"
else
    echo "❌ 未检测到 Godot 应用在 /Applications/Godot.app，请确认安装位置。"
fi
