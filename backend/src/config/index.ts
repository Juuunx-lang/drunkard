import dotenv from 'dotenv';
dotenv.config();

const nodeEnv = process.env.NODE_ENV || 'development';
const jwtSecret = process.env.JWT_SECRET;

if (nodeEnv === 'production' && (!jwtSecret || jwtSecret === 'dev-secret')) {
  throw new Error('生产环境必须设置安全的 JWT_SECRET，且不能使用 dev-secret');
}

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv,
  jwtSecret: jwtSecret || 'dev-secret',
  serverUrl: process.env.SERVER_URL || 'http://localhost:3000',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  inviteCode: process.env.INVITE_CODE || '0000',
  admin: {
    phone: process.env.ADMIN_PHONE || '18800000001',
    password: process.env.ADMIN_PASSWORD || 'change_me_admin',
  },
  database: {
    url: process.env.DATABASE_URL,
  },
  wechat: {
    appId: process.env.WECHAT_APP_ID || '',
    appSecret: process.env.WECHAT_APP_SECRET || '',
  },
  upload: {
    dir: process.env.UPLOAD_DIR || './uploads',
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760', 10),
  },
  get isDev() {
    return this.nodeEnv === 'development';
  },
};
