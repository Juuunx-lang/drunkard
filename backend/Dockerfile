FROM docker.m.daocloud.io/library/node:22-bookworm-slim AS builder

WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci --only=production=false
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM docker.m.daocloud.io/library/node:22-bookworm-slim AS runner

WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY package*.json ./

RUN mkdir -p uploads/temp uploads/drinks uploads/reviews uploads/avatars

EXPOSE 3000
CMD ["sh", "-c", "if [ \"$NODE_ENV\" = \"development\" ]; then npx prisma db push --accept-data-loss && npx tsx prisma/seed.ts && node dist/index.js; else npx prisma migrate deploy && node dist/index.js; fi"]
