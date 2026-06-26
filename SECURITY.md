# Security Policy

Drunkard is designed for small cocktail bar and private gathering scenarios. Before deploying your own fork publicly, review the following configuration items carefully.

## Secrets

Use .env.production.example as a template and provide deployment values through local environment files or your hosting platform's secret manager. Keep authentication tokens, database credentials, invite codes, uploaded files, backups, and user records in your own deployment storage.

## Production Checklist

- Set a strong `JWT_SECRET`.
- Set a strong database password.
- Change `INVITE_CODE`, `ADMIN_PHONE`, and `ADMIN_PASSWORD`.
- Do not expose PostgreSQL `5432` publicly.
- Do not expose Node.js `3000` publicly.
- Restrict CORS origins.
- Prefer HTTPS for real users.

## Reporting

This project does not define a public vulnerability reporting process yet. If you publish a fork, add your own contact method here.
