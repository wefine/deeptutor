# DeepTutor 自定义改动清单

> 记录所有对上游 DeepTutor 的定制化修改，便于版本升级时重新应用。
> 
> 上游仓库: `https://github.com/HKUDS/DeepTutor`
> 自定义分支: `origin/mine`（基于 origin/main，force push 覆盖）
> 当前版本: v1.3.9

---

## 一、后端 Python 改动

### 1. require_auth / require_admin 同步改异步

**文件**: `deeptutor/api/routers/auth.py`

**改动**: `def require_auth(...)` → `async def require_auth(...)`
        `def require_admin(...)` → `async def require_admin(...)`

**原因**: 这两个函数内部调用 `set_current_user()` 写入 `ContextVar`。FastAPI 对同步依赖函数在线程池中执行，而 async endpoint 在主 event loop 中执行，两者的 `ContextVar` 不共享。导致多用户模式下所有 API（如 `/api/v1/knowledge/list`）读到 `current_user=None`，用户数据全部丢失。

**上游合并风险**: 低。如果上游也改为 async 或用其他方式传递用户上下文，此改动可丢弃。

---

### 2. 新增 /api/version 端点

**文件**: `deeptutor/api/main.py`

**改动**: 在 `app = FastAPI(...)` 之后、middleware 之前插入 `@app.get("/api/version")` 端点。

**逻辑**:
- 读取环境变量 `APP_VERSION`（如 `v1.3.9`）
- 用正则解析 semver，返回与前端 `ParsedBuild` 接口兼容的字段（tag, display, isDev, isDirty, commitsAhead, commit）
- 前端 `VersionBadge` 组件 fetch `/api/version`，依赖 `current.tag` 和 `current.display` 字段

**原因**: 上游版本号显示依赖 GitHub API 获取 latest release（私有部署不可用）。此端点让版本号从环境变量注入，无需外部 API 调用。

**上游合并风险**: 低。新增代码，不影响现有逻辑。若上游自行实现版本端点，需替换。

---

## 二、前端改动

### 3. 登录页/注册页：允许用户名登录

**文件**: 
- `web/app/(auth)/login/page.tsx`
- `web/app/(auth)/register/page.tsx`

**改动**: 两处 `<input>` 的 `type="email"` → `type="text"`，`autoComplete="email"` → `autoComplete="username"`

**原因**: 后端 `authenticate()` 支持用户名登录，但前端 `type="email"` 会触发浏览器强制邮箱格式验证，导致非邮箱用户名无法提交。

**上游合并风险**: 低。仅改 input type，不影响表单逻辑。等上游支持 i18n 登录页后可能不再需要。

---

### 4. 侧边栏：GitHub 图标替换为退出/管理按钮

**文件**:
- `web/components/sidebar/SidebarShell.tsx`
- `web/components/sidebar/WorkspaceSidebar.tsx`
- `web/components/sidebar/UtilitySidebar.tsx`

**改动**:
- `SidebarShell.tsx`:
  - 移除 `Github` import、`GITHUB_REPO_URL` 常量、`ReactNode` import
  - 移除 `footerSlot` prop 及所有引用
  - 引入 `LogoutButton`、`AdminLink`
  - collapsed 和 expanded 两种状态下，底部用 `<AdminLink collapsed />` + `<LogoutButton collapsed />` 替换 GitHub `<a>` 链接
- `WorkspaceSidebar.tsx`: 移除 `footerSlot` prop 传入、移除 `AdminLink`/`LogoutButton` import
- `UtilitySidebar.tsx`: 同上

**原因**: 私有部署不需要 GitHub 链接；退出按钮和管理链接统一放在侧边栏底部，和版本号并排。

**上游合并风险**: 中。SidebarShell 结构变化较大，需手动 merge。

---

### 5. 默认语言改为中文

**文件**:
- `web/context/app-shell-storage.ts`
- `web/context/AppShellContext.tsx`
- `web/i18n/init.ts`

**改动**:
- `app-shell-storage.ts`: `readStoredLanguage()` 的两个 fallback `"en"` → `"zh"`
- `AppShellContext.tsx`: `useState<AppLanguage>("en")` → `"zh"`，注释改为 "Start with zh"
- `init.ts`: `normalizeLanguage()` 空值 fallback `"en"` → `"zh"`

**原因**: 默认用户是中国用户，首次打开应为中文界面。

**上游合并风险**: 低。纯字符串替换。

---

## 三、Docker 构建改动

### 6. Dockerfile: AUTH_ENABLED 构建参数

**文件**: `Dockerfile`

**改动**: 在 `frontend-builder` 阶段（约第 28 行）添加:
```dockerfile
ARG AUTH_ENABLED=false
ENV NEXT_PUBLIC_AUTH_ENABLED=$AUTH_ENABLED
```

**原因**: `LogoutButton.tsx` 中 `if (!AUTH_ENABLED) return null`，`AUTH_ENABLED` 是构建时常量（`NEXT_PUBLIC_AUTH_ENABLED`），不在 Dockerfile 声明 ARG 则构建产物中永远为 `false`，退出按钮永远不显示。

**构建命令**:
```bash
docker build --target production \
  --build-arg AUTH_ENABLED=true \
  --build-arg APP_VERSION=v1.3.9 \
  -t 192.168.1.36:5000/deeptutor/app:1.3.9-arm64 .
```

**上游合并风险**: 低。纯增量添加。

---

## 四、新增文件（非修改上游）

| 文件 | 用途 |
|------|------|
| `.env.prod` | VM 生产环境变量（AUTH_SECRET, JWT_SECRET, APP_VERSION 等） |
| `docker-compose.multi-user.yml` | 多用户单实例 compose 配置 |
| `scripts/migrate-miya-data.sh` | miya 数据迁移脚本（一次性，可删） |
| `scripts/migrate-to-multi-user.sh` | 通用迁移脚本（一次性，可删） |

---

## 五、版本升级流程

```bash
# 1. 拉取上游最新代码
cd ~/Gits/deeptutor
git fetch upstream
git checkout main
git merge upstream/main

# 2. 逐一重新应用上述改动（按顺序）
#    改动 1: auth.py — require_auth/require_admin 改 async
#    改动 2: main.py — /api/version 端点
#    改动 3: login/register — type="text"
#    改动 4: SidebarShell — 移除 GitHub，加 LogoutButton/AdminLink
#    改动 5: 默认语言 zh
#    改动 6: Dockerfile — AUTH_ENABLED ARG

# 3. 构建新版本镜像（替换版本号）
docker build --target production \
  --build-arg AUTH_ENABLED=true \
  --build-arg APP_VERSION=vX.Y.Z \
  -t 192.168.1.36:5000/deeptutor/app:X.Y.Z-arm64 .

# 4. Push + 部署
docker push 192.168.1.36:5000/deeptutor/app:X.Y.Z-arm64
scp .env.prod prod-server:/opt/projects/deeptutor/.env.prod
ssh prod-server "cd /opt/projects/deeptutor && \
  sed -i 's/X.Y.Z-arm64/X.Y.Z-arm64/' docker-compose.prod.yml && \
  docker compose -f docker-compose.prod.yml pull && \
  docker compose -f docker-compose.prod.yml up -d --force-recreate"

# 5. 保存到 mine 分支
git add -A && git commit -m "custom: rebase onto vX.Y.Z"
git push origin main:mine --force
```
