// @ts-nocheck
import 'dotenv/config';

import cors from 'cors';
import express from 'express';

const WEB_ORIGIN = process.env.WEB_ORIGIN ?? 'http://127.0.0.1:54879';
const PORT = Number.parseInt(process.env.PORT ?? '4000', 10);
const HOST = '0.0.0.0';

const LOCALHOST_REGEX = /^(https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])):\d+$/i;
const extraOrigins = (process.env.EXTRA_ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const allowedOrigins = new Set([
  WEB_ORIGIN,
  'http://localhost:4000',
  'http://127.0.0.1:4000',
  'https://localhost:4000',
  'https://127.0.0.1:4000',
  ...extraOrigins,
].filter(Boolean));

const app = express();

const corsOptions = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    if (!origin) {
      return callback(null, true);
    }

    if (LOCALHOST_REGEX.test(origin)) {
      return callback(null, true);
    }

    if (allowedOrigins.has(origin)) {
      return callback(null, true);
    }

    if (process.env.NODE_ENV !== 'production') {
      console.warn(`[mock-api] Rejecting CORS origin ${origin}. Set WEB_ORIGIN or EXTRA_ALLOWED_ORIGINS to allow it.`);
    }

    return callback(null, false);
  },
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};

app.use((req, _res, next) => {
  console.log(`[mock-api] ${req.method} ${req.path}`);
  next();
});

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/api/auth/login', (req, res) => {
  const { email } = req.body ?? {};

  res.json({
    accessToken: 'dev-token',
    user: {
      id: '1',
      email,
    },
  });
});

app.listen(PORT, HOST, () => {
  console.log(`[mock-api] listening on http://${HOST}:${PORT} with origin ${WEB_ORIGIN}`);
});
