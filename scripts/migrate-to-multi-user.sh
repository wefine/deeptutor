#!/bin/bash
# ============================================================
# DeepTutor v1.3.8 多用户迁移脚本
#
# 功能：
#   1. 停止旧的 wefine/miya 双容器
#   2. 重组 Mac 共享盘上的数据目录
#      - wefine → data/（admin 工作空间）
#      - miya   → _migration_backup/miya/（暂存，等注册后迁移）
#   3. 创建 multi-user/ 目录结构
#   4. 上传新的 compose 和 .env 到 VM
#   5. 启动新容器
#
# 用法：
#   cd ~/Gits/deeptutor
#   bash scripts/migrate-to-multi-user.sh
#
# 数据目录位置（Mac 共享盘，VM 通过 vmhgfs-fuse 访问）：
#   Mac:   /Volumes/Lexar4T/docker-data-prod/deeptutor/
#   VM:    /mnt/hgfs/docker-data-prod/deeptutor/
# ============================================================

set -euo pipefail

# ---- 配置 ----
MAC_DATA_ROOT="/Volumes/Lexar4T/docker-data-prod/deeptutor"
VM_DATA_ROOT="/mnt/hgfs/docker-data-prod/deeptutor"
VM_COMPOSE_DIR="/opt/projects/deeptutor"
SSH_HOST="prod-server"

echo "============================================"
echo " DeepTutor v1.3.8 多用户迁移"
echo "============================================"
echo ""

# ---- 检查 Mac 共享盘 ----
if [ ! -d "$MAC_DATA_ROOT/data/wefine" ] || [ ! -d "$MAC_DATA_ROOT/data/miya" ]; then
    echo "[ERROR] 找不到 wefine/miya 数据目录：$MAC_DATA_ROOT/data/"
    exit 1
fi

echo "[1/7] 停止 VM 上的旧容器..."
ssh $SSH_HOST "cd $VM_COMPOSE_DIR && docker compose -f docker-compose.prod.yml down" 2>/dev/null || true
echo "  旧容器已停止。"
echo ""

echo "[2/7] 备份旧数据..."
BACKUP_DIR="$MAC_DATA_ROOT/_migration_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "  备份目录：$BACKUP_DIR"
echo ""

echo "[3/7] 重组数据目录..."
cd "$MAC_DATA_ROOT"

# 3a. 将 wefine 的数据提升到 data/ 根目录
# 旧结构: data/wefine/{user,memory,knowledge_bases}
# 新结构: data/{user,memory,knowledge_bases}
echo "  3a. wefine → data/ (admin 工作空间)..."

# 备份原有 wefine 数据
cp -a "data/wefine" "$BACKUP_DIR/wefine"

# 如果 data/ 下已有旧的 data/ 子目录（来自本地开发），先移开
if [ -d "data/user" ]; then
    echo "    发现已有 data/user，移到备份..."
    mv "data/user" "$BACKUP_DIR/old_data_user"
fi
if [ -d "data/memory" ]; then
    mv "data/memory" "$BACKUP_DIR/old_data_memory"
fi
if [ -d "data/knowledge_bases" ]; then
    mv "data/knowledge_bases" "$BACKUP_DIR/old_data_knowledge_bases"
fi

# 移动 wefine 的数据到 data/ 根目录
mv "data/wefine/user" "data/user"
mv "data/wefine/memory" "data/memory"
mv "data/wefine/knowledge_bases" "data/knowledge_bases"

echo "    完成: data/{user,memory,knowledge_bases} ← wefine"
echo ""

# 3b. 将 miya 的数据暂存到备份目录
echo "  3b. miya → 备份暂存..."
cp -a "data/miya" "$BACKUP_DIR/miya_active"
echo "    miya 数据已备份到 $BACKUP_DIR/miya_active"
echo "    原始数据保留在 data/miya/（注册后迁移到 multi-user/<uid>/）"
echo ""

# 3c. 创建 multi-user 目录结构
echo "  3c. 创建 multi-user/_system/ 目录..."
mkdir -p "multi-user/_system/auth"
mkdir -p "multi-user/_system/grants"
mkdir -p "multi-user/_system/audit"
mkdir -p "multi-user/_system/indexes"
echo "    完成。"
echo ""

echo "[4/7] 上传配置到 VM..."
# 上传新的 compose 和 .env
scp docker-compose.multi-user.yml $SSH_HOST:$VM_COMPOSE_DIR/docker-compose.prod.yml
scp .env.prod $SSH_HOST:$VM_COMPOSE_DIR/.env.prod
echo "  配置已上传。"
echo ""

echo "[5/7] 启动新容器..."
ssh $SSH_HOST "cd $VM_COMPOSE_DIR && docker compose -f docker-compose.prod.yml up -d"
echo "  新容器已启动。"
echo ""

echo "[6/7] 等待后端就绪..."
for i in $(seq 1 30); do
    if ssh $SSH_HOST "curl -sf http://localhost:8001/ > /dev/null 2>&1"; then
        echo "  后端已就绪。"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  [WARN] 后端 30s 内未就绪，请手动检查。"
    fi
    sleep 1
done
echo ""

echo "[7/7] 后续步骤（请手动完成）："
echo ""
echo "  a. 浏览器打开 https://deeptutor.home/register"
echo "     注册 wefine（第一个用户自动成为 admin）"
echo ""
echo "  b. 注册后，查看分配的 wefine user_id："
echo "     ssh $SSH_HOST 'cat $VM_DATA_ROOT/multi-user/_system/auth/users.json'"
echo ""
echo "  c. 用 admin 账号登录，在 /admin/users 页面创建 miya 用户"
echo "     或让 miya 自己去 /register 注册"
echo ""
echo "  d. 查看 miya 的 user_id 后，运行数据迁移："
echo "     cd ~/Gits/deeptutor"
echo "     bash scripts/migrate-miya-data.sh <miya_user_id>"
echo ""
echo "  e. 在 /admin/users 页面给 miya 分配模型和知识库权限"
echo ""
echo "============================================"
echo " 迁移准备完成！"
echo "============================================"
