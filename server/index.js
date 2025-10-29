require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { loadEnvironmentConfig, seedEnvironmentData } = require('./config/environments');
const { connectDB } = require('./db');
const User = require('./models/User');
const Sentry = require('@sentry/node');

const APP_ENV = process.env.APP_ENV || process.env.NODE_ENV || 'development';
const APP_RELEASE = process.env.APP_RELEASE || 'freetask-server@2.0.0';
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ACCESS_TOKEN_TTL = parseInt(process.env.JWT_TTL || '900', 10); // seconds
const REFRESH_TOKEN_TTL = parseInt(process.env.REFRESH_TTL || `${7 * 24 * 60 * 60}`, 10);
const COOKIE_NAME = process.env.AUTH_COOKIE_NAME || 'freetask_refresh_token';
const environmentConfig = loadEnvironmentConfig(APP_ENV);
const shouldUseSecureCookies =
  typeof environmentConfig.cookies?.secure === 'boolean'
    ? environmentConfig.cookies.secure
    : APP_ENV === 'production';
const allowedOrigins = new Set(environmentConfig.cors.allowedOrigins || []);
const allowOriginPattern = environmentConfig.cors.allowPattern || null;
const localOriginPatterns = [/^http:\/\/localhost:\d+$/, /^http:\/\/127\.0\.0\.1:\d+$/];

Sentry.init({
  dsn: process.env.SENTRY_DSN || '',
  environment: APP_ENV,
  release: APP_RELEASE,
  tracesSampleRate: 1.0,
});

const app = express();

app.use(
  cors({
    origin(origin, callback) {
      if (!origin) {
        return callback(null, true);
      }
      if (localOriginPatterns.some((pattern) => pattern.test(origin))) {
        return callback(null, true);
      }
      if (allowedOrigins.has(origin)) {
        return callback(null, true);
      }
      if (allowOriginPattern && allowOriginPattern.test(origin)) {
        return callback(null, true);
      }
      const corsError = new Error('Origin is not allowed by CORS policy');
      corsError.type = 'cors';
      return callback(corsError);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    exposedHeaders: ['X-Request-Id'],
  }),
);

app.use(express.json({ limit: '1mb' }));

app.use(Sentry.Handlers.requestHandler());
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(compression());
app.use(cookieParser());
app.use((req, res, next) => {
  const requestId = req.headers['x-request-id'] || uuidv4();
  req.requestId = requestId;
  res.setHeader('X-Request-Id', requestId);
  next();
});

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
});

const signupLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
});

const refreshLimiterConfig = environmentConfig.rateLimiting?.refresh || {};
const refreshLimiter = rateLimit({
  windowMs: refreshLimiterConfig.windowMs || 60 * 1000,
  max: refreshLimiterConfig.max || 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) =>
    res.status(429).json({
      error: { message: 'Too many refresh attempts. Please wait before retrying.' },
      requestId: req.requestId,
    }),
  keyGenerator: (req) => {
    if (refreshLimiterConfig.useUserAgentKey) {
      return `${req.ip}:${req.headers['user-agent'] || 'unknown'}`;
    }
    return req.ip;
  },
});

const db = {
  users: new Map(),
  refreshTokens: new Map(),
  passwordResets: new Map(),
  jobs: new Map(),
  auditLogs: [],
};

const allowedRoles = new Set(['client', 'freelancer', 'admin', 'manager', 'support']);

function sanitizeUser(user) {
  if (!user) return null;
  const source = typeof user.toObject === 'function' ? user.toObject({ virtuals: false }) : user;
  const { passwordHash, __v, _id, ...rest } = source;
  const id = source.id || (_id ? _id.toString() : undefined);
  const normalizeDate = (value) => {
    if (!value) return value;
    return value instanceof Date ? value.toISOString() : value;
  };
  return {
    ...rest,
    id,
    email: source.email,
    role: source.role,
    verified: source.verified,
    createdAt: normalizeDate(source.createdAt),
    updatedAt: normalizeDate(source.updatedAt),
  };
}

function audit({ userId, action, metadata, requestId }) {
  db.auditLogs.push({
    id: uuidv4(),
    userId: userId || null,
    action,
    metadata: metadata || null,
    requestId: requestId || null,
    timestamp: new Date().toISOString(),
  });
}

function buildTokens(user) {
  const mapped = sanitizeUser(user);
  const userId = mapped?.id;
  const accessToken = jwt.sign(
    {
      sub: userId,
      role: mapped.role,
    },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL },
  );

  const refreshToken = uuidv4().replace(/-/g, '');
  const expiresAt = Date.now() + REFRESH_TOKEN_TTL * 1000;
  db.refreshTokens.set(refreshToken, { userId, expiresAt });

  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TOKEN_TTL,
    expiresAt,
  };
}

function setRefreshCookie(res, token) {
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: shouldUseSecureCookies,
    maxAge: REFRESH_TOKEN_TTL * 1000,
    path: '/auth',
  });
}

function clearRefreshCookie(res) {
  res.clearCookie(COOKIE_NAME, { path: '/auth' });
}

function validationErrorFormatter({ msg, param }) {
  return `${param}: ${msg}`;
}

function handleValidationResult(req, res, next) {
  const errors = validationResult(req).formatWith(validationErrorFormatter);
  if (!errors.isEmpty()) {
    return res.status(422).json({
      error: {
        message: 'Validation failed',
        details: errors.array(),
      },
      requestId: req.requestId,
    });
  }
  return next();
}

async function authGuard(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({
      error: { message: 'Authentication required' },
      requestId: req.requestId,
    });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(payload.sub);
    if (!user) {
      throw new Error('User not found');
    }
    req.user = sanitizeUser(user);
    return next();
  } catch (error) {
    return res.status(401).json({
      error: { message: 'Invalid or expired token' },
      requestId: req.requestId,
    });
  }
}

function roleGuard(roles) {
  return (req, res, next) => {
    if (!req.user || (!roles.includes(req.user.role) && req.user.role !== 'admin')) {
      return res.status(403).json({
        error: { message: 'Insufficient permissions', requiredRoles: roles },
        requestId: req.requestId,
      });
    }
    return next();
  };
}

async function findUserByEmail(email) {
  if (!email) return null;
  return User.findOne({ email });
}

function signAccessToken(user) {
  const secret = process.env.JWT_SECRET || JWT_SECRET;
  return jwt.sign({ sub: user._id.toString(), role: user.role }, secret, {
    expiresIn: '15m',
  });
}

function respondWithAuth(res, user, tokens, message) {
  const payload = {
    data: {
      user: sanitizeUser(user),
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
    },
    message,
    requestId: res.req.requestId,
  };
  return res.status(200).json(payload);
}

app.post(
  '/auth/signup',
  signupLimiter,
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    body('role')
      .optional()
      .isString()
      .custom((value) => allowedRoles.has(value))
      .withMessage('Invalid role provided'),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const { name, email, password, role } = req.body;
      if (await User.findOne({ email })) {
        return res.status(409).json({ message: 'Email already exists' });
      }
      const user = new User({ name, email, role: allowedRoles.has(role) ? role : 'client' });
      await user.setPassword(password);
      await user.save();
      const code = crypto.randomInt(100000, 999999).toString();
      req.app.locals.emailCodes ??= new Map();
      req.app.locals.emailCodes.set(email, { code, exp: Date.now() + 15 * 60 * 1000 });
      return res.status(201).json({ message: 'Signup success. Verify email.', verificationCode: code });
    } catch (e) {
      console.error(e);
      return res.status(500).json({ message: 'Signup failed' });
    }
  },
);

app.post(
  '/auth/login',
  loginLimiter,
  [
    body('email').isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const { email, password } = req.body;
      const user = await User.findOne({ email });
      if (!user || !(await user.verifyPassword(password))) {
        return res.status(401).json({ message: 'Invalid credentials' });
      }
      if (!user.verified) {
        const code = crypto.randomInt(100000, 999999).toString();
        req.app.locals.emailCodes ??= new Map();
        req.app.locals.emailCodes.set(email, { code, exp: Date.now() + 15 * 60 * 1000 });
        return res.status(403).json({
          message: 'Email verification required',
          details: { verificationCode: code },
        });
      }
      return res.json({
        user: {
          id: user._id.toString(),
          name: user.name,
          email: user.email,
          role: user.role,
        },
        accessToken: signAccessToken(user),
      });
    } catch (e) {
      console.error(e);
      res.status(500).json({ message: 'Login failed' });
    }
  },
);

app.post(
  '/auth/verify-email',
  [
    body('email').isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('code').isLength({ min: 4 }).withMessage('Verification code is required'),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const { email, code } = req.body;
      const rec = req.app.locals.emailCodes?.get(email);
      if (!rec || rec.exp < Date.now() || rec.code !== code) {
        return res.status(400).json({ message: 'Invalid or expired code' });
      }
      const user = await User.findOneAndUpdate(
        { email },
        { $set: { verified: true } },
        { new: true },
      );
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      req.app.locals.emailCodes.delete(email);
      res.json({ message: 'Email verified' });
    } catch (e) {
      console.error(e);
      res.status(500).json({ message: 'Verify failed' });
    }
  },
);

app.post(
  '/auth/refresh',
  refreshLimiter,
  [
    body('refreshToken').optional().isString(),
  ],
  handleValidationResult,
  async (req, res) => {
    const tokenFromBody = req.body.refreshToken;
    const tokenFromCookie = req.cookies[COOKIE_NAME];
    const refreshToken = tokenFromBody || tokenFromCookie;

    if (!refreshToken) {
      return res.status(401).json({
        error: { message: 'Refresh token is required' },
        requestId: req.requestId,
      });
    }

    const record = db.refreshTokens.get(refreshToken);
    if (!record || record.expiresAt < Date.now()) {
      db.refreshTokens.delete(refreshToken);
      clearRefreshCookie(res);
      return res.status(401).json({
        error: { message: 'Invalid refresh token' },
        requestId: req.requestId,
      });
    }

    const user = await User.findById(record.userId);
    if (!user) {
      db.refreshTokens.delete(refreshToken);
      clearRefreshCookie(res);
      return res.status(401).json({
        error: { message: 'Invalid refresh token' },
        requestId: req.requestId,
      });
    }

    db.refreshTokens.delete(refreshToken);
    const tokens = buildTokens(user);
    setRefreshCookie(res, tokens.refreshToken);
    audit({ userId: sanitizeUser(user).id, action: 'REFRESH_TOKEN', requestId: req.requestId });
    return respondWithAuth(res, user, tokens, 'Token refreshed');
  },
);

app.post(
  '/auth/logout',
  (req, res) => {
    const tokenFromBody = req.body?.refreshToken;
    const tokenFromCookie = req.cookies[COOKIE_NAME];
    const refreshToken = tokenFromBody || tokenFromCookie;
    if (refreshToken) {
      db.refreshTokens.delete(refreshToken);
    }
    clearRefreshCookie(res);
    return res.status(204).send();
  },
);

app.post(
  '/auth/forgot-password',
  [body('email').isEmail().withMessage('A valid email is required').normalizeEmail()],
  handleValidationResult,
  async (req, res) => {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(200).json({
        message: 'If that account exists, a reset email has been sent.',
        requestId: req.requestId,
      });
    }

    const token = uuidv4().replace(/-/g, '');
    db.passwordResets.set(token, {
      email,
      expiresAt: Date.now() + 15 * 60 * 1000,
    });
    audit({ userId: user._id.toString(), action: 'REQUEST_PASSWORD_RESET', requestId: req.requestId });

    return res.status(200).json({
      data: { resetToken: token },
      message: 'Password reset instructions sent.',
      requestId: req.requestId,
    });
  },
);

app.post(
  '/auth/reset-password',
  [
    body('email').isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('token').notEmpty().withMessage('Reset token is required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  ],
  handleValidationResult,
  async (req, res) => {
    const { email, token, password } = req.body;
    const reset = db.passwordResets.get(token);
    if (!reset || reset.email !== email || reset.expiresAt < Date.now()) {
      return res.status(401).json({
        error: { message: 'Invalid or expired reset token' },
        requestId: req.requestId,
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({
        error: { message: 'Account not found. Please verify the email used for reset.' },
        requestId: req.requestId,
      });
    }

    await user.setPassword(password);
    await user.save();
    db.passwordResets.delete(token);
    audit({ userId: user._id.toString(), action: 'RESET_PASSWORD', requestId: req.requestId });

    return res.status(200).json({
      message: 'Password has been updated.',
      requestId: req.requestId,
    });
  },
);

app.get('/users/me', authGuard, (req, res) => {
  return res.status(200).json({
    data: sanitizeUser(req.user),
    requestId: req.requestId,
  });
});

app.use((err, req, res, next) => {
  if (err && err.type === 'cors') {
    return res.status(403).json({
      error: { message: 'Origin not allowed' },
      requestId: req.requestId,
    });
  }
  Sentry.captureException(err);
  return res.status(500).json({
    error: { message: 'Unexpected server error' },
    requestId: req.requestId,
  });
});

app.use(Sentry.Handlers.errorHandler());

async function bootstrap() {
  try {
    await connectDB(process.env.MONGODB_URI);
    if (APP_ENV !== 'production') {
      await (async () => {
        const exist = await User.findOne({ email: 'admin@freetask.local' });
        if (!exist) {
          const admin = new User({
            name: 'Admin',
            email: 'admin@freetask.local',
            verified: true,
            role: 'admin',
          });
          await admin.setPassword('Admin123!');
          await admin.save();
          console.log('[SEED] Admin user created');
        }
      })().catch((error) => {
        console.error('[SEED] Failed:', error);
      });
    }
    await seedEnvironmentData(APP_ENV, {
      db,
      findUserByEmail,
      audit,
      hashPassword: (value) => bcrypt.hash(value, 10),
      UserModel: User,
    });

    const port = process.env.PORT || 4000;
    app.listen(port, () => console.log(`[API] running on ${port}`));
  } catch (e) {
    Sentry.captureException(e);
    console.error('[Boot] Failed:', e);
    process.exit(1);
  }
}

bootstrap();
