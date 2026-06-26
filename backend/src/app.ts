import express from 'express';
import cors from 'cors';
import path from 'path';
import routes from './routes';
import { errorHandler } from './middleware/errorHandler';
import { config } from './config';

const app = express();

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || config.isDev) {
      callback(null, true);
      return;
    }
    const allowedOrigins = new Set([config.frontendUrl, ...config.corsOrigins]);
    callback(null, allowedOrigins.has(origin));
  },
}));
app.use(express.json({ limit: '4mb' }));
app.use('/uploads', express.static(path.join(__dirname, '..', config.upload.dir)));

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', env: config.nodeEnv });
});

app.use('/api', routes);
app.use(errorHandler);

export default app;
