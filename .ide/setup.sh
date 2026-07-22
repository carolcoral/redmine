#!/bin/sh
# ============================================================
# CodeBuddy 数据持久化脚本
# 在 CNB 云原生开发环境启动时，将 ~/.codebuddy 链接到
# 工作区持久化目录 /workspace/.codebuddy-home/
# ============================================================

PERSIST_DIR="/workspace/.codebuddy-home"
CODEBUDDY_HOME="/root/.codebuddy"

# 如果持久化目录不存在（首次使用），创建并初始化
if [ ! -d "$PERSIST_DIR" ]; then
    mkdir -p "$PERSIST_DIR"
    # 如果当前 ~/.codebuddy 有数据（非软链接），迁移过来
    if [ -d "$CODEBUDDY_HOME" ] && [ ! -L "$CODEBUDDY_HOME" ]; then
        cp -a "$CODEBUDDY_HOME"/. "$PERSIST_DIR"/ 2>/dev/null
    fi
fi

# 确保 ~/.codebuddy 是软链接指向持久化目录
if [ ! -L "$CODEBUDDY_HOME" ] || [ "$(readlink "$CODEBUDDY_HOME")" != "$PERSIST_DIR" ]; then
    rm -rf "$CODEBUDDY_HOME" 2>/dev/null
    ln -sf "$PERSIST_DIR" "$CODEBUDDY_HOME"
    echo "[CodeBuddy] 数据已挂载到持久化目录: $PERSIST_DIR"
fi
