const admin = require('firebase-admin');
const { connectDB } = require('../db');
const User = require('../models/User');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

async function verifyFirebaseToken(req, res, next) {
  const authHeader = req.header('Authorization') || '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7).trim()
    : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing token' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);

    if (!decoded.email) {
      return res.status(403).json({ error: 'User email missing from token' });
    }

    await connectDB();

    const user = await User.findOne({ email: decoded.email }).lean();

    if (!user) {
      return res.status(403).json({ error: 'User not registered' });
    }

    req.user = {
      uid: decoded.uid,
      email: decoded.email,
      name: decoded.name || user.name,
      picture: decoded.picture,
      role: user.role,
      userId: user._id.toString(),
      firebaseClaims: decoded,
    };
    req.auth = req.user;

    return next();
  } catch (error) {
    console.error('[Auth] Failed to verify Firebase token:', error.message);
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = { verifyFirebaseToken };
