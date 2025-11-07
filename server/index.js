require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const { body, param, validationResult } = require('express-validator');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { loadEnvironmentConfig, seedEnvironmentData } = require('./config/environments');
const { connectDB } = require('./db');
const User = require('./models/User');
const Service = require('./models/Service');
const Order = require('./models/Order');
const Transaction = require('./models/Transaction');
const Payout = require('./models/Payout');
const { requireRole } = require('./middleware/role_guard');
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
const DEV_ORIGIN = process.env.WEB_ORIGIN ?? 'http://127.0.0.1:54879';
const corsOptions = {
  origin: DEV_ORIGIN,
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  exposedHeaders: ['X-Request-Id'],
};

Sentry.init({
  dsn: process.env.SENTRY_DSN || '',
  environment: APP_ENV,
  release: APP_RELEASE,
  tracesSampleRate: 1.0,
});

const app = express();
const payments = require('./routes/payments');

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

app.use(express.json());

app.get('/healthz', (req, res) => {
  res.status(200).json({ ok: true, ts: Date.now() });
});

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.use(Sentry.Handlers.requestHandler());
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(compression());
app.use(cookieParser());
app.use('/payments', payments);
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
  services: new Map(),
  orders: new Map(),
  transactions: new Map(),
  payouts: new Map(),
  auditLogs: [],
};

let usingMemoryStore = false;

const allowedRoles = new Set(['client', 'freelancer', 'admin']);

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

function getUserId(user) {
  if (!user) return null;
  if (typeof user.id === 'string' && user.id) {
    return user.id;
  }
  if (user._id) {
    return user._id.toString();
  }
  return null;
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
    const user = await findUserById(payload.sub);
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
  if (!usingMemoryStore) {
    return User.findOne({ email });
  }
  const normalizedEmail = String(email).toLowerCase();
  for (const user of db.users.values()) {
    if (user.email === normalizedEmail) {
      return user;
    }
  }
  return null;
}

async function findUserById(id) {
  if (!id) return null;
  if (!usingMemoryStore) {
    return User.findById(id);
  }
  return db.users.get(id) || null;
}

async function createUserRecord({ name, email, password, role, verified = false }) {
  const normalizedEmail = String(email).toLowerCase();
  if (!usingMemoryStore) {
    const user = new User({ name, email: normalizedEmail, role, verified });
    if (password) {
      await user.setPassword(password);
    }
    await user.save();
    return user;
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const passwordHash = password ? await bcrypt.hash(password, 10) : '';
  const user = {
    id,
    name,
    email: normalizedEmail,
    role,
    verified,
    passwordHash,
    createdAt: now,
    updatedAt: now,
  };
  db.users.set(id, user);
  return user;
}

async function verifyUserPassword(user, password) {
  if (!user || !password) {
    return false;
  }

  if (!usingMemoryStore && typeof user.verifyPassword === 'function') {
    return user.verifyPassword(password);
  }

  if (!user.passwordHash) {
    return false;
  }
  return bcrypt.compare(password, user.passwordHash);
}

async function markUserVerified(email) {
  const user = await findUserByEmail(email);
  if (!user) {
    return null;
  }

  if (!usingMemoryStore) {
    user.verified = true;
    await user.save();
    return user;
  }

  user.verified = true;
  user.updatedAt = new Date().toISOString();
  db.users.set(user.id, user);
  return user;
}

async function updateUserPassword(user, password) {
  if (!user) {
    return null;
  }

  if (!usingMemoryStore) {
    await user.setPassword(password);
    await user.save();
    return user;
  }

  const userId = getUserId(user);
  if (!userId) {
    return null;
  }

  const existing = db.users.get(userId);
  if (!existing) {
    return null;
  }

  existing.passwordHash = await bcrypt.hash(password, 10);
  existing.updatedAt = new Date().toISOString();
  db.users.set(userId, existing);
  return existing;
}

function signAccessToken(user) {
  const secret = process.env.JWT_SECRET || JWT_SECRET;
  return jwt.sign({ sub: getUserId(user), role: user.role }, secret, {
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

const PLATFORM_FEE_RATE = 0.1;

function toPlainDocument(doc) {
  if (!doc) return null;
  if (typeof doc.toObject === 'function') {
    const plain = doc.toObject({ virtuals: false });
    const { _id, __v, ...rest } = plain;
    return {
      ...rest,
      id: (_id || plain.id)?.toString(),
      createdAt: plain.createdAt ? new Date(plain.createdAt).toISOString() : undefined,
      updatedAt: plain.updatedAt ? new Date(plain.updatedAt).toISOString() : undefined,
    };
  }

  const source = { ...doc };
  if (!source.id && source._id) {
    source.id = source._id;
  }
  if (source.createdAt instanceof Date) {
    source.createdAt = source.createdAt.toISOString();
  }
  if (source.updatedAt instanceof Date) {
    source.updatedAt = source.updatedAt.toISOString();
  }
  return source;
}

function ensureId(value) {
  if (!value) return value;
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value !== null && typeof value.toString === 'function') {
    return value.toString();
  }
  return value;
}

function calculateEscrow(amount) {
  const total = Number(amount) || 0;
  const platformFee = Math.round(total * PLATFORM_FEE_RATE * 100) / 100;
  const freelancerAmount = Math.round((total - platformFee) * 100) / 100;
  return { platformFee, freelancerAmount };
}

async function formatServiceRecord(service) {
  if (!service) return null;
  const plain = toPlainDocument(service);
  if (!plain) return null;
  return {
    id: ensureId(plain.id),
    freelancer: ensureId(plain.freelancer),
    title: plain.title,
    description: plain.description,
    category: plain.category,
    price: plain.price,
    deliveryTime: plain.deliveryTime,
    media: Array.isArray(plain.media) ? plain.media : [],
    status: plain.status,
    createdAt: plain.createdAt,
    updatedAt: plain.updatedAt,
  };
}

async function formatOrderRecord(order) {
  if (!order) return null;

  if (!usingMemoryStore) {
    const populated = await order
      .populate('service')
      .populate('client', 'name email role')
      .populate('freelancer', 'name email role');
    const plain = toPlainDocument(populated);
    return {
      id: ensureId(plain.id),
      service: await formatServiceRecord(populated.service),
      client: sanitizeUser(populated.client),
      freelancer: sanitizeUser(populated.freelancer),
      requirements: plain.requirements || '',
      status: plain.status,
      deliveredAt: plain.deliveredAt,
      deliveryDate: plain.deliveryDate,
      deliveredWork: plain.deliveredWork,
      revisionNotes: plain.revisionNotes,
      totalAmount: plain.totalAmount,
      createdAt: plain.createdAt,
      updatedAt: plain.updatedAt,
    };
  }

  const plain = toPlainDocument(order);
  const service = await formatServiceRecord(db.services.get(ensureId(plain.service)));
  const client = await findUserById(ensureId(plain.client));
  const freelancer = await findUserById(ensureId(plain.freelancer));
  return {
    id: ensureId(plain.id),
    service,
    client: sanitizeUser(client),
    freelancer: sanitizeUser(freelancer),
    requirements: plain.requirements || '',
    status: plain.status,
    deliveredAt: plain.deliveredAt,
    deliveryDate: plain.deliveryDate,
    deliveredWork: plain.deliveredWork,
    revisionNotes: plain.revisionNotes,
    totalAmount: plain.totalAmount,
    createdAt: plain.createdAt,
    updatedAt: plain.updatedAt,
  };
}

function normalizeStatusInput(input, allowed) {
  if (!input) return null;
  const normalized = String(input).toLowerCase();
  if (allowed.includes(normalized)) {
    return normalized;
  }
  return null;
}

async function createServiceRecord(data) {
  if (!usingMemoryStore) {
    const record = new Service(data);
    await record.save();
    return record;
  }
  const id = uuidv4();
  const now = new Date().toISOString();
  const record = {
    id,
    ...data,
    freelancer: ensureId(data.freelancer),
    media: Array.isArray(data.media) ? data.media : [],
    status: data.status || 'published',
    createdAt: now,
    updatedAt: now,
  };
  db.services.set(id, record);
  return record;
}

async function listServices(filter = {}) {
  if (!usingMemoryStore) {
    const query = Service.find(filter);
    return query.exec();
  }
  const services = Array.from(db.services.values());
  if (!filter || Object.keys(filter).length === 0) {
    return services;
  }
  return services.filter((service) => {
    return Object.entries(filter).every(([key, value]) => {
      if (value === undefined) return true;
      if (Array.isArray(value)) {
        return value.includes(service[key]);
      }
      return service[key] === value;
    });
  });
}

async function findServiceById(id) {
  if (!id) return null;
  if (!usingMemoryStore) {
    return Service.findById(id);
  }
  return db.services.get(ensureId(id)) || null;
}

async function createOrderRecord(data) {
  if (!usingMemoryStore) {
    const record = new Order(data);
    await record.save();
    return record;
  }
  const id = uuidv4();
  const now = new Date().toISOString();
  const record = {
    id,
    ...data,
    service: ensureId(data.service),
    client: ensureId(data.client),
    freelancer: ensureId(data.freelancer),
    createdAt: now,
    updatedAt: now,
  };
  db.orders.set(id, record);
  return record;
}

async function findOrderById(id) {
  if (!id) return null;
  if (!usingMemoryStore) {
    return Order.findById(id);
  }
  return db.orders.get(ensureId(id)) || null;
}

async function listOrdersForUser(user) {
  if (!user) return [];
  const userId = ensureId(getUserId(user) || user.id || user._id);
  if (!usingMemoryStore) {
    const query = Order.find({
      $or: [{ client: userId }, { freelancer: userId }],
    });
    return query.exec();
  }
  return Array.from(db.orders.values()).filter(
    (order) => ensureId(order.client) === userId || ensureId(order.freelancer) === userId,
  );
}

async function listAllOrders() {
  if (!usingMemoryStore) {
    return Order.find();
  }
  return Array.from(db.orders.values());
}

async function saveOrder(order) {
  if (!order) return null;
  if (!usingMemoryStore && typeof order.save === 'function') {
    await order.save();
    return order;
  }
  const id = ensureId(order.id || order._id);
  if (!id) return order;
  order.updatedAt = new Date().toISOString();
  db.orders.set(id, order);
  return order;
}

async function createTransactionRecord(data) {
  if (!usingMemoryStore) {
    const record = new Transaction(data);
    await record.save();
    return record;
  }
  const id = uuidv4();
  const now = new Date().toISOString();
  const record = {
    id,
    ...data,
    order: ensureId(data.order),
    createdAt: now,
    updatedAt: now,
  };
  db.transactions.set(id, record);
  return record;
}

async function findTransactionByOrder(orderId) {
  if (!orderId) return null;
  if (!usingMemoryStore) {
    return Transaction.findOne({ order: orderId });
  }
  const normalized = ensureId(orderId);
  for (const transaction of db.transactions.values()) {
    if (ensureId(transaction.order) === normalized) {
      return transaction;
    }
  }
  return null;
}

async function saveTransaction(transaction) {
  if (!transaction) return null;
  if (!usingMemoryStore && typeof transaction.save === 'function') {
    await transaction.save();
    return transaction;
  }
  const id = ensureId(transaction.id || transaction._id);
  if (!id) return transaction;
  transaction.updatedAt = new Date().toISOString();
  db.transactions.set(id, transaction);
  return transaction;
}

async function createPayoutRecord(data) {
  if (!usingMemoryStore) {
    const record = new Payout(data);
    await record.save();
    return record;
  }
  const id = uuidv4();
  const now = new Date().toISOString();
  const record = {
    id,
    ...data,
    freelancer: ensureId(data.freelancer),
    transaction: ensureId(data.transaction),
    createdAt: now,
    updatedAt: now,
  };
  db.payouts.set(id, record);
  return record;
}

async function findPayoutById(id) {
  if (!id) return null;
  if (!usingMemoryStore) {
    return Payout.findById(id);
  }
  return db.payouts.get(ensureId(id)) || null;
}

async function savePayout(payout) {
  if (!payout) return null;
  if (!usingMemoryStore && typeof payout.save === 'function') {
    await payout.save();
    return payout;
  }
  const id = ensureId(payout.id || payout._id);
  if (!id) return payout;
  payout.updatedAt = new Date().toISOString();
  db.payouts.set(id, payout);
  return payout;
}

async function listTransactions(filter = {}) {
  if (!usingMemoryStore) {
    return Transaction.find(filter).exec();
  }
  const transactions = Array.from(db.transactions.values());
  if (!filter || Object.keys(filter).length === 0) return transactions;
  return transactions.filter((transaction) => {
    return Object.entries(filter).every(([key, value]) => {
      if (value === undefined) return true;
      return transaction[key] === value;
    });
  });
}

async function listPayouts(filter = {}) {
  if (!usingMemoryStore) {
    return Payout.find(filter).exec();
  }
  const payouts = Array.from(db.payouts.values());
  if (!filter || Object.keys(filter).length === 0) return payouts;
  return payouts.filter((payout) => {
    return Object.entries(filter).every(([key, value]) => {
      if (value === undefined) return true;
      return payout[key] === value;
    });
  });
}

async function formatTransactionRecord(transaction) {
  if (!transaction) return null;
  const plain = toPlainDocument(transaction);
  return {
    id: ensureId(plain.id),
    order: ensureId(plain.order),
    amount: plain.amount,
    platformFee: plain.platformFee,
    freelancerAmount: plain.freelancerAmount,
    status: plain.status,
    type: plain.type,
    notes: plain.notes,
    createdAt: plain.createdAt,
    updatedAt: plain.updatedAt,
  };
}

async function formatPayoutRecord(payout) {
  if (!payout) return null;
  const plain = toPlainDocument(payout);
  const freelancer = await findUserById(ensureId(plain.freelancer));
  return {
    id: ensureId(plain.id),
    transaction: ensureId(plain.transaction),
    freelancer: sanitizeUser(freelancer),
    amount: plain.amount,
    status: plain.status,
    method: plain.method,
    reference: plain.reference,
    createdAt: plain.createdAt,
    updatedAt: plain.updatedAt,
  };
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
      if (await findUserByEmail(email)) {
        return res.status(409).json({ message: 'Email already exists' });
      }
      const user = await createUserRecord({
        name,
        email,
        password,
        role: allowedRoles.has(role) ? role : 'client',
      });
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

const privilegedAccounts = [
  { name: 'Admin', email: 'admin@freetask.local', password: 'Admin123!', role: 'admin' },
  { name: 'Client', email: 'client@freetask.local', password: 'Client123!', role: 'client' },
  {
    name: 'Freelancer',
    email: 'freelancer@freetask.local',
    password: 'Freelancer123!',
    role: 'freelancer',
  },
];

const bypassVerificationAccounts = new Map(
  privilegedAccounts.map((account) => [account.email.toLowerCase(), account]),
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
      const normalizedEmail = String(email).toLowerCase();
      const user = await findUserByEmail(normalizedEmail);
      if (!user || !(await verifyUserPassword(user, password))) {
        return res.status(401).json({ message: 'Invalid credentials' });
      }

      const bypassAccount = bypassVerificationAccounts.get(normalizedEmail);

      if (!user.verified) {
        if (!bypassAccount || password !== bypassAccount.password) {
          const code = crypto.randomInt(100000, 999999).toString();
          req.app.locals.emailCodes ??= new Map();
          req.app.locals.emailCodes.set(normalizedEmail, { code, exp: Date.now() + 15 * 60 * 1000 });
          return res.status(403).json({
            message: 'Email verification required',
            details: { verificationCode: code },
          });
        }

        if (bypassAccount) {
          if (!usingMemoryStore) {
            let needsSave = false;
            if (user.role !== bypassAccount.role) {
              user.role = bypassAccount.role;
              needsSave = true;
            }
            if (!user.verified) {
              user.verified = true;
              needsSave = true;
            }
            if (needsSave) {
              await user.save();
            }
          } else {
            let needsUpdate = false;
            if (user.role !== bypassAccount.role) {
              user.role = bypassAccount.role;
              needsUpdate = true;
            }
            if (!user.verified) {
              user.verified = true;
              needsUpdate = true;
            }
            if (needsUpdate) {
              user.updatedAt = new Date().toISOString();
              db.users.set(user.id, user);
            }
          }
        }
      }

      const userId = getUserId(user);
      return res.json({
        user: {
          id: userId,
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
      const user = await markUserVerified(email);
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

    const user = await findUserById(record.userId);
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
    const user = await findUserByEmail(email);
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
    audit({ userId: getUserId(user), action: 'REQUEST_PASSWORD_RESET', requestId: req.requestId });

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

    const user = await findUserByEmail(email);
    if (!user) {
      return res.status(401).json({
        error: { message: 'Account not found. Please verify the email used for reset.' },
        requestId: req.requestId,
      });
    }

    const updatedUser = await updateUserPassword(user, password);
    db.passwordResets.delete(token);
    audit({
      userId: getUserId(updatedUser || user),
      action: 'RESET_PASSWORD',
      requestId: req.requestId,
    });

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

app.get('/api/services', async (req, res) => {
  try {
    const { category, freelancerId, status } = req.query;
    const filter = {};
    if (category) {
      filter.category = category;
    }
    if (freelancerId) {
      filter.freelancer = freelancerId;
    }
    filter.status = status || 'published';

    const services = await listServices(filter);
    const payload = await Promise.all(services.map((service) => formatServiceRecord(service)));
    return res.status(200).json({
      data: payload,
      requestId: req.requestId,
    });
  } catch (error) {
    console.error('[Services:list] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load services' },
      requestId: req.requestId,
    });
  }
});

app.get('/api/services/:serviceId', async (req, res) => {
  try {
    const service = await findServiceById(req.params.serviceId);
    if (!service) {
      return res.status(404).json({
        error: { message: 'Service not found' },
        requestId: req.requestId,
      });
    }
    return res.status(200).json({
      data: await formatServiceRecord(service),
      requestId: req.requestId,
    });
  } catch (error) {
    console.error('[Services:get] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load service' },
      requestId: req.requestId,
    });
  }
});

app.get('/api/services/mine', authGuard, requireRole('freelancer'), async (req, res) => {
  try {
    const services = await listServices({ freelancer: req.user.id });
    const payload = await Promise.all(services.map((service) => formatServiceRecord(service)));
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Services:mine] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load freelancer services' },
      requestId: req.requestId,
    });
  }
});

app.post(
  '/api/services',
  authGuard,
  requireRole('freelancer'),
  [
    body('title').isString().trim().isLength({ min: 3 }).withMessage('Title is required'),
    body('description').isString().trim().isLength({ min: 10 }).withMessage('Description is required'),
    body('category').isString().trim().notEmpty().withMessage('Category is required'),
    body('price').isNumeric().withMessage('Price must be a number'),
    body('deliveryTime').isInt({ min: 1 }).withMessage('Delivery time must be at least 1 day'),
    body('media').optional().isArray().withMessage('Media must be an array'),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const { title, description, category, price, deliveryTime, media, status } = req.body;
      const normalizedStatus = normalizeStatusInput(status, ['draft', 'published']);
      const service = await createServiceRecord({
        freelancer: req.user.id,
        title,
        description,
        category,
        price,
        deliveryTime,
        media: Array.isArray(media) ? media : [],
        status: normalizedStatus || 'published',
      });
      return res.status(201).json({
        data: await formatServiceRecord(service),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Services:create] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to create service' },
        requestId: req.requestId,
      });
    }
  },
);

app.put(
  '/api/services/:serviceId',
  authGuard,
  requireRole('freelancer'),
  [
    param('serviceId').isString().withMessage('Service id is required'),
    body('title').optional().isString().trim(),
    body('description').optional().isString().trim(),
    body('category').optional().isString().trim(),
    body('price').optional().isNumeric(),
    body('deliveryTime').optional().isInt({ min: 1 }),
    body('media').optional().isArray(),
    body('status').optional().isString(),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const service = await findServiceById(req.params.serviceId);
      if (!service) {
        return res.status(404).json({
          error: { message: 'Service not found' },
          requestId: req.requestId,
        });
      }

      const ownerId = ensureId(
        usingMemoryStore ? service.freelancer : service.freelancer?._id || service.freelancer,
      );
      if (req.user.role !== 'admin' && ownerId !== req.user.id) {
        return res.status(403).json({
          error: { message: 'You can only update your own services' },
          requestId: req.requestId,
        });
      }

      const updates = {};
      const { title, description, category, price, deliveryTime, media, status } = req.body;
      if (title) updates.title = title;
      if (description) updates.description = description;
      if (category) updates.category = category;
      if (price !== undefined) updates.price = price;
      if (deliveryTime !== undefined) updates.deliveryTime = deliveryTime;
      if (Array.isArray(media)) updates.media = media;
      if (status) {
        const normalized = normalizeStatusInput(status, ['draft', 'published', 'suspended']);
        if (normalized) {
          updates.status = normalized;
        }
      }

      if (!usingMemoryStore) {
        Object.assign(service, updates);
        await service.save();
      } else {
        Object.assign(service, updates, { updatedAt: new Date().toISOString() });
        db.services.set(service.id, service);
      }

      return res.status(200).json({
        data: await formatServiceRecord(service),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Services:update] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to update service' },
        requestId: req.requestId,
      });
    }
  },
);

app.post(
  '/api/orders',
  authGuard,
  requireRole('client'),
  [
    body('serviceId').isString().withMessage('Service id is required'),
    body('requirements').optional().isString(),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const { serviceId, requirements } = req.body;
      const service = await findServiceById(serviceId);
      if (!service) {
        return res.status(404).json({
          error: { message: 'Service not found' },
          requestId: req.requestId,
        });
      }

      const serviceRecord = await formatServiceRecord(service);
      if (serviceRecord.status === 'suspended') {
        return res.status(403).json({
          error: { message: 'Service is not available for purchase' },
          requestId: req.requestId,
        });
      }

      const expectedDelivery = new Date();
      expectedDelivery.setDate(expectedDelivery.getDate() + Number(serviceRecord.deliveryTime || 1));

      const order = await createOrderRecord({
        service: serviceRecord.id,
        client: req.user.id,
        freelancer: serviceRecord.freelancer,
        requirements: requirements || '',
        status: 'pending',
        totalAmount: serviceRecord.price,
        deliveryDate: expectedDelivery.toISOString(),
      });

      const orderId = ensureId(order.id || order._id);
      const { platformFee, freelancerAmount } = calculateEscrow(serviceRecord.price);
      await createTransactionRecord({
        order: orderId,
        amount: serviceRecord.price,
        platformFee,
        freelancerAmount,
        status: 'escrow',
        type: 'escrow',
      });

      return res.status(201).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:create] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to create order' },
        requestId: req.requestId,
      });
    }
  },
);

app.get('/api/orders', authGuard, async (req, res) => {
  try {
    const orders = req.user.role === 'admin' ? await listAllOrders() : await listOrdersForUser(req.user);
    const payload = await Promise.all(orders.map((order) => formatOrderRecord(order)));
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Orders:list] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load orders' },
      requestId: req.requestId,
    });
  }
});

app.get(
  '/api/orders/:orderId',
  authGuard,
  [param('orderId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      const ownerIds = [
        ensureId(usingMemoryStore ? order.client : order.client?._id || order.client),
        ensureId(usingMemoryStore ? order.freelancer : order.freelancer?._id || order.freelancer),
      ];
      if (req.user.role !== 'admin' && !ownerIds.includes(req.user.id)) {
        return res.status(403).json({
          error: { message: 'You do not have access to this order' },
          requestId: req.requestId,
        });
      }

      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:get] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to load order' },
        requestId: req.requestId,
      });
    }
  },
);

app.patch(
  '/api/orders/:orderId/accept',
  authGuard,
  requireRole('freelancer'),
  [param('orderId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      const freelancerId = ensureId(
        usingMemoryStore ? order.freelancer : order.freelancer?._id || order.freelancer,
      );
      if (freelancerId !== req.user.id) {
        return res.status(403).json({
          error: { message: 'You can only accept orders assigned to you' },
          requestId: req.requestId,
        });
      }

      order.status = 'accepted';
      await saveOrder(order);
      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:accept] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to accept order' },
        requestId: req.requestId,
      });
    }
  },
);

app.patch(
  '/api/orders/:orderId/deliver',
  authGuard,
  requireRole('freelancer'),
  [
    param('orderId').isString(),
    body('deliveredWork').isString().withMessage('Delivered work is required'),
    body('revisionNotes').optional().isString(),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      const freelancerId = ensureId(
        usingMemoryStore ? order.freelancer : order.freelancer?._id || order.freelancer,
      );
      if (freelancerId !== req.user.id) {
        return res.status(403).json({
          error: { message: 'You can only deliver orders assigned to you' },
          requestId: req.requestId,
        });
      }

      order.status = 'delivered';
      order.deliveredWork = req.body.deliveredWork;
      order.revisionNotes = req.body.revisionNotes || '';
      order.deliveredAt = new Date().toISOString();
      await saveOrder(order);

      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:deliver] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to deliver order' },
        requestId: req.requestId,
      });
    }
  },
);

app.patch(
  '/api/orders/:orderId/complete',
  authGuard,
  requireRole('client'),
  [param('orderId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      const clientId = ensureId(
        usingMemoryStore ? order.client : order.client?._id || order.client,
      );
      if (clientId !== req.user.id && req.user.role !== 'admin') {
        return res.status(403).json({
          error: { message: 'You can only complete your own orders' },
          requestId: req.requestId,
        });
      }

      order.status = 'completed';
      await saveOrder(order);

      const transaction = await findTransactionByOrder(req.params.orderId);
      if (transaction) {
        transaction.status = 'released';
        await saveTransaction(transaction);
        await createPayoutRecord({
          transaction: ensureId(transaction.id || transaction._id),
          freelancer: ensureId(
            usingMemoryStore ? order.freelancer : order.freelancer?._id || order.freelancer,
          ),
          amount: transaction.freelancerAmount,
          status: 'pending',
        });
      }

      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:complete] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to complete order' },
        requestId: req.requestId,
      });
    }
  },
);

app.patch(
  '/api/orders/:orderId/cancel',
  authGuard,
  [param('orderId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      const clientId = ensureId(
        usingMemoryStore ? order.client : order.client?._id || order.client,
      );
      const freelancerId = ensureId(
        usingMemoryStore ? order.freelancer : order.freelancer?._id || order.freelancer,
      );
      const isOwner = req.user.role === 'admin' || req.user.id === clientId || req.user.id === freelancerId;
      if (!isOwner) {
        return res.status(403).json({
          error: { message: 'You are not allowed to cancel this order' },
          requestId: req.requestId,
        });
      }

      order.status = 'cancelled';
      await saveOrder(order);

      const transaction = await findTransactionByOrder(req.params.orderId);
      if (transaction) {
        transaction.status = 'refunded';
        await saveTransaction(transaction);
      }

      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Orders:cancel] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to cancel order' },
        requestId: req.requestId,
      });
    }
  },
);

app.get('/api/admin/services', authGuard, requireRole('admin'), async (req, res) => {
  try {
    const services = await listServices();
    const payload = await Promise.all(services.map((service) => formatServiceRecord(service)));
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Admin:services] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load services' },
      requestId: req.requestId,
    });
  }
});

app.patch(
  '/api/admin/services/:serviceId/status',
  authGuard,
  requireRole('admin'),
  [
    param('serviceId').isString(),
    body('status').isString().withMessage('Status is required'),
  ],
  handleValidationResult,
  async (req, res) => {
    try {
      const service = await findServiceById(req.params.serviceId);
      if (!service) {
        return res.status(404).json({
          error: { message: 'Service not found' },
          requestId: req.requestId,
        });
      }

      const normalized = normalizeStatusInput(req.body.status, ['draft', 'published', 'suspended']);
      if (!normalized) {
        return res.status(422).json({
          error: { message: 'Invalid status' },
          requestId: req.requestId,
        });
      }

      if (!usingMemoryStore) {
        service.status = normalized;
        await service.save();
      } else {
        service.status = normalized;
        service.updatedAt = new Date().toISOString();
        db.services.set(service.id, service);
      }

      return res.status(200).json({
        data: await formatServiceRecord(service),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Admin:serviceStatus] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to update service status' },
        requestId: req.requestId,
      });
    }
  },
);

app.get('/api/admin/orders', authGuard, requireRole('admin'), async (req, res) => {
  try {
    const orders = await listAllOrders();
    const payload = await Promise.all(orders.map((order) => formatOrderRecord(order)));
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Admin:orders] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load orders' },
      requestId: req.requestId,
    });
  }
});

app.get('/api/admin/transactions', authGuard, requireRole('admin'), async (req, res) => {
  try {
    const transactions = await listTransactions();
    const payload = await Promise.all(
      transactions.map((transaction) => formatTransactionRecord(transaction)),
    );
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Admin:transactions] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load transactions' },
      requestId: req.requestId,
    });
  }
});

app.get('/api/admin/payouts', authGuard, requireRole('admin'), async (req, res) => {
  try {
    const payouts = await listPayouts();
    const payload = await Promise.all(payouts.map((payout) => formatPayoutRecord(payout)));
    return res.status(200).json({ data: payload, requestId: req.requestId });
  } catch (error) {
    console.error('[Admin:payouts] Failed', error);
    return res.status(500).json({
      error: { message: 'Failed to load payouts' },
      requestId: req.requestId,
    });
  }
});

app.patch(
  '/api/admin/orders/:orderId/refund',
  authGuard,
  requireRole('admin'),
  [param('orderId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const order = await findOrderById(req.params.orderId);
      if (!order) {
        return res.status(404).json({
          error: { message: 'Order not found' },
          requestId: req.requestId,
        });
      }

      order.status = 'refunded';
      await saveOrder(order);

      const transaction = await findTransactionByOrder(req.params.orderId);
      if (transaction) {
        transaction.status = 'refunded';
        await saveTransaction(transaction);
      }

      return res.status(200).json({
        data: await formatOrderRecord(order),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Admin:refund] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to refund order' },
        requestId: req.requestId,
      });
    }
  },
);

app.patch(
  '/api/admin/payouts/:payoutId/release',
  authGuard,
  requireRole('admin'),
  [param('payoutId').isString()],
  handleValidationResult,
  async (req, res) => {
    try {
      const payout = await findPayoutById(req.params.payoutId);
      if (!payout) {
        return res.status(404).json({
          error: { message: 'Payout not found' },
          requestId: req.requestId,
        });
      }

      payout.status = 'paid';
      await savePayout(payout);

      return res.status(200).json({
        data: await formatPayoutRecord(payout),
        requestId: req.requestId,
      });
    } catch (error) {
      console.error('[Admin:payoutRelease] Failed', error);
      return res.status(500).json({
        error: { message: 'Failed to release payout' },
        requestId: req.requestId,
      });
    }
  },
);

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
    let connectedToMongo = false;
    try {
      await connectDB(process.env.MONGODB_URI);
      connectedToMongo = true;
    } catch (connectionError) {
      console.warn(
        `[Boot] MongoDB connection failed (${connectionError.message}). Falling back to in-memory data store.`,
      );
    }

    usingMemoryStore = !connectedToMongo;
    if (usingMemoryStore) {
      console.warn('[Boot] Data will not persist between restarts while using the in-memory store.');
    }

    if (APP_ENV !== 'production') {
      await (async () => {
        for (const account of privilegedAccounts) {
          const existing = await findUserByEmail(account.email);
          if (!existing) {
            await createUserRecord({
              ...account,
              verified: true,
            });
            console.log(`[SEED] ${account.role} user created`);
            continue;
          }

          let needsSave = false;
          if (!usingMemoryStore) {
            if (!existing.verified) {
              existing.verified = true;
              needsSave = true;
            }
            if (existing.role !== account.role) {
              existing.role = account.role;
              needsSave = true;
            }
            if (typeof existing.setPassword === 'function') {
              await existing.setPassword(account.password);
              needsSave = true;
            }
            if (needsSave) {
              await existing.save();
              console.log(`[SEED] ${account.email} synchronized`);
            }
          } else {
            const userRecord = existing;
            if (!userRecord.verified) {
              userRecord.verified = true;
              needsSave = true;
            }
            if (userRecord.role !== account.role) {
              userRecord.role = account.role;
              needsSave = true;
            }
            const shouldUpdatePassword =
              !userRecord.passwordHash ||
              !(await bcrypt.compare(account.password, userRecord.passwordHash));
            if (shouldUpdatePassword) {
              userRecord.passwordHash = await bcrypt.hash(account.password, 10);
              needsSave = true;
            }
            if (needsSave) {
              userRecord.updatedAt = new Date().toISOString();
              db.users.set(userRecord.id, userRecord);
              console.log(`[SEED] ${account.email} synchronized`);
            }
          }
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
      UserModel: connectedToMongo ? User : null,
    });

    const port = process.env.PORT || 4000;
    const host = process.env.HOST || '0.0.0.0';
    app.listen(port, host, () =>
      console.log(`API listening on http://${host}:${port}`),
    );
  } catch (e) {
    Sentry.captureException(e);
    console.error('[Boot] Failed:', e);
    process.exit(1);
  }
}

bootstrap();
