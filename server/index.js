require('dotenv/config');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');

const app = express();

const origins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const corsOptions = {
  origin(origin, callback) {
    if (!origin || origins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error(`CORS blocked: ${origin}`));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
  exposedHeaders: ['X-Request-Id'],
  credentials: false,
  optionsSuccessStatus: 204,
};

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use((req, res, next) => {
  const started = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - started;
    console.log(
      `${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`
    );
  });
  next();
});
app.use(express.json());
app.use(cookieParser());
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

app.get('/healthz', (_req, res) => {
  res.status(200).json({ ok: true, env: process.env.NODE_ENV });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ message: 'Email & password required' });
  }

  if (email === 'client@freetask.local' && password === 'Client123!') {
    return res.status(200).json({
      accessToken: 'dev.jwt.token.example',
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: { id: 'u_1', email, name: 'Client' },
    });
  }

  return res.status(401).json({ message: 'Invalid credentials' });
});

app.use((_req, res) => {
  res.status(404).json({ message: 'Not Found' });
});

const port = Number(process.env.PORT || 4000);
app.listen(port, () => {
  console.log(`API on http://127.0.0.1:${port}`);
});
