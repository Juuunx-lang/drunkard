# 生产部署文档

本文说明如何把 Drunkard 部署到 Linux 服务器，并尽量不影响服务器上已有项目。

## 部署目标

推荐部署结果：

```text
用户浏览器 / Android APK
  -> http://YOUR_SERVER_IP:18080
  -> Drunkard Nginx 容器
  -> /api 反代到 Node.js 后端
  -> /socket.io 反代到 Socket.IO
  -> PostgreSQL 容器内网访问
```

如果未来有域名和 HTTPS，可以把 `18080` 放到内网端口，由宿主机 Nginx/Caddy 统一反代。

## 推荐服务器目录

建议固定为：

```text
/opt/drunkard
```

目录结构：

```text
/opt/drunkard/
├── app/
│   └── build/
│       └── web/                 # Flutter Web 构建产物
├── backend/                     # 后端源码和 Dockerfile
├── data/
│   └── postgres/                # PostgreSQL 数据
├── docker-compose.prod.yml
├── nginx.conf
└── .env.production
```

不要把 `.env.production` 上传 GitHub。

## 部署前检查

服务器上检查 Docker：

```bash
docker --version
docker compose version
```

检查磁盘：

```bash
df -h
```

检查内存：

```bash
free -h
```

检查端口占用：

```bash
ss -lntp
```

如果服务器已有项目，重点确认不要占用已有项目的 `80`、`443` 或其他关键端口。

## 端口策略

如果服务器已有项目占用了 `80` 或 `443`，不要抢占它们。

Drunkard 可以绑定到单独端口：

```yaml
ports:
  - "18080:80"
```

访问地址：

```text
http://YOUR_SERVER_IP:18080/
```

如果以后使用宿主机 Nginx、Caddy 或宝塔反代，推荐改成：

```yaml
ports:
  - "127.0.0.1:18080:80"
```

然后由宿主机反代到：

```text
127.0.0.1:18080
```

## 准备生产目录

服务器执行：

```bash
mkdir -p /opt/drunkard
cd /opt/drunkard
```

需要上传这些内容：

```text
backend/
app/build/web/
docker-compose.prod.example.yml
nginx.conf
.env.production.example
```

复制并重命名：

```bash
cp docker-compose.prod.example.yml docker-compose.prod.yml
cp .env.production.example .env.production
```

## 配置生产环境变量

编辑：

```bash
nano .env.production
```

示例：

```env
NODE_ENV=production
DB_PASSWORD=<强数据库密码>
JWT_SECRET=<长随机 JWT 密钥>
INVITE_CODE=<私有邀请码>
ADMIN_PHONE=<管理员手机号>
ADMIN_PASSWORD=<管理员密码>
SERVER_URL=http://YOUR_SERVER_IP:18080
FRONTEND_URL=http://YOUR_SERVER_IP:18080
CORS_ORIGINS=http://YOUR_SERVER_IP:18080
WECHAT_APP_ID=
WECHAT_APP_SECRET=
```

生成 JWT 密钥：

```bash
openssl rand -base64 48
```

注意：

- `JWT_SECRET` 不能用默认值。
- `DB_PASSWORD` 不能用简单密码。
- `ADMIN_PASSWORD` 上线前必须改。
- 微信相关变量暂时可以留空。

## 本地构建 Web

在本地项目根目录执行：

```bash
cd app
flutter pub get
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

构建完成后得到：

```text
app/build/web
```

把这个目录上传到服务器：

```text
/opt/drunkard/app/build/web
```

## 启动生产服务

服务器执行：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build
```

第一次启动会构建后端镜像，可能较慢。

查看容器状态：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
```

正常应该有：

```text
drunkard-app-1
drunkard-db-1
drunkard-nginx-1
```

其中数据库应为 healthy。

## 部署后验证

服务器本机检查：

```bash
curl http://127.0.0.1:18080/api/health
curl -I http://127.0.0.1:18080/
```

外部电脑检查：

```bash
curl -I http://YOUR_SERVER_IP:18080/
```

浏览器打开：

```text
http://YOUR_SERVER_IP:18080/
```

如果网页能打开，但登录失败，检查：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
```

## 只更新前端

适合只改 Flutter 页面、样式、交互时使用。

本地重新构建：

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

上传新的 `app/build/web` 到服务器后：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

验证：

```bash
curl -I http://127.0.0.1:18080/
```

## 更新后端

适合改接口、数据库逻辑、权限、订单、上传等后端代码时使用。

上传后端源码后：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

验证：

```bash
curl http://127.0.0.1:18080/api/health
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 app
```

## 构建 APK

IP + 端口部署：

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

域名 + HTTPS 部署：

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

APK 输出：

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

如果 APK 显示连不上吧台，首先确认构建时的 `API_BASE_URL` 是否正确。

## 与服务器旧项目共存

为了不影响旧项目：

- 不修改旧项目目录。
- 不覆盖宿主机已有 Nginx 配置。
- 不占用旧项目正在使用的端口。
- Drunkard 固定放在 `/opt/drunkard`。
- Docker Compose 项目名固定为 `drunkard`。
- 使用 `18080` 或其他空闲端口。

检查旧项目：

```bash
ls -la /opt
ls -la /etc/nginx/conf.d
ss -lntp
docker ps
```

## 防火墙和安全组

如果用 IP + `18080` 访问，需要在云服务器安全组或防火墙开放：

```text
TCP 18080
```

不建议开放：

```text
3000
5432
```

因为：

- `3000` 是后端内部端口，应由 Nginx 反代。
- `5432` 是数据库端口，不应暴露公网。

## HTTPS 建议

真实使用建议配置 HTTPS，尤其是移动浏览器和 APK。

推荐方式：

- Drunkard 只绑定 `127.0.0.1:18080`。
- 宿主机 Nginx/Caddy 绑定域名和证书。
- 反代到 `127.0.0.1:18080`。
- `.env.production` 中 `SERVER_URL`、`FRONTEND_URL`、`CORS_ORIGINS` 改成 HTTPS 域名。

## 部署检查清单

上线前确认：

- `.env.production` 已配置。
- `JWT_SECRET` 是强随机字符串。
- 数据库密码不是简单密码。
- 管理员密码已修改。
- `app/build/web` 是最新构建产物。
- `docker compose ps` 中容器正常。
- `/api/health` 正常。
- Web 首页能打开。
- APK 使用正确的 `API_BASE_URL` 构建。
- 服务器没有暴露 `5432`。
- 服务器没有直接暴露 `3000`。
