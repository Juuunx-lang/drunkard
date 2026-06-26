# 运维与后续开发文档

本文用于后续维护 Drunkard，包括启动、重启、日志、备份、恢复、安全检查、发布流程和后续开发建议。

## 日常运维入口

服务器上进入项目目录：

```bash
cd /opt/drunkard
```

所有生产命令都建议在这个目录执行。

## 基础命令

启动：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d
```

重新构建：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build
```

停止：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml down
```

查看状态：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
```

健康检查：

```bash
curl http://127.0.0.1:18080/api/health
```

## 日志查看

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

最近 100 行：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 app
```

## 数据位置

默认运行数据位置：

```text
/opt/drunkard/data/postgres       # PostgreSQL 数据
Docker volume drunkard_uploads    # 上传图片
/opt/drunkard/app/build/web       # Web 静态文件
/opt/drunkard/.env.production     # 生产环境变量
```

不要误删：

- `data/postgres`
- uploads volume
- `.env.production`
- 最近备份

## 备份数据库

服务器执行：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec db \
  pg_dump -U drunkard drunkard > backup-drunkard-$(date +%F).sql
```

确认备份文件：

```bash
ls -lh backup-drunkard-*.sql
```

建议把备份下载到本地或对象存储，不要只放服务器上。

## 备份上传图片

```bash
cd /opt/drunkard
docker run --rm \
  -v drunkard_uploads:/uploads:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/backup-uploads-$(date +%F).tar.gz /uploads
```

确认：

```bash
ls -lh backup-uploads-*.tar.gz
```

## 恢复数据库

恢复前建议先停止写入或确认没有用户正在操作。

```bash
cd /opt/drunkard
cat backup-drunkard-YYYY-MM-DD.sql | docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec -T db \
  psql -U drunkard drunkard
```

恢复后检查：

```bash
curl http://127.0.0.1:18080/api/health
```

## 恢复上传图片

```bash
cd /opt/drunkard
docker run --rm \
  -v drunkard_uploads:/uploads \
  -v "$PWD:/backup" \
  alpine sh -c "cd / && tar xzf /backup/backup-uploads-YYYY-MM-DD.tar.gz"
```

## 发布流程建议

### 只改前端

1. 本地构建 Web：

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

2. 上传 `app/build/web`。

3. 服务器重启 Nginx：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

4. 验证网页：

```bash
curl -I http://127.0.0.1:18080/
```

### 改了后端

1. 本地检查：

```bash
cd backend
npm run build
```

2. 上传后端源码。

3. 服务器重建：

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

4. 验证：

```bash
curl http://127.0.0.1:18080/api/health
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 app
```

### 改了数据库结构

当前生产 Compose 使用：

```bash
npx prisma db push
```

这对私人项目比较方便，但更正式的做法是 Prisma migration：

```bash
cd backend
npx prisma migrate dev --name change_name
npx prisma migrate deploy
```

如果未来开源多人协作，建议迁移到 migration 流程。

## 管理员操作建议

管理员可以在 App 内 GUI 管理：

- 用户
- 酒品
- 酒类分类
- 原料库存
- 订单
- 评论
- 社区内容

除非紧急恢复数据，不建议直接进入数据库手动修改。

## 图片上传维护

用户上传图片和酒品图片会进入后端 uploads volume，并由 Nginx 对外提供访问。

注意：

- 上传目录需要备份。
- 上传文件不要进 Git。
- 如果后续用户变多，需要考虑定期清理孤儿图片。
- 大图应继续保持裁剪和压缩流程。

## 实时同步维护

项目使用 Socket.IO 实时同步：

- 新订单
- 订单状态
- 吧台状态
- 酒单、分类、库存变化
- 评论和社区内容更新

如果实时同步异常：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
```

同时检查 Nginx 是否正确代理：

```text
/socket.io/
```

## 安全维护

定期检查：

- `.env.production` 没有进 Git。
- 数据库 `5432` 没有暴露公网。
- 后端 `3000` 没有暴露公网。
- `JWT_SECRET` 不是默认值或弱密码。
- 管理员密码不是公开默认值。
- CORS 白名单不是无限开放。
- 服务器防火墙只开放必要端口。

## 故障处理

### 网页打不开

检查：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
curl -I http://127.0.0.1:18080/
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 nginx
```

### API 失败

检查：

```bash
curl http://127.0.0.1:18080/api/health
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 app
```

### 数据库异常

检查：

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=100 db
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
```

### 磁盘不足

检查：

```bash
df -h
docker system df
```

谨慎清理：

```bash
docker builder prune
```

不要删除数据库目录和 uploads volume。

## 后续开发建议

优先级建议：

1. 增加域名和 HTTPS。
2. 把 Prisma `db push` 改成 migration deploy。
3. 补充后端自动化测试，尤其是订单状态、权限、登录注册。
4. 增加上传图片的后台清理机制。
5. 如果 iPhone 体验很重要，考虑 iOS 原生 App 或壳应用。
6. 管理员的删除和修改操作增加审计日志。
7. 社区内容增加举报、置顶、搜索排序等能力。
8. 酒单增加季节推荐和活动专题。

## GitHub 开源检查

上传前确认删除：

- `.local-dev/`
- SSH 私钥
- 部署临时 zip
- `.env.production`
- 数据库备份
- 用户上传图片
- 真实手机号、邀请码、服务器密码

可以保留：

- `.env.production.example`
- `docker-compose.prod.example.yml`
- `nginx.conf`
- `docs/`
- 源码
