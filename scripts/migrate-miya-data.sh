#!/bin/bash
# ============================================================
# 迁移 miya 的历史数据到 multi-user/<uid>/ 工作空间
#
# 前置条件：
#   1. 已完成 migrate-to-multi-user.sh
#   2. miya 已通过 /register 注册，获得 user_id
#
# 用法：
#   bash scripts/migrate-miya-data.sh <miya_user_id>
#   例如：bash scripts/migrate-miya-data.sh u_a1b2c3d4e5f6
# ============================================================

set -euo pipefail

MIYA_UID="${1:?用法: $0 <miya_user_id>}"

MAC_DATA_ROOT="/Volumes/Lexar4T/docker-data-prod/deeptutor"
MIYA_SRC="$MAC_DATA_ROOT/data/miya"
MIYA_DST="$MAC_DATA_ROOT/multi-user/$MIYA_UID"

echo "============================================"
echo " 迁移 miya 数据"
echo "============================================"
echo "  源: $MIYA_SRC"
echo "  目标: $MIYA_DST"
echo ""

if [ ! -d "$MIYA_SRC/user" ]; then
    echo "[ERROR] 找不到 miya 数据: $MIYA_SRC/user"
    exit 1
fi

if [ -z "$MIYA_UID" ]; then
    echo "[ERROR] user_id 不能为空"
    exit 1
fi

# 创建目标目录结构
echo "[1/4] 创建目标目录..."
mkdir -p "$MIYA_DST/user/settings"
mkdir -p "$MIYA_DST/user/workspace"
mkdir -p "$MIYA_DST/user/logs"
mkdir -p "$MIYA_DST/knowledge_bases"
mkdir -p "$MIYA_DST/memory"
echo "  完成。"
echo ""

# 复制 chat_history.db
echo "[2/4] 复制 chat_history.db..."
if [ -f "$MIYA_SRC/user/chat_history.db" ]; then
    cp -a "$MIYA_SRC/user/chat_history.db" "$MIYA_DST/user/chat_history.db"
    SIZE=$(du -h "$MIYA_DST/user/chat_history.db" | cut -f1)
    echo "  已复制 ($SIZE)"
else
    echo "  无 chat_history.db，跳过。"
fi
echo ""

# 复制 settings
echo "[3/4] 复制 settings..."
if [ -d "$MIYA_SRC/user/settings" ] && [ "$(ls -A $MIYA_SRC/user/settings 2>/dev/null)" ]; then
    cp -a "$MIYA_SRC/user/settings/"* "$MIYA_DST/user/settings/"
    echo "  已复制: $(ls $MIYA_SRC/user/settings)"
else
    echo "  settings 为空，跳过。"
fi
echo ""

# 复制 workspace
echo "[4/4] 复制 workspace + knowledge_bases + memory..."
if [ -d "$MIYA_SRC/user/workspace" ]; then
    cp -a "$MIYA_SRC/user/workspace" "$MIYA_DST/user/workspace"
    echo "  workspace: 已复制"
fi

if [ -d "$MIYA_SRC/knowledge_bases" ] && [ "$(ls -A $MIYA_SRC/knowledge_bases 2>/dev/null)" ]; then
    cp -a "$MIYA_SRC/knowledge_bases/"* "$MIYA_DST/knowledge_bases/"
    echo "  knowledge_bases: $(ls $MIYA_SRC/knowledge_bases | tr '\n' ' ')"
fi

if [ -d "$MIYA_SRC/memory" ] && [ "$(ls -A $MIYA_SRC/memory 2>/dev/null)" ]; then
    cp -a "$MIYA_SRC/memory/"* "$MIYA_DST/memory/"
    echo "  memory: $(ls $MIYA_SRC/memory | tr '\n' ' ')"
fi

if [ -d "$MIYA_SRC/user/logs" ] && [ "$(ls -A $MIYA_SRC/user/logs 2>/dev/null)" ]; then
    cp -a "$MIYA_SRC/user/logs/"* "$MIYA_DST/user/logs/"
    echo "  logs: 已复制"
fi

echo ""
echo "============================================"
echo " 迁移完成！"
echo ""
echo " 后续步骤："
echo "  1. 在 /admin/users 给 miya 分配模型权限"
echo "  2. 让 miya 登录验证数据是否正常"
echo ""
echo " 如需回滚，miya 原始数据仍保留在："
echo "   $MIYA_SRC"
echo "============================================"
