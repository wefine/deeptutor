# DeepTutor 自定义改动清单

> 记录所有对上游 DeepTutor 的定制化修改，便于版本升级时重新应用。
> 
> 上游仓库: `https://github.com/HKUDS/DeepTutor`
> 自定义分支: `origin/mine`（基于 upstream/main，force push 覆盖）
> 当前版本: v1.4.0

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

**改动**: 在 `selective_access_log` middleware 之后、CORS middleware 之前插入 `@app.get("/api/version")` 端点。

**逻辑**:
- 读取环境变量 `APP_VERSION`（如 `v1.4.0`）
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
- `WorkspaceSidebar.tsx` / `UtilitySidebar.tsx`: 移除 `footerSlot` prop 传入、移除 `AdminLink`/`LogoutButton` import

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
- `init.ts`: `normalizeLanguage()` 空值 fallback `"en"` → `"zh"`，`fallbackLng: "en"` → `"zh"`

**原因**: 默认用户是中国用户，首次打开应为中文界面。

**上游合并风险**: 低。纯字符串替换。

---

## 三、Docker 构建改动

### 6. AUTH_ENABLED 构建参数（v1.4.0 起上游已内置）

**文件**: `Dockerfile`

**状态**: ✅ 上游 v1.4.0 已原生支持 `AUTH_ENABLED` 和 `NEXT_PUBLIC_AUTH_ENABLED` 构建参数，无需手动修改。

**构建命令**:
```bash
docker build --target production \
  --build-arg AUTH_ENABLED=true \
  --build-arg APP_VERSION=v1.4.0 \
  -t 192.168.1.36:5000/deeptutor/app:1.4.0-arm64 .
```

---

## 四、新增文件（非修改上游）

| 文件 | 用途 |
|------|------|
| `.env.prod` | VM 生产环境变量（AUTH_SECRET, JWT_SECRET, APP_VERSION 等） |
| `docker-compose.multi-user.yml` | 多用户单实例 compose 配置 |

---

## 五、版本升级流程

```bash
# 1. 拉取上游最新代码
cd ~/Gits/deeptutor
git fetch upstream

# 2. 基于 upstream/main 重建 mine 分支
git checkout mine
git reset --hard upstream/main

# 3. 逐一重新应用上述改动（按顺序）
#    改动 1: auth.py — require_auth/require_admin 改 async
#    改动 2: main.py — /api/version 端点
#    改动 3: login/register — type="text"
#    改动 4: SidebarShell — 移除 GitHub，加 LogoutButton/AdminLink
#    改动 5: 默认语言 zh
#    改动 6: 上游已内置，无需手动修改

# 4. 恢复自有文件
git show mine@{1}:.env.prod > .env.prod
git show mine@{1}:docker-compose.multi-user.yml > docker-compose.multi-user.yml
# 更新版本号和镜像标签

# 5. 构建新版本镜像
docker build --target production \
  --build-arg AUTH_ENABLED=true \
  --build-arg APP_VERSION=vX.Y.Z \
  -t 192.168.1.36:5000/deeptutor/app:X.Y.Z-arm64 .

# 6. Push + 部署
docker push 192.168.1.36:5000/deeptutor/app:X.Y.Z-arm64
scp .env.prod docker-compose.multi-user.yml prod-server:/opt/projects/deeptutor/
ssh prod-server "cd /opt/projects/deeptutor && \
  docker compose -f docker-compose.multi-user.yml pull && \
  docker compose -f docker-compose.multi-user.yml up -d --force-recreate"

# 7. 保存到 mine 分支
git add -A && git commit -m "custom: rebase onto vX.Y.Z"
git push origin mine --force
```
