const jwt = require('jsonwebtoken');

const { connectDB } = require('../db');
const User = require('../models/User');

const JWT_SECRET = process.env.JWT_SECRET || 'development-secret';

async function requireAuth(req, res, next) {
  const authHeader = req.header('Authorization') || '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : null;

  if (!token) {
    return res.status(401).json({ message: 'Missing authorization token' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);

    await connectDB();
    const user = await User.findById(payload.sub).lean();

    if (!user) {
      return res.status(401).json({ message: 'User not found' });
    }

    req.user = {
      id: user._id.toString(),
      email: user.email,
      name: user.name,
      role: user.role,
      verified: user.verified,
    };

    return next();
  } catch (error) {
    console.error('[Auth] Failed to verify token:', error.message);
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
