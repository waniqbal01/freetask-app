const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const ACCESS_TOKEN_TTL = Number.parseInt(
  process.env.JWT_EXPIRES_IN || '900',
  10
);
const REFRESH_TOKEN_TTL = Number.parseInt(
  process.env.JWT_REFRESH_EXPIRES_IN || String(60 * 60 * 24 * 7),
  10
);

const JWT_SECRET = process.env.JWT_SECRET || 'development-secret';

function signAccessToken(user) {
  const payload = {
    sub: user._id.toString(),
    email: user.email,
    role: user.role,
    name: user.name,
  };

  const token = jwt.sign(payload, JWT_SECRET, {
    expiresIn: ACCESS_TOKEN_TTL,
  });

  const expiresAt = new Date(Date.now() + ACCESS_TOKEN_TTL * 1000);

  return {
    token,
    expiresIn: ACCESS_TOKEN_TTL,
    expiresAt,
  };
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function tokensEqual(expected, actual) {
  const a = Buffer.from(expected, 'hex');
  const b = Buffer.from(actual, 'hex');
  if (a.length !== b.length) {
    return false;
  }
  return crypto.timingSafeEqual(a, b);
}

function createRefreshToken() {
  const token = crypto.randomBytes(48).toString('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL * 1000);
  const tokenHash = hashToken(token);

  return {
    token,
    tokenHash,
    expiresIn: REFRESH_TOKEN_TTL,
    expiresAt,
  };
}

function verifyRefreshToken(token, hashed) {
  if (!token || !hashed) {
    return false;
  }
  const candidate = hashToken(token);
  return tokensEqual(candidate, hashed);
}

module.exports = {
  signAccessToken,
  createRefreshToken,
  hashToken,
  verifyRefreshToken,
  ACCESS_TOKEN_TTL,
  REFRESH_TOKEN_TTL,
};
