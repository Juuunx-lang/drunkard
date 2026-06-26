# Production Deployment Guide

This guide describes a Docker Compose deployment that does not interfere with existing projects on the same server.

## Recommended Server Layout

```text
/opt/drunkard/
├── app/build/web/                 # Flutter Web build
├── backend/                       # Backend source and Dockerfile
├── data/postgres/                 # PostgreSQL data directory
├── docker-compose.prod.yml
├── nginx.conf
└── .env.production
```

Do not store production secrets in Git.

## Port Strategy

If the server already runs another website on `80` or `443`, bind Drunkard to a separate port:

```yaml
ports:
  - "18080:80"
```

Then access:

```text
http://YOUR_SERVER_IP:18080/
```

If a host-level reverse proxy is available, use:

```yaml
ports:
  - "127.0.0.1:18080:80"
```

and proxy a domain to `127.0.0.1:18080`.

## Prepare Production Files

On the server:

```bash
mkdir -p /opt/drunkard
cd /opt/drunkard
```

Copy these files from the repository:

```text
backend/
app/build/web/
docker-compose.prod.example.yml
nginx.conf
.env.production.example
```

Rename:

```bash
cp docker-compose.prod.example.yml docker-compose.prod.yml
cp .env.production.example .env.production
```

Edit `.env.production`:

```env
NODE_ENV=production
DB_PASSWORD=<strong database password>
JWT_SECRET=<long random secret>
INVITE_CODE=<private invite code>
ADMIN_PHONE=<admin phone>
ADMIN_PASSWORD=<admin password>
SERVER_URL=http://YOUR_SERVER_IP:18080
FRONTEND_URL=http://YOUR_SERVER_IP:18080
CORS_ORIGINS=http://YOUR_SERVER_IP:18080
WECHAT_APP_ID=
WECHAT_APP_SECRET=
```

Generate a JWT secret:

```bash
openssl rand -base64 48
```

## Build Web Locally

From the repository root:

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

Upload `app/build/web` to:

```text
/opt/drunkard/app/build/web
```

## Start Production Stack

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build
```

Check:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
curl http://127.0.0.1:18080/api/health
```

Public test:

```bash
curl -I http://YOUR_SERVER_IP:18080/
```

## Updating Web Only

Build locally:

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

Upload the new `app/build/web` directory to the server, then recreate Nginx:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate nginx
```

## Updating Backend

Upload the changed backend source, then rebuild:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build app nginx
```

## Build Android APK for Production

For IP + port deployment:

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

For domain + HTTPS:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

## Coexisting With Existing Projects

To avoid affecting an existing project:

- Do not modify the existing project directory.
- Do not overwrite existing host Nginx files.
- Do not use host ports already used by another project.
- Keep Drunkard in `/opt/drunkard`.
- Bind Drunkard to `18080` or another free port.
- Keep Drunkard Docker Compose project name as `drunkard`.

Useful checks:

```bash
ss -lntp
docker ps
ls -la /etc/nginx/conf.d
```

## HTTPS Recommendation

For real users, use HTTPS. Mobile browsers and APK traffic are safer and more reliable with TLS.

Typical options:

- Bind Drunkard internally to `127.0.0.1:18080`.
- Use host Nginx, Caddy, or a cloud load balancer.
- Add a domain and TLS certificate.
- Set `SERVER_URL`, `FRONTEND_URL`, and `CORS_ORIGINS` to the HTTPS domain.
