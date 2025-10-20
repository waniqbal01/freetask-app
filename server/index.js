const http = require('http');
const crypto = require('crypto');
const { URL } = require('url');

const PORT = process.env.PORT || 4000;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ACCESS_TOKEN_TTL = 15 * 60; // 15 minutes
const REFRESH_TOKEN_TTL = 7 * 24 * 60 * 60; // 7 days

const RESPONSE_FIELDS = ['id', 'title', 'status', 'category', 'budget', 'payment_state', 'createdAt'];

const db = {
  users: new Map(),
  jobs: new Map(),
  bids: new Map(),
  chatMessages: new Map(),
  payments: new Map(),
  walletTransactions: new Map(),
  notifications: new Map(),
  reviews: new Map(),
  refreshTokens: new Map(),
  otps: new Map(),
  auditLogs: [],
  idempotency: new Map(),
};

const rateLimitState = new Map();

const jobStatusTransitions = {
  OPEN: ['IN_PROGRESS', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

const jobStatusRoles = {
  OPEN: ['client', 'admin'],
  IN_PROGRESS: ['client', 'admin'],
  COMPLETED: ['client', 'admin'],
  CANCELLED: ['client', 'admin'],
};

const requestHandlers = [];
const websocketClients = new Map();

function registerRoute(method, path, handler, options = {}) {
  const { regex, keys } = pathToRegex(path);
  requestHandlers.push({ method, regex, keys, handler, ...options });
}

function pathToRegex(path) {
  const parts = path.split('/').filter(Boolean);
  const keys = [];
  const pattern = parts
    .map((part) => {
      if (part.startsWith(':')) {
        keys.push(part.slice(1));
        return '([^/]+)';
      }
      if (part === '*') {
        keys.push('wildcard');
        return '(.*)';
      }
      return part;
    })
    .join('/');
  const regex = new RegExp(`^/${pattern}$`);
  return { regex, keys };
}

function sendJson(res, status, body, requestId) {
  const payload = body && typeof body === 'object' ? { ...body, requestId } : body;
  const data = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data),
    'X-Request-Id': requestId,
  });
  res.end(data);
}

function sendError(res, status, message, requestId, details) {
  sendJson(
    res,
    status,
    {
      error: {
        message,
        details,
      },
    },
    requestId
  );
}

function parseBody(req, limitBytes = 1 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let body = Buffer.alloc(0);
    req.on('data', (chunk) => {
      body = Buffer.concat([body, chunk]);
      if (body.length > limitBytes) {
        reject(new Error('Payload too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!body.length) {
        resolve(null);
        return;
      }
      const contentType = req.headers['content-type'] || '';
      if (contentType.includes('application/json')) {
        try {
          resolve(JSON.parse(body.toString('utf8')));
        } catch (err) {
          reject(new Error('Invalid JSON body'));
        }
      } else {
        resolve(body);
      }
    });
    req.on('error', reject);
  });
}

async function readJsonBody(req, res, requestId, limitBytes) {
  try {
    const body = await parseBody(req, limitBytes);
    if (body === null) return {};
    if (Buffer.isBuffer(body)) {
      sendError(res, 415, 'Unsupported media type', requestId);
      return null;
    }
    return body;
  } catch (err) {
    sendError(res, 400, err.message || 'Invalid request body', requestId);
    return null;
  }
}

function createJwt(payload, ttlSeconds) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + ttlSeconds;
  const body = Buffer.from(JSON.stringify({ ...payload, exp })).toString('base64url');
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyJwt(token) {
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, body, signature] = parts;
  const expected = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    return null;
  }
  const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  if (payload.exp * 1000 < Date.now()) {
    return null;
  }
  return payload;
}

function authenticate(req) {
  const header = req.headers['authorization'];
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return null;
  return verifyJwt(token);
}

function rateLimit(key, { windowMs = 60_000, max = 5 }) {
  const now = Date.now();
  const record = rateLimitState.get(key) || { count: 0, resetAt: now + windowMs };
  if (now > record.resetAt) {
    record.count = 0;
    record.resetAt = now + windowMs;
  }
  record.count += 1;
  rateLimitState.set(key, record);
  return record.count <= max;
}

function ensureRateLimit(req, res, key, options, requestId) {
  if (!rateLimit(key, options)) {
    res.setHeader('Retry-After', Math.ceil((rateLimitState.get(key).resetAt - Date.now()) / 1000));
    sendError(res, 429, 'Too many requests', requestId);
    return false;
  }
  return true;
}

function logAudit({ userId, action, entity, requestId, metadata }) {
  db.auditLogs.push({
    timestamp: new Date().toISOString(),
    userId,
    action,
    entity,
    requestId,
    metadata: metadata || null,
  });
}

function paginate(array, page = 1, pageSize = 10) {
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  const items = array.slice(start, end);
  return { items, total: array.length, page, pageSize };
}

function requireAuth(req, res, requestId) {
  const payload = authenticate(req);
  if (!payload) {
    sendError(res, 401, 'Authentication required', requestId);
    return null;
  }
  const user = db.users.get(payload.sub);
  if (!user) {
    sendError(res, 401, 'Invalid token', requestId);
    return null;
  }
  req.user = user;
  return user;
}

function requireRole(user, role, res, requestId) {
  if (!user.roles.includes(role) && !user.roles.includes('admin')) {
    sendError(res, 403, 'Insufficient permissions', requestId);
    return false;
  }
  return true;
}

function validate(schema, data) {
  const errors = [];
  for (const field of Object.keys(schema)) {
    const rules = schema[field];
    const value = data[field];
    if (rules.required && (value === undefined || value === null || value === '')) {
      errors.push(`${field} is required`);
      continue;
    }
    if (value === undefined || value === null) {
      continue;
    }
    if (rules.type === 'string' && typeof value !== 'string') {
      errors.push(`${field} must be a string`);
    }
    if (rules.type === 'number' && typeof value !== 'number') {
      errors.push(`${field} must be a number`);
    }
    if (rules.enum && !rules.enum.includes(value)) {
      errors.push(`${field} must be one of ${rules.enum.join(', ')}`);
    }
    if (rules.maxLength && typeof value === 'string' && value.length > rules.maxLength) {
      errors.push(`${field} exceeds maximum length`);
    }
    if (rules.min && typeof value === 'number' && value < rules.min) {
      errors.push(`${field} must be >= ${rules.min}`);
    }
  }
  return errors;
}

function virusScanStub(contentBuffer) {
  return true;
}

function pickJobProjection(job) {
  const projection = {};
  for (const key of RESPONSE_FIELDS) {
    if (job[key] !== undefined) {
      projection[key] = job[key];
    }
  }
  return projection;
}

function canAccessJobChat(user, job) {
  if (!user || !job) return false;
  if (user.roles.includes('admin')) return true;
  if (job.ownerId === user.id) return true;
  for (const bid of db.bids.values()) {
    if (bid.jobId === job.id && bid.userId === user.id) {
      return true;
    }
  }
  return false;
}

function registerAuthRoutes() {
  registerRoute('POST', '/auth/login', async (req, res, params, query, requestId) => {
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    if (!body || typeof body.email !== 'string') {
      sendError(res, 400, 'Email is required', requestId);
      return;
    }
    const limiterKey = `login:${req.socket.remoteAddress || 'unknown'}`;
    if (!ensureRateLimit(req, res, limiterKey, { windowMs: 60_000, max: 5 }, requestId)) {
      return;
    }
    let user = null;
    for (const record of db.users.values()) {
      if (record.email === body.email) {
        user = record;
        break;
      }
    }
    if (!user) {
      sendError(res, 404, 'User not found', requestId);
      return;
    }
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    db.otps.set(body.email, { otp, expiresAt: Date.now() + 5 * 60_000 });
    logAudit({ userId: user.id, action: 'REQUEST_OTP', entity: 'auth', requestId });
    sendJson(res, 200, { data: { otpSent: true, otp }, message: 'OTP dispatched for verification' }, requestId);
  });

  registerRoute('POST', '/auth/verify-otp', async (req, res, params, query, requestId) => {
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        email: { required: true, type: 'string' },
        otp: { required: true, type: 'string' },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const limiterKey = `otp:${req.socket.remoteAddress || 'unknown'}`;
    if (!ensureRateLimit(req, res, limiterKey, { windowMs: 60_000, max: 10 }, requestId)) {
      return;
    }
    const otpRecord = db.otps.get(body.email);
    if (!otpRecord || otpRecord.otp !== body.otp) {
      sendError(res, 401, 'Invalid OTP', requestId);
      return;
    }
    if (otpRecord.expiresAt < Date.now()) {
      sendError(res, 401, 'OTP expired', requestId);
      return;
    }
    db.otps.delete(body.email);
    const user = Array.from(db.users.values()).find((u) => u.email === body.email);
    if (!user) {
      sendError(res, 404, 'User not found', requestId);
      return;
    }
    const accessToken = createJwt({ sub: user.id, roles: user.roles }, ACCESS_TOKEN_TTL);
    const refreshToken = crypto.randomBytes(32).toString('hex');
    db.refreshTokens.set(refreshToken, { userId: user.id, expiresAt: Date.now() + REFRESH_TOKEN_TTL * 1000 });
    logAudit({ userId: user.id, action: 'LOGIN', entity: 'auth', requestId });
    sendJson(
      res,
      200,
      {
        data: {
          accessToken,
          refreshToken,
          user: { id: user.id, name: user.name, role: user.roles[0] },
        },
      },
      requestId
    );
  });

  registerRoute('POST', '/auth/refresh', async (req, res, params, query, requestId) => {
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    if (!body || typeof body.refreshToken !== 'string') {
      sendError(res, 400, 'refreshToken is required', requestId);
      return;
    }
    const record = db.refreshTokens.get(body.refreshToken);
    if (!record || record.expiresAt < Date.now()) {
      sendError(res, 401, 'Invalid refresh token', requestId);
      return;
    }
    const user = db.users.get(record.userId);
    if (!user) {
      sendError(res, 401, 'Invalid refresh token', requestId);
      return;
    }
    const accessToken = createJwt({ sub: user.id, roles: user.roles }, ACCESS_TOKEN_TTL);
    sendJson(res, 200, { data: { accessToken } }, requestId);
  });
}

function registerJobRoutes() {
  registerRoute('GET', '/jobs', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const status = query.get('status');
    const category = query.get('category');
    const search = query.get('search');
    const page = parseInt(query.get('page') || '1', 10);
    const pageSize = Math.min(50, parseInt(query.get('pageSize') || '10', 10));
    let jobs = Array.from(db.jobs.values());
    if (status) {
      jobs = jobs.filter((job) => job.status === status);
    }
    if (category) {
      jobs = jobs.filter((job) => job.category === category);
    }
    if (search) {
      jobs = jobs.filter((job) => job.title.toLowerCase().includes(search.toLowerCase()));
    }
    jobs.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const { items, total } = paginate(jobs, page, pageSize);
    sendJson(
      res,
      200,
      {
        data: {
          items: items.map(pickJobProjection),
          page,
          pageSize,
          total,
        },
      },
      requestId
    );
  });

  registerRoute('POST', '/jobs', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    if (!requireRole(user, 'client', res, requestId)) return;
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        title: { required: true, type: 'string', maxLength: 120 },
        description: { required: true, type: 'string' },
        category: { required: true, type: 'string' },
        budget: { required: true, type: 'number', min: 0 },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    const job = {
      id,
      ownerId: user.id,
      title: body.title,
      description: body.description,
      category: body.category,
      budget: body.budget,
      status: 'OPEN',
      payment_state: 'PENDING_ESCROW',
      createdAt: now,
      updatedAt: now,
    };
    db.jobs.set(id, job);
    logAudit({ userId: user.id, action: 'CREATE', entity: 'job', requestId, metadata: { jobId: id } });
    sendJson(res, 201, { data: pickJobProjection(job) }, requestId);
  });

  registerRoute('PATCH', '/jobs/:jobId/status', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const job = db.jobs.get(params.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    if (!canAccessJobChat(user, job)) {
      sendError(res, 403, 'Chat access denied', requestId);
      return;
    }
    if (job.ownerId !== user.id && !user.roles.includes('admin')) {
      sendError(res, 403, 'Insufficient permissions', requestId);
      return;
    }
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        status: { required: true, type: 'string', enum: ['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const targetStatus = body.status;
    const allowed = jobStatusTransitions[job.status] || [];
    if (!allowed.includes(targetStatus)) {
      sendError(res, 409, 'Invalid status transition', requestId, { from: job.status, to: targetStatus });
      return;
    }
    const allowedRoles = jobStatusRoles[targetStatus] || [];
    if (!allowedRoles.some((role) => user.roles.includes(role))) {
      sendError(res, 403, 'Role not allowed for transition', requestId);
      return;
    }
    job.status = targetStatus;
    job.updatedAt = new Date().toISOString();
    logAudit({ userId: user.id, action: 'UPDATE_STATUS', entity: 'job', requestId, metadata: { jobId: job.id, status: job.status } });
    sendJson(res, 200, { data: pickJobProjection(job) }, requestId);
  });
}

function registerBidRoutes() {
  registerRoute('POST', '/bids', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    if (!requireRole(user, 'freelancer', res, requestId)) return;
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        jobId: { required: true, type: 'string' },
        amount: { required: true, type: 'number', min: 0 },
        message: { required: true, type: 'string', maxLength: 500 },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const job = db.jobs.get(body.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    if (job.status !== 'OPEN') {
      sendError(res, 409, 'Bids only allowed on OPEN jobs', requestId);
      return;
    }
    const bidId = crypto.randomUUID();
    const record = {
      id: bidId,
      jobId: job.id,
      userId: user.id,
      amount: body.amount,
      message: body.message,
      createdAt: new Date().toISOString(),
    };
    db.bids.set(bidId, record);
    logAudit({ userId: user.id, action: 'CREATE', entity: 'bid', requestId, metadata: { jobId: job.id } });
    sendJson(res, 201, { data: { id: record.id, jobId: record.jobId, amount: record.amount, createdAt: record.createdAt } }, requestId);
  });
}

function ensureChatRoom(jobId) {
  if (!db.chatMessages.has(jobId)) {
    db.chatMessages.set(jobId, []);
  }
  if (!websocketClients.has(jobId)) {
    websocketClients.set(jobId, new Set());
  }
}

function registerChatRoutes() {
  registerRoute('GET', '/chat/:jobId/messages', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const job = db.jobs.get(params.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    if (!canAccessJobChat(user, job)) {
      sendError(res, 403, 'Chat access denied', requestId);
      return;
    }
    const page = parseInt(query.get('page') || '1', 10);
    const pageSize = Math.min(50, parseInt(query.get('pageSize') || '20', 10));
    ensureChatRoom(job.id);
    const messages = db.chatMessages.get(job.id);
    messages.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    const { items, total } = paginate(messages, page, pageSize);
    sendJson(res, 200, { data: { items, page, pageSize, total } }, requestId);
  });

  registerRoute('POST', '/chat/:jobId/messages', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const job = db.jobs.get(params.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    const body = await readJsonBody(req, res, requestId, 12 * 1024 * 1024);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        message: { required: true, type: 'string', maxLength: 2000 },
        attachment: { type: 'string' },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    if (body.attachment) {
      let attachment;
      try {
        attachment = Buffer.from(body.attachment, 'base64');
      } catch (err) {
        sendError(res, 422, 'Attachment must be base64 encoded', requestId);
        return;
      }
      if (attachment.length > 10 * 1024 * 1024) {
        sendError(res, 413, 'Attachment too large', requestId);
        return;
      }
      if (!virusScanStub(attachment)) {
        sendError(res, 422, 'Attachment failed virus scan', requestId);
        return;
      }
    }
    const record = {
      id: crypto.randomUUID(),
      jobId: job.id,
      userId: user.id,
      message: body.message,
      attachment: body.attachment ? true : false,
      createdAt: new Date().toISOString(),
    };
    ensureChatRoom(job.id);
    db.chatMessages.get(job.id).push(record);
    broadcastChatMessage(job.id, { type: 'chat_message', payload: record });
    sendJson(res, 201, { data: record }, requestId);
  });
}

function registerPaymentRoutes() {
  registerRoute('POST', '/payments/escrow', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    if (!requireRole(user, 'client', res, requestId)) return;
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        jobId: { required: true, type: 'string' },
        amount: { required: true, type: 'number', min: 0 },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const job = db.jobs.get(body.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    job.payment_state = 'ESCROWED';
    if (job.status === 'OPEN') {
      job.status = 'IN_PROGRESS';
    }
    const paymentId = crypto.randomUUID();
    db.payments.set(paymentId, {
      id: paymentId,
      jobId: job.id,
      clientId: user.id,
      amount: body.amount,
      state: 'ESCROWED',
      createdAt: new Date().toISOString(),
    });
    addWalletTransaction(user.id, {
      id: crypto.randomUUID(),
      type: 'ESCROW',
      jobId: job.id,
      amount: -Math.abs(body.amount),
    });
    logAudit({ userId: user.id, action: 'ESCROW', entity: 'payment', requestId, metadata: { jobId: job.id } });
    sendJson(res, 201, { data: { jobId: job.id, payment_state: job.payment_state, status: job.status } }, requestId);
  });

  registerRoute('POST', '/payments/release', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    if (!requireRole(user, 'client', res, requestId)) return;
    const idemKey = req.headers['idempotency-key'];
    if (!idemKey) {
      sendError(res, 400, 'Idempotency-Key header is required', requestId);
      return;
    }
    if (db.idempotency.has(idemKey)) {
      const previous = db.idempotency.get(idemKey);
      sendJson(res, previous.status, previous.body, requestId);
      return;
    }
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        jobId: { required: true, type: 'string' },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const job = db.jobs.get(body.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    if (job.payment_state !== 'ESCROWED') {
      sendError(res, 409, 'Payment not in escrowed state', requestId);
      return;
    }
    job.payment_state = 'RELEASED';
    job.status = 'COMPLETED';
    logAudit({ userId: user.id, action: 'RELEASE', entity: 'payment', requestId, metadata: { jobId: job.id } });
    const bodyResponse = { data: { jobId: job.id, payment_state: job.payment_state, status: job.status } };
    db.idempotency.set(idemKey, { status: 200, body: bodyResponse });
    sendJson(res, 200, bodyResponse, requestId);
  });
}

function addWalletTransaction(userId, transaction) {
  if (!db.walletTransactions.has(userId)) {
    db.walletTransactions.set(userId, []);
  }
  db.walletTransactions.get(userId).push({
    ...transaction,
    createdAt: new Date().toISOString(),
  });
}

function registerWalletRoutes() {
  registerRoute('GET', '/wallet/transactions', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const page = parseInt(query.get('page') || '1', 10);
    const pageSize = Math.min(50, parseInt(query.get('pageSize') || '20', 10));
    const transactions = db.walletTransactions.get(user.id) || [];
    transactions.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const { items, total } = paginate(transactions, page, pageSize);
    sendJson(res, 200, { data: { items, page, pageSize, total } }, requestId);
  });
}

function registerNotificationRoutes() {
  registerRoute('GET', '/notifications', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const category = query.get('category');
    const page = parseInt(query.get('page') || '1', 10);
    const pageSize = Math.min(50, parseInt(query.get('pageSize') || '20', 10));
    const notifications = db.notifications.get(user.id) || [];
    let filtered = notifications;
    if (category) {
      filtered = notifications.filter((item) => item.category === category);
    }
    filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const { items, total } = paginate(filtered, page, pageSize);
    sendJson(res, 200, { data: { items, page, pageSize, total } }, requestId);
  });
}

function registerReviewRoutes() {
  registerRoute('POST', '/reviews', async (req, res, params, query, requestId) => {
    const user = requireAuth(req, res, requestId);
    if (!user) return;
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    const errors = validate(
      {
        jobId: { required: true, type: 'string' },
        rating: { required: true, type: 'number', min: 1 },
        comment: { required: true, type: 'string', maxLength: 500 },
      },
      body || {}
    );
    if (errors.length) {
      sendError(res, 422, 'Validation failed', requestId, errors);
      return;
    }
    const job = db.jobs.get(body.jobId);
    if (!job) {
      sendError(res, 404, 'Job not found', requestId);
      return;
    }
    if (job.status !== 'COMPLETED') {
      sendError(res, 409, 'Reviews allowed only for completed jobs', requestId);
      return;
    }
    const reviewId = crypto.randomUUID();
    const record = {
      id: reviewId,
      jobId: job.id,
      reviewerId: user.id,
      rating: body.rating,
      comment: body.comment,
      createdAt: new Date().toISOString(),
    };
    db.reviews.set(reviewId, record);
    logAudit({ userId: user.id, action: 'CREATE', entity: 'review', requestId, metadata: { jobId: job.id } });
    sendJson(res, 201, { data: record }, requestId);
  });
}

function registerWebhookRoutes() {
  registerRoute('POST', '/webhooks/billplz', async (req, res, params, query, requestId) => {
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    handleWebhookUpdate(body, 'billplz', requestId);
    sendJson(res, 202, { data: { received: true } }, requestId);
  });

  registerRoute('POST', '/webhooks/stripe', async (req, res, params, query, requestId) => {
    const body = await readJsonBody(req, res, requestId);
    if (body === null) {
      return;
    }
    handleWebhookUpdate(body, 'stripe', requestId);
    sendJson(res, 202, { data: { received: true } }, requestId);
  });
}

function handleWebhookUpdate(body, provider, requestId) {
  if (!body || !body.jobId || !body.state) {
    return;
  }
  const job = db.jobs.get(body.jobId);
  if (!job) {
    return;
  }
  if (body.state === 'ESCROWED') {
    job.payment_state = 'ESCROWED';
  }
  if (body.state === 'RELEASED') {
    job.payment_state = 'RELEASED';
    job.status = 'COMPLETED';
  }
  logAudit({ userId: body.userId || null, action: provider.toUpperCase(), entity: 'webhook', requestId, metadata: body });
}

function registerSystemRoutes() {
  registerRoute('GET', '/healthz', async (req, res, params, query, requestId) => {
    sendJson(res, 200, { data: { status: 'ok' } }, requestId);
  });

  registerRoute('GET', '/readyz', async (req, res, params, query, requestId) => {
    sendJson(res, 200, { data: { status: 'ready' } }, requestId);
  });
}

function broadcastChatMessage(jobId, payload) {
  const clients = websocketClients.get(jobId);
  if (!clients) return;
  for (const socket of clients) {
    sendWebSocketMessage(socket, JSON.stringify(payload));
  }
}

function sendWebSocketMessage(socket, message) {
  const data = Buffer.from(message);
  let headerLength = 2;
  let payloadIndicator = data.length;
  if (data.length >= 126 && data.length <= 0xffff) {
    headerLength += 2;
    payloadIndicator = 126;
  } else if (data.length > 0xffff) {
    headerLength += 8;
    payloadIndicator = 127;
  }
  const frame = Buffer.alloc(headerLength + data.length);
  frame[0] = 0x81; // FIN + text frame
  if (payloadIndicator === 126) {
    frame[1] = 126;
    frame.writeUInt16BE(data.length, 2);
    data.copy(frame, 4);
  } else if (payloadIndicator === 127) {
    frame[1] = 127;
    frame.writeBigUInt64BE(BigInt(data.length), 2);
    data.copy(frame, 10);
  } else {
    frame[1] = data.length;
    data.copy(frame, 2);
  }
  socket.write(frame);
}

function setupWebsocket(server) {
  server.on('upgrade', (req, socket) => {
    const url = new URL(req.url, 'http://localhost');
    if (!url.pathname.startsWith('/chat')) {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
      return;
    }
    const payload = authenticateUpgrade(req);
    if (!payload) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }
    const jobId = url.pathname.split('/')[2];
    if (!db.jobs.has(jobId)) {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
      return;
    }
    const job = db.jobs.get(jobId);
    const user = db.users.get(payload.sub);
    if (!canAccessJobChat(user, job)) {
      socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
      socket.destroy();
      return;
    }
    const acceptKey = generateAcceptValue(req.headers['sec-websocket-key']);
    const responseHeaders = [
      'HTTP/1.1 101 Switching Protocols',
      'Upgrade: websocket',
      'Connection: Upgrade',
      `Sec-WebSocket-Accept: ${acceptKey}`,
    ];
    socket.write(responseHeaders.concat('\r\n').join('\r\n'));
    ensureChatRoom(jobId);
    websocketClients.get(jobId).add(socket);
    socket.on('close', () => {
      const clients = websocketClients.get(jobId);
      if (clients) {
        clients.delete(socket);
      }
    });
    socket.on('data', (buffer) => {
      const message = decodeWebSocketFrame(buffer);
      if (!message) return;
      try {
        const payload = JSON.parse(message);
        if (payload.type === 'typing') {
          const echo = JSON.stringify({ type: 'typing', payload: { userId: user.id } });
          for (const client of websocketClients.get(jobId) || []) {
            if (client !== socket) {
              sendWebSocketMessage(client, echo);
            }
          }
        } else if (payload.type === 'chat_message') {
          const record = {
            id: crypto.randomUUID(),
            jobId,
            userId: user.id,
            message: payload.message,
            attachment: false,
            createdAt: new Date().toISOString(),
          };
          db.chatMessages.get(jobId).push(record);
          broadcastChatMessage(jobId, { type: 'chat_message', payload: record });
        }
      } catch (err) {
        // ignore malformed payloads
      }
    });
  });
}

function authenticateUpgrade(req) {
  const header = req.headers['authorization'];
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return null;
  const payload = verifyJwt(token);
  if (!payload) return null;
  if (!db.users.has(payload.sub)) return null;
  return payload;
}

function generateAcceptValue(secKey) {
  return crypto
    .createHash('sha1')
    .update(secKey + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', 'binary')
    .digest('base64');
}

function decodeWebSocketFrame(buffer) {
  const firstByte = buffer[0];
  const opCode = firstByte & 0x0f;
  if (opCode === 0x8) {
    return null;
  }
  const secondByte = buffer[1];
  const isMasked = (secondByte & 0x80) === 0x80;
  let payloadLength = secondByte & 0x7f;
  let offset = 2;
  if (payloadLength === 126) {
    payloadLength = buffer.readUInt16BE(offset);
    offset += 2;
  } else if (payloadLength === 127) {
    payloadLength = Number(buffer.readBigUInt64BE(offset));
    offset += 8;
  }
  let maskingKey = null;
  if (isMasked) {
    maskingKey = buffer.slice(offset, offset + 4);
    offset += 4;
  }
  const data = buffer.slice(offset, offset + payloadLength);
  if (isMasked && maskingKey) {
    for (let i = 0; i < data.length; i += 1) {
      data[i] ^= maskingKey[i % 4];
    }
  }
  return data.toString('utf8');
}

function createServer() {
  seedData();
  const server = http.createServer(async (req, res) => {
    const requestId = crypto.randomUUID();
    res.setHeader('X-Request-Id', requestId);
    res.setHeader('Cache-Control', req.method === 'GET' ? 'no-store' : 'no-cache');
    res.setHeader('X-Retryable', req.method === 'GET' ? 'true' : 'false');
    try {
      const url = new URL(req.url, `http://${req.headers.host}`);
      const query = url.searchParams;
      let matched = false;
      for (const route of requestHandlers) {
        if (route.method !== req.method) continue;
        const match = url.pathname.match(route.regex);
        if (match) {
          matched = true;
          const params = {};
          route.keys.forEach((key, index) => {
            params[key] = match[index + 1];
          });
          await route.handler(req, res, params, query, requestId);
          break;
        }
      }
      if (!matched) {
        if (!res.headersSent) {
          sendError(res, 404, 'Not found', requestId);
        }
      }
    } catch (err) {
      sendError(res, 500, 'Unexpected error', requestId);
    }
  });

  setupWebsocket(server);

  server.listen(PORT, () => {
    console.log(`API server listening on port ${PORT}`);
  });

  const gracefulShutdown = () => {
    console.log('Received shutdown signal, closing server...');
    server.close(() => {
      console.log('HTTP server closed');
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGTERM', gracefulShutdown);
  process.on('SIGINT', gracefulShutdown);

  return server;
}

function seedData() {
  if (db.users.size) return;
  const users = [
    { id: 'u-client', name: 'Client One', email: 'client@example.com', roles: ['client'] },
    { id: 'u-freelancer', name: 'Freelancer One', email: 'freelancer@example.com', roles: ['freelancer'] },
    { id: 'u-admin', name: 'Admin User', email: 'admin@example.com', roles: ['admin'] },
  ];
  users.forEach((user) => db.users.set(user.id, user));

  const jobId = crypto.randomUUID();
  const job = {
    id: jobId,
    ownerId: 'u-client',
    title: 'Landing page redesign',
    description: 'Revamp marketing site',
    category: 'Design',
    budget: 1200,
    status: 'OPEN',
    payment_state: 'PENDING_ESCROW',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  db.jobs.set(jobId, job);
  db.notifications.set('u-client', [
    { id: crypto.randomUUID(), category: 'System', message: 'Welcome to FreeTask', createdAt: new Date().toISOString() },
  ]);
  db.notifications.set('u-freelancer', [
    { id: crypto.randomUUID(), category: 'Job', message: 'New job available', createdAt: new Date().toISOString() },
  ]);
}

registerAuthRoutes();
registerJobRoutes();
registerBidRoutes();
registerChatRoutes();
registerPaymentRoutes();
registerWalletRoutes();
registerNotificationRoutes();
registerReviewRoutes();
registerWebhookRoutes();
registerSystemRoutes();

createServer();
