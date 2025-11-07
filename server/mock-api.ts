// @ts-nocheck
import 'dotenv/config';

import cors from 'cors';
import express from 'express';

const WEB_ORIGIN = process.env.WEB_ORIGIN ?? 'http://127.0.0.1:54879';
const PORT = Number.parseInt(process.env.PORT ?? '4000', 10);
const HOST = '0.0.0.0';

const app = express();

const corsOptions = {
  origin: WEB_ORIGIN,
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

app.post('/auth/login', (req, res) => {
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
