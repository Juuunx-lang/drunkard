# Local Development Guide

This guide explains how to run Drunkard locally for development and testing.

## Requirements

- Windows 10/11, macOS, or Linux
- Docker Desktop or Docker Engine
- Flutter SDK
- Node.js LTS
- Git

On Windows, make sure `docker`, `flutter`, `node`, `npm`, and `git` are available in `PATH`.

## One-Command Windows Startup

From the repository root:

```bat
start-local.cmd
```

This helper script starts the local backend/database stack and serves the Flutter Web build for browser testing.

Open:

```text
http://127.0.0.1:8080
```

Stop:

```bat
stop-local.cmd
```

## Manual Backend Startup

Create a local `.env` or export the required variables before starting Docker Compose. At minimum:

```env
NODE_ENV=development
DB_PASSWORD=drunkard_dev_password
JWT_SECRET=replace_with_local_dev_secret
SERVER_URL=http://127.0.0.1:3000
FRONTEND_URL=http://127.0.0.1:8080
WECHAT_APP_ID=
WECHAT_APP_SECRET=
```

Start services:

```bash
docker compose up -d --build
```

Check status:

```bash
docker compose ps
```

Check backend health:

```bash
curl http://127.0.0.1:3000/api/health
```

View logs:

```bash
docker compose logs -f app
```

## Manual Flutter Web Startup

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

For a production-like Web build:

```bash
cd app
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

If serving through the included Nginx config, the Web client can use the default `/api` base path.

## Android APK for Local or Server Testing

Build against a deployed server:

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

Build against a domain:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

APK output:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

Install with ADB:

```bash
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

## Common Development Commands

Backend:

```bash
cd backend
npm install
npm run build
npm run dev
npx prisma db push
npx prisma studio
```

Flutter:

```bash
cd app
flutter pub get
flutter analyze
flutter build web --pwa-strategy=none --no-wasm-dry-run
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

## Troubleshooting

### Blank Web Page

Try:

```bash
flutter clean
flutter pub get
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

Also clear the browser cache or open a fresh tab.

### Login Works on Web but APK Cannot Connect

The Web build usually uses `/api` behind Nginx. The APK cannot use a relative API URL. Build the APK with:

```bash
--dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

### Docker Starts but Backend Fails

Check:

```bash
docker compose logs -f app
docker compose logs -f db
```

Common causes:

- Missing `JWT_SECRET`
- Missing database password
- Database container still starting
- Port conflict on `3000`, `5432`, or `80`

### iOS Safari Feels Less Smooth

This is a known limitation of Flutter Web on iOS Safari for Canvas-heavy apps. Drunkard was tested with both the regular JS Web build and Flutter WebAssembly build; if neither improves a specific device, further UI micro-optimizations usually have limited value. Prefer Android APK or a future native iOS build for the smoothest mobile experience.
