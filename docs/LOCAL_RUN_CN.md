# 本地运行文档

本文是一份可以照着执行的本地运行手册，目标是让你在自己的电脑上启动 Drunkard，完成浏览器测试、后端接口测试和 APK 构建。

## 本地运行包含什么

Drunkard 本地运行通常包含三部分：

```text
PostgreSQL 数据库
  -> Node.js 后端 API
  -> Flutter Web 前端
```

本地测试时，常见访问地址是：

```text
http://127.0.0.1:8080
```

后端接口地址通常是：

```text
http://127.0.0.1:3000/api
```

## 环境要求

建议安装：

- Docker Desktop
- Flutter SDK
- Node.js LTS
- Git
- Android Studio 或 Android SDK，如果需要构建 APK

Windows 下打开 PowerShell，确认这些命令可用：

```powershell
docker --version
docker compose version
flutter --version
node --version
npm --version
git --version
```

如果某个命令不可用，说明没有安装或没有加入 `PATH`。

## 最推荐：一键启动

在项目根目录执行：

```bat
start-local.cmd
```

启动完成后打开：

```text
http://127.0.0.1:8080
```

停止服务：

```bat
stop-local.cmd
```

如果一键脚本失败，不要先删除项目或 Docker 数据，先按下面步骤排查是哪一层失败。

## 手动启动：检查 Docker

确认 Docker Desktop 已启动：

```powershell
docker ps
```

如果提示 Docker daemon 连接不上，一般是 Docker Desktop 没启动或还没初始化完成。

## 手动启动：设置本地环境变量

本地 Compose 需要一些环境变量。可以在 PowerShell 当前窗口临时设置：

```powershell
$env:NODE_ENV="development"
$env:DB_PASSWORD="drunkard_dev_password"
$env:JWT_SECRET="replace_with_local_dev_secret"
$env:SERVER_URL="http://127.0.0.1:3000"
$env:FRONTEND_URL="http://127.0.0.1:8080"
$env:WECHAT_APP_ID=""
$env:WECHAT_APP_SECRET=""
```

这些只是本地开发值，不要用于生产环境。

## 手动启动：启动 Docker 服务

项目根目录执行：

```powershell
docker compose up -d --build
```

查看容器：

```powershell
docker compose ps
```

查看后端日志：

```powershell
docker compose logs -f app
```

查看数据库日志：

```powershell
docker compose logs -f db
```

## 手动启动：检查后端健康

```powershell
curl http://127.0.0.1:3000/api/health
```

正常应该返回类似：

```json
{"status":"ok","env":"development"}
```

如果不是，优先看后端日志。

## 手动启动：启动 Flutter Web

进入 Flutter 项目：

```powershell
cd app
flutter pub get
```

开发运行：

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

如果你不想用 `flutter run`，也可以构建静态资源：

```powershell
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

构建输出：

```text
app/build/web
```

## 本地注册和登录

注册时需要：

- 手机号
- 顾客名
- 邀请码
- 密码
- 确认密码

管理员账号由环境变量控制，不应该写死在文档或源码里。

如果忘记测试账号密码，可以通过管理员 GUI 或数据库维护能力修改。修改后如果登录失败，要确认后端是否真的保存了新密码哈希，而不是只改了显示字段。

## 构建 Web 生产包

```powershell
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

用于部署的目录：

```text
app/build/web
```

Web 默认 API 地址是：

```text
/api
```

这表示它依赖 Nginx 同源反代。上线部署时这是推荐方式。

## 构建 APK

APK 不能使用 `/api` 这种相对路径，必须指定完整服务器地址。

IP + 端口：

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

域名 + HTTPS：

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

输出：

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

复制一份方便分发：

```powershell
Copy-Item app\build\app\outputs\flutter-apk\app-release.apk dist\drunkard-release.apk -Force
```

## 常见问题排查

### 网页白屏

优先检查：

```powershell
curl http://127.0.0.1:3000/api/health
```

再检查浏览器控制台是否有：

- `main.dart.js` 加载失败
- API 401
- API 500
- CORS 错误
- 静态资源 404

常用清理：

```powershell
cd app
flutter clean
flutter pub get
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

然后关闭旧浏览器标签，重新打开。

### 登录后马上回登录页

通常和以下问题有关：

- token 没写入本地存储
- 后端返回 401
- 前端调用了错误 API 地址
- 本地缓存里有旧 token

可尝试：

- 清浏览器缓存。
- 关闭旧标签。
- 重新启动后端。
- 检查 `/api/auth/login` 返回。

### APK 显示吧台暂时连不上

大概率是 APK 构建时没有指定完整 API 地址。

重新构建：

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

注意手机必须能访问这个服务器地址。

### Docker 后端起不来

查看：

```powershell
docker compose logs -f app
```

常见原因：

- `JWT_SECRET` 没设置。
- 数据库密码没设置。
- 数据库还没 ready。
- Prisma 初始化失败。
- 端口被占用。

### 端口冲突

查看占用：

```powershell
netstat -ano | findstr :3000
netstat -ano | findstr :8080
netstat -ano | findstr :5432
```

如果端口被别的程序占用，需要停止对应程序或修改 Compose/脚本端口。

### Flutter 图标或字体警告

如果只是 Noto 字体缺失或 tree-shaking 提示，通常不影响构建和使用。

如果登录页按钮图标无法显示，需要检查：

- 图标是否来自 Material/Cupertino 字体。
- 是否误删了图标字体。
- 是否开启了导致图标被错误裁剪的构建参数。

### iPhone Safari 帧率低

这是 Flutter Web 在 iOS Safari 上的现实限制。本项目曾测试 WASM 构建，没有明显改善，最终撤掉。

建议：

- Android 用户优先使用 APK。
- iPhone 用户可使用 Web，但不要强求原生级动画。
- 后续如果必要，再做 iOS 原生版或壳应用。

## 本地开发建议

开发时尽量遵守：

- 后端改接口后先跑 `npm run build`。
- Flutter 改页面后先跑 `flutter analyze`。
- 不要把 `.env.production`、上传图片、数据库备份提交到 Git。
- 新功能尽量同时考虑顾客端和管理员端。
- 修改订单、登录、权限相关逻辑时优先做回归测试。
