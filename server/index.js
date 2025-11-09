require('dotenv/config');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');

const authRouter = require('./routes/auth');
const jobsRouter = require('./routes/jobs');

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

app.use('/api/auth', authRouter);
app.use('/api/jobs', jobsRouter);

app.use((_req, res) => {
  res.status(404).json({ message: 'Not Found' });
});

// eslint-disable-next-line no-unused-vars
app.use((error, _req, res, _next) => {
  console.error('[Server] Unhandled error:', error);
  res.status(500).json({ message: 'Internal Server Error' });
});

const port = Number(process.env.PORT || 4000);
app.listen(port, () => {
  console.log(`API on http://127.0.0.1:${port}`);
});
