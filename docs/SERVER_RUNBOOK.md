# Server Runbook

This runbook is a safe, sanitized reference for operating Drunkard on a Linux server.

It intentionally does not include real passwords, private keys, production secrets, or personal phone numbers.

## Server Assumptions

- Drunkard project directory: `/opt/drunkard`
- Docker Compose project name: `drunkard`
- Public HTTP port: `18080`
- Internal API port: `3000`
- PostgreSQL is only available inside the Docker network.

## Daily Health Check

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
curl http://127.0.0.1:18080/api/health
curl -I http://127.0.0.1:18080/
```

Expected:

- `db` is healthy.
- `app` is up.
- `nginx` is up.
- `/api/health` returns `{"status":"ok","env":"production"}`.
- Web entry returns `200`.

## Start / Restart

Start:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d
```

Restart Nginx only:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

Rebuild backend and restart:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

Stop:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml down
```

## Logs

Backend:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
```

Nginx:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f nginx
```

Database:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f db
```

Recent logs:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs --tail=200 app
```

## Deploy Web Update

Build locally:

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

Upload the build to the server and replace:

```bash
cd /opt/drunkard
rm -rf app/build/web
mkdir -p app/build
# copy the new web build to app/build/web
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

Verify:

```bash
curl -I http://127.0.0.1:18080/
```

## Deploy Backend Update

Upload backend changes, then:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
curl http://127.0.0.1:18080/api/health
```

## Build and Distribute APK

Build from local workstation:

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

APK output:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

Distribute the APK through a trusted private channel.

## Backup

Create database backup:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec db \
  pg_dump -U drunkard drunkard > backup-drunkard-$(date +%F).sql
```

Create uploads backup:

```bash
docker run --rm \
  -v drunkard_uploads:/uploads:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/backup-uploads-$(date +%F).tar.gz /uploads
```

## Cleanup

Check disk:

```bash
df -h
docker system df
```

Prune unused Docker build cache carefully:

```bash
docker builder prune
```

Do not delete:

- `/opt/drunkard/data/postgres`
- Docker uploads volume
- `.env.production`
- recent backups

## Emergency Rollback

Recommended approach:

1. Keep a zip/tar copy of the previous `app/build/web`.
2. Keep backend source snapshots before deployment.
3. Restore previous Web build or backend source.
4. Recreate affected containers.

Web rollback:

```bash
cd /opt/drunkard
rm -rf app/build/web
# copy previous web build to app/build/web
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

Backend rollback:

```bash
cd /opt/drunkard
# restore previous backend source
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

## Known Notes

- iOS Safari can feel less smooth than Android APK or desktop browsers because of Flutter Web rendering limitations.
- The `/wasm/` performance experiment was removed because it did not provide a meaningful improvement.
- WeChat quick login is intentionally hidden until valid WeChat platform credentials and approval are available.
