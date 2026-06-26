# 服务器运维手册

本文是 Drunkard 服务器日常运维手册，使用占位示例展示常见部署、检查、备份和恢复流程。

## 服务器约定

默认约定：

- Drunkard 目录：`/opt/drunkard`
- Docker Compose 项目名：`drunkard`
- 公网 HTTP 端口：`18080`
- 后端容器端口：`3000`
- PostgreSQL 只在 Docker 内网访问

## 每日健康检查

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
curl http://127.0.0.1:18080/api/health
curl -I http://127.0.0.1:18080/
```

正常状态：

- `db` 为 healthy。
- `app` 为 up。
- `nginx` 为 up。
- `/api/health` 返回 `{"status":"ok","env":"production"}`。
- Web 首页返回 `200`。

## 启动与重启

启动：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d
```

只重启 Nginx：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

重建后端并重启：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

停止：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml down
```

## 日志

后端日志：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
```

Nginx 日志：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f nginx
```

数据库日志：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f db
```

最近 200 行后端日志：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=200 app
```

## 发布前端更新

本地构建：

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

上传并替换服务器目录：

```bash
cd /opt/drunkard
rm -rf app/build/web
mkdir -p app/build
# 将新的 web 构建产物复制到 app/build/web
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

验证：

```bash
curl -I http://127.0.0.1:18080/
```

## 发布后端更新

上传后端源码后：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
curl http://127.0.0.1:18080/api/health
```

## 构建和分发 APK

本地构建：

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

APK 输出：

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

建议通过可信私有渠道分发 APK。

## 备份

数据库备份：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec db \
  pg_dump -U drunkard drunkard > backup-drunkard-$(date +%F).sql
```

上传图片备份：

```bash
docker run --rm \
  -v drunkard_uploads:/uploads:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/backup-uploads-$(date +%F).tar.gz /uploads
```

备份后建议下载到本地。

## 恢复

恢复数据库：

```bash
cd /opt/drunkard
cat backup-drunkard-YYYY-MM-DD.sql | docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec -T db \
  psql -U drunkard drunkard
```

恢复上传图片：

```bash
docker run --rm \
  -v drunkard_uploads:/uploads \
  -v "$PWD:/backup" \
  alpine sh -c "cd / && tar xzf /backup/backup-uploads-YYYY-MM-DD.tar.gz"
```

## 清理

查看磁盘：

```bash
df -h
docker system df
```

清理 Docker 构建缓存：

```bash
docker builder prune
```

不要删除：

- `/opt/drunkard/data/postgres`
- Docker uploads volume
- `.env.production`
- 最近的备份文件

## 紧急回滚

建议每次部署前保留：

- 上一版 `app/build/web`
- 上一版后端源码
- 最近数据库备份

前端回滚：

```bash
cd /opt/drunkard
rm -rf app/build/web
# 复制上一版 web 构建到 app/build/web
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

后端回滚：

```bash
cd /opt/drunkard
# 恢复上一版 backend 源码
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

## 事故排查顺序

如果用户反馈打不开：

1. `curl -I http://127.0.0.1:18080/`
2. `curl http://127.0.0.1:18080/api/health`
3. `docker compose ... ps`
4. `docker compose ... logs --tail=200 nginx`
5. `docker compose ... logs --tail=200 app`

如果用户反馈无法登录：

1. 检查后端日志。
2. 检查 `/api/auth/login` 是否 401 或 500。
3. 确认账号密码。
4. 确认数据库用户记录。
5. 清理浏览器旧 token 后重试。

如果用户反馈图片打不开：

1. 检查上传 volume。
2. 检查 Nginx 是否挂载 uploads。
3. 检查图片 URL 是否是服务器可访问路径。
4. 检查浏览器 Network 是否 404。

## 已知说明

- iOS Safari 上的 Flutter Web 帧率可能弱于 Android APK 和桌面浏览器，这是浏览器渲染链路限制。
- 曾测试 `/wasm/` 灰度版本，但没有明显改善，当前已撤掉。
- 微信快捷登录入口暂时隐藏，等后续具备有效微信开放平台资质后再接入。
