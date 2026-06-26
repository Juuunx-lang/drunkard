# Operations and Future Development Guide

This document is for maintainers who operate or continue developing Drunkard.

## Core Runtime Commands

Run from the server project directory:

```bash
cd /opt/drunkard
```

Start:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d
```

Rebuild:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml up -d --build
```

Stop:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml down
```

Status:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml ps
```

Logs:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f nginx
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f db
```

Health check:

```bash
curl http://127.0.0.1:18080/api/health
```

## Data Locations

Default runtime locations:

```text
/opt/drunkard/data/postgres       # PostgreSQL data
Docker volume drunkard_uploads    # Uploaded images
/opt/drunkard/app/build/web       # Web static files
/opt/drunkard/.env.production     # Production secrets
```

Keep these paths intact unless intentionally resetting the runtime state.

## Backup

Database backup:

```bash
cd /opt/drunkard
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec db \
  pg_dump -U drunkard drunkard > backup-drunkard-$(date +%F).sql
```

Uploads backup:

```bash
docker run --rm \
  -v drunkard_uploads:/uploads:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/backup-uploads-$(date +%F).tar.gz /uploads
```

Copy backups off the server after creation.

## Restore

Database restore example:

```bash
cd /opt/drunkard
cat backup-drunkard-YYYY-MM-DD.sql | docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml exec -T db \
  psql -U drunkard drunkard
```

Uploads restore example:

```bash
docker run --rm \
  -v drunkard_uploads:/uploads \
  -v "$PWD:/backup" \
  alpine sh -c "cd / && tar xzf /backup/backup-uploads-YYYY-MM-DD.tar.gz"
```

## Database Changes

The production Compose command runs:

```bash
npx prisma db push
```

This is convenient for a private project. For a larger public deployment, prefer Prisma migrations:

```bash
cd backend
npx prisma migrate dev --name change_name
npx prisma migrate deploy
```

## Admin Operations

The bartender/admin can manage common data from the in-app admin GUI:

- Users
- Drinks
- Drink categories
- Ingredients
- Orders
- Reviews
- Community posts

Use database-level access only for emergency recovery.

## Image Uploads

Uploaded files are stored in the backend uploads volume and served by Nginx.

Operational notes:

- Keep the uploads volume backed up.
- Avoid committing uploaded files to Git.
- Large images should be cropped/compressed client-side or processed by the backend.

## Realtime

Socket.IO is used for realtime updates:

- New orders
- Order status updates
- Bar status updates
- Drink, category, and inventory invalidation

If realtime appears broken:

```bash
docker compose -p drunkard --env-file .env.production -f docker-compose.prod.yml logs -f app
```

Also confirm Nginx proxies `/socket.io/`.

## Security Maintenance

Regular checks:

- `.env.production` is not committed.
- Database port `5432` is not exposed publicly.
- Backend port `3000` is not exposed publicly.
- `JWT_SECRET` is not a default or weak value.
- Admin password is not a public/default password.
- CORS origins are restricted to the expected frontend origins.
- Server firewall only exposes necessary ports.

## Future Development Notes

Recommended priorities:

1. Add HTTPS and domain-based deployment.
2. Replace development-style Prisma `db push` with migration deploy flow.
3. Add automated backend tests for order status, auth, and permissions.
4. Add image size limits and scheduled cleanup for orphaned uploads.
5. Add a proper iOS client or iOS wrapper if mobile Safari smoothness becomes critical.
6. Add role-based admin audit logs for destructive operations.

## Open Source Checklist

Before publishing to GitHub:

- Remove `.local-dev/`.
- Remove SSH keys and deployment zips.
- Remove `.env.production`.
- Remove database dumps.
- Remove uploaded user images.
- Replace private IPs, phone numbers, invite codes, and passwords with placeholders.
- Add a `LICENSE` if external reuse is allowed.
