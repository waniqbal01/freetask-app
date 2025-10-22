const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const Sentry = require('@sentry/node');

const PORT = process.env.PORT || 4000;
const APP_ENV = process.env.APP_ENV || process.env.NODE_ENV || 'development';
const APP_RELEASE = process.env.APP_RELEASE || 'freetask-server@2.0.0';
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ACCESS_TOKEN_TTL = parseInt(process.env.JWT_TTL || '900', 10); // seconds
const REFRESH_TOKEN_TTL = parseInt(process.env.REFRESH_TTL || `${7 * 24 * 60 * 60}`, 10);
const COOKIE_NAME = process.env.AUTH_COOKIE_NAME || 'freetask_refresh_token';

Sentry.init({
  dsn: process.env.SENTRY_DSN || '',
  environment: APP_ENV,
  release: APP_RELEASE,
  tracesSampleRate: 1.0,
});

const app = express();

app.use(Sentry.Handlers.requestHandler());
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(
  cors({
    origin: process.env.CLIENT_ORIGIN || true,
    credentials: true,
  }),
);
app.use(compression());
app.use(express.json({ limit: '1mb' }));
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

const refreshLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
});

const db = {
  users: new Map(),
  refreshTokens: new Map(),
  emailVerifications: new Map(),
  passwordResets: new Map(),
  auditLogs: [],
};

const allowedRoles = new Set(['client', 'freelancer', 'admin', 'manager', 'support']);

function sanitizeUser(user) {
  if (!user) return null;
  const { passwordHash, ...rest } = user;
  return rest;
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
  const accessToken = jwt.sign(
    {
      sub: user.id,
      role: user.role,
    },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL },
  );

  const refreshToken = uuidv4().replace(/-/g, '');
  const expiresAt = Date.now() + REFRESH_TOKEN_TTL * 1000;
  db.refreshTokens.set(refreshToken, { userId: user.id, expiresAt });

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
    secure: APP_ENV === 'production',
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

function authGuard(req, res, next) {
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
    const user = db.users.get(payload.sub);
    if (!user) {
      throw new Error('User not found');
    }
    req.user = user;
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

function findUserByEmail(email) {
  for (const user of db.users.values()) {
    if (user.email === email) {
      return user;
    }
  }
  return null;
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

function requireVerification(user) {
  const record = db.emailVerifications.get(user.email);
  if (!user.verified && record) {
    return {
      code: record.code,
      expiresAt: record.expiresAt,
    };
  }
  return null;
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
      const { name, email, password } = req.body;
      const role = allowedRoles.has(req.body.role) ? req.body.role : 'client';

      if (findUserByEmail(email)) {
        return res.status(409).json({
          error: { message: 'Email already registered' },
          requestId: req.requestId,
        });
      }

      const passwordHash = await bcrypt.hash(password, 10);
      const id = uuidv4();
      const user = {
        id,
        name,
        email,
        role,
        verified: false,
        passwordHash,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      db.users.set(id, user);
      const verificationCode = String(Math.floor(100000 + Math.random() * 900000));
      db.emailVerifications.set(email, {
        code: verificationCode,
        expiresAt: Date.now() + 15 * 60 * 1000,
      });

      const tokens = buildTokens(user);
      setRefreshCookie(res, tokens.refreshToken);
      audit({ userId: id, action: 'SIGNUP', metadata: { role }, requestId: req.requestId });

      return res.status(201).json({
        data: {
          user: sanitizeUser(user),
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresIn: tokens.expiresIn,
          verificationRequired: true,
          verificationCode,
        },
        message: 'Account created. Please verify your email.',
        requestId: req.requestId,
      });
    } catch (error) {
      Sentry.captureException(error);
      return res.status(500).json({
        error: { message: 'Unable to complete signup' },
        requestId: req.requestId,
      });
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
    const { email, password } = req.body;
    const user = findUserByEmail(email);
    if (!user) {
      return res.status(401).json({
        error: { message: 'Invalid credentials' },
        requestId: req.requestId,
      });
    }

    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) {
      return res.status(401).json({
        error: { message: 'Invalid credentials' },
        requestId: req.requestId,
      });
    }

    if (!user.verified) {
      const verification = requireVerification(user);
      return res.status(403).json({
        error: {
          message: 'Email verification required before logging in.',
          details: verification ? [`Verification code: ${verification.code}`] : undefined,
        },
        requestId: req.requestId,
      });
    }

    const tokens = buildTokens(user);
    setRefreshCookie(res, tokens.refreshToken);
    audit({ userId: user.id, action: 'LOGIN', requestId: req.requestId });
    return respondWithAuth(res, user, tokens, 'Login successful');
  },
);

app.post(
  '/auth/verify-email',
  [
    body('email').isEmail().withMessage('A valid email is required').normalizeEmail(),
    body('code').isLength({ min: 4 }).withMessage('Verification code is required'),
  ],
  handleValidationResult,
  (req, res) => {
    const { email, code } = req.body;
    const user = findUserByEmail(email);
    if (!user) {
      return res.status(404).json({
        error: { message: 'User not found' },
        requestId: req.requestId,
      });
    }

    const record = db.emailVerifications.get(email);
    if (!record || record.code !== code || record.expiresAt < Date.now()) {
      return res.status(400).json({
        error: { message: 'Invalid or expired verification code' },
        requestId: req.requestId,
      });
    }

    db.emailVerifications.delete(email);
    user.verified = true;
    user.updatedAt = new Date().toISOString();
    audit({ userId: user.id, action: 'VERIFY_EMAIL', requestId: req.requestId });

    return res.status(200).json({
      data: { verified: true },
      message: 'Email verified successfully',
      requestId: req.requestId,
    });
  },
);

app.post(
  '/auth/refresh',
  refreshLimiter,
  [
    body('refreshToken').optional().isString(),
  ],
  handleValidationResult,
  (req, res) => {
    const tokenFromBody = req.body.refreshToken;
    const tokenFromCookie = req.cookies[COOKIE_NAME];
    const refreshToken = tokenFromBody || tokenFromCookie;

    if (!refreshToken) {
      return res.status(400).json({
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

    const user = db.users.get(record.userId);
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
    audit({ userId: user.id, action: 'REFRESH_TOKEN', requestId: req.requestId });
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
  (req, res) => {
    const { email } = req.body;
    const user = findUserByEmail(email);
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
    audit({ userId: user.id, action: 'REQUEST_PASSWORD_RESET', requestId: req.requestId });

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
      return res.status(400).json({
        error: { message: 'Invalid or expired reset token' },
        requestId: req.requestId,
      });
    }

    const user = findUserByEmail(email);
    if (!user) {
      return res.status(404).json({
        error: { message: 'User not found' },
        requestId: req.requestId,
      });
    }

    user.passwordHash = await bcrypt.hash(password, 10);
    user.updatedAt = new Date().toISOString();
    db.passwordResets.delete(token);
    audit({ userId: user.id, action: 'RESET_PASSWORD', requestId: req.requestId });

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
  Sentry.captureException(err);
  return res.status(500).json({
    error: { message: 'Unexpected server error' },
    requestId: req.requestId,
  });
});

app.use(Sentry.Handlers.errorHandler());

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Authentication API listening on port ${PORT}`);
});
