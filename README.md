# Drunkard

Drunkard is a private cocktail bar application for home bars, small parties, bartender-led gatherings, and invite-only tasting events.

It provides a Flutter client for Web and Android, a Node.js API, PostgreSQL persistence, image uploads, realtime order updates, inventory warnings, reviews, favorites, community posts, and a small admin console for bartender operations.

## Highlights

- Guest phone registration with invite-code protection.
- Phone/password login, plus a reserved WeChat OAuth flow for future integration.
- Cocktail menu grouped by configurable categories.
- Cocktail detail pages with stock warnings, reviews, favorites, and uploaded images.
- Persistent selected-drinks cart on the client side.
- One-tap order creation for multiple cocktails and multiple cups of the same cocktail.
- Missing-ingredient hints that can be written into order item notes.
- Bartender order workflow: accept, prepare, complete.
- Realtime updates powered by Socket.IO.
- Bar status management: idle, busy, closed.
- Review flow after completed orders, including text, emoji, and images.
- Community feed with categories, search, likes, editing, and moderation.
- Admin GUI for common database maintenance tasks.
- Drink image upload and cropping.
- Production deployment with Docker Compose and Nginx.

## Tech Stack

| Layer            | Technology                   |
| ---------------- | ---------------------------- |
| Client           | Flutter Web, Flutter Android |
| State management | Riverpod                     |
| Routing          | GoRouter                     |
| HTTP client      | Dio                          |
| Realtime         | Socket.IO                    |
| Backend          | Node.js, TypeScript, Express |
| ORM              | Prisma                       |
| Database         | PostgreSQL                   |
| Image processing | Multer, Sharp                |
| Deployment       | Docker Compose, Nginx        |

## Repository Layout

```text
Drunkard/
├── app/                         # Flutter Web / Android client
│   ├── lib/
│   ├── assets/
│   └── web/
├── backend/                     # Node.js API
│   ├── prisma/                  # Prisma schema and seed data
│   └── src/                     # Express routes, controllers, services
├── docs/
│   ├── README_CN.md             # Chinese project handbook
│   ├── LOCAL_RUN.md             # Local development guide
│   ├── DEPLOYMENT.md            # Production deployment guide
│   ├── OPERATIONS.md            # Maintenance and future development guide
│   └── SERVER_RUNBOOK.md        # Server operations runbook
├── scripts/                     # Local helper scripts
├── docker-compose.yml           # Local Docker Compose stack
├── docker-compose.prod.example.yml
├── nginx.conf
├── .env.production.example
├── start-local.cmd
└── stop-local.cmd
```

## How the App Works

Drunkard is designed around two roles:

### Guest Workflow

```text
Register or sign in
  -> browse the cocktail menu
  -> open a drink detail page
  -> tap "+" to add drinks to the selected-drinks cart
  -> confirm one combined order
  -> follow realtime order status
  -> review completed drinks
```

Guests can add multiple drinks and multiple cups of the same drink before confirming the order. If a drink is missing ingredients, the app shows a self-preparation hint and stores the missing-ingredient note on the corresponding order item.

### Bartender Workflow

```text
Sign in as admin
  -> review pending orders
  -> accept order
  -> mark as preparing
  -> mark as completed
  -> maintain bar status, menu, inventory and categories
```

The bartender can switch the bar status between idle, busy and closed. When the bar is closed, guests cannot place new orders.

## Quick Start

### Requirements

- Docker Desktop or Docker Engine
- Flutter SDK
- Node.js LTS
- Git

### Start Locally on Windows

```bat
start-local.cmd
```

Open:

```text
http://127.0.0.1:8080
```

Stop:

```bat
stop-local.cmd
```

For details, see [`docs/LOCAL_RUN.md`](docs/LOCAL_RUN.md).

## Environment Variables

Copy the example file before deployment:

```bash
cp .env.production.example .env.production
```

Important variables:

| Variable            | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `DB_PASSWORD`       | PostgreSQL password                                          |
| `JWT_SECRET`        | JWT signing secret; use a long random value                  |
| `INVITE_CODE`       | Private registration invite code                             |
| `ADMIN_PHONE`       | Initial bartender/admin phone number                         |
| `ADMIN_PASSWORD`    | Initial bartender/admin password                             |
| `SERVER_URL`        | Public backend origin, for example `https://bar.example.com` |
| `FRONTEND_URL`      | Public frontend origin                                       |
| `CORS_ORIGINS`      | Allowed browser origins                                      |
| `WECHAT_APP_ID`     | Optional WeChat OAuth AppID                                  |
| `WECHAT_APP_SECRET` | Optional WeChat OAuth secret                                 |

Never commit `.env.production` or any real secret.

## Build Flutter Web

```bash
cd app
flutter pub get
flutter build web --pwa-strategy=none --no-wasm-dry-run
```

Output:

```text
app/build/web
```

The default Web API base URL is `/api`, which is intended for same-origin Nginx reverse proxy deployments.

## Build Android APK

For local LAN or production IP testing, build with an explicit API URL:

```bash
cd app
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_SERVER_IP:18080/api
```

For HTTPS/domain deployments:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_DOMAIN/api
```

Output:

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

## Production Deployment

The recommended production topology is:

```text
Browser / Android app
  -> Nginx container on port 80
  -> /api and /socket.io proxy to Node.js
  -> PostgreSQL inside the Docker Compose network
```

If the server already hosts another project, do not overwrite the existing host-level Nginx configuration. Bind Drunkard to a separate port such as `18080`, or bind it to `127.0.0.1:18080` and use a host reverse proxy.

See:

- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
- [`docs/SERVER_RUNBOOK.md`](docs/SERVER_RUNBOOK.md)

## Documentation

English documentation:

- [`README.md`](README.md)
- [`docs/LOCAL_RUN.md`](docs/LOCAL_RUN.md)
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md)
- [`docs/SERVER_RUNBOOK.md`](docs/SERVER_RUNBOOK.md)

Chinese documentation:

- [`README_CN.md`](README_CN.md)
- [`docs/LOCAL_RUN_CN.md`](docs/LOCAL_RUN_CN.md)
- [`docs/DEPLOYMENT_CN.md`](docs/DEPLOYMENT_CN.md)
- [`docs/OPERATIONS_CN.md`](docs/OPERATIONS_CN.md)
- [`docs/SERVER_RUNBOOK_CN.md`](docs/SERVER_RUNBOOK_CN.md)

## Security Checklist

Before publishing or deploying:

- Replace all placeholder secrets.
- Use a strong `JWT_SECRET`.
- Use a strong database password.
- Change the default admin account values.
- Do not expose PostgreSQL `5432` to the public internet.
- Do not expose Node.js `3000` directly in production.
- Keep `.env.production`, deployment keys, database backups, and uploaded user files out of Git.
- Prefer HTTPS for real users, especially for mobile browsers and APK usage.
- Review CORS origins before public deployment.

## Notes on Mobile Web Performance

Flutter Web can be less smooth on iOS Safari than on Android or desktop browsers because of browser-level rendering limitations. Drunkard keeps the Web build as the shareable client and the Android APK as the smoother Android client. For iOS users requiring native-level smoothness, a future iOS app shell or native iOS build is recommended.

## Troubleshooting Overview

### Blank Web Page

- Rebuild Flutter Web.
- Clear browser cache.
- Confirm static files are deployed to `app/build/web`.
- Confirm Nginx is serving the expected directory.

### API Unavailable

- Check `/api/health`.
- Check backend container logs.
- Confirm `/api` is proxied by Nginx.
- Confirm the APK was built with a full `API_BASE_URL`.

### Login Fails

- Check backend logs.
- Confirm JWT secret is configured.
- Confirm the user exists.
- Clear stale browser local storage if necessary.

### Realtime Does Not Update

- Check Socket.IO proxy configuration.
- Check backend logs.
- Confirm the browser can access `/socket.io/`.

## Contributing

This project started as a private bar app and is still optimized for that use case. If you fork it:

- Replace all secrets and account bootstrap values.
- Review business assumptions such as invite-code registration and admin workflows.
- Add tests before using it for larger public deployments.
- Add a license if you intend to accept contributions.

## License

No license is included by default. Add a license before accepting external contributions or redistributing the project.
