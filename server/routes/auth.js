const express = require('express');
const { body, validationResult } = require('express-validator');

const { connectDB } = require('../db');
const User = require('../models/User');
const { requireAuth } = require('../middleware/auth');
const {
  signAccessToken,
  createRefreshToken,
  hashToken,
  verifyRefreshToken,
} = require('../utils/token');

const router = express.Router();

const allowedRoles = new Set([
  'client',
  'freelancer',
  'seller',
  'admin',
  'support',
  'manager',
]);

function buildUserPayload(user) {
  return {
    id: user._id.toString(),
    name: user.name,
    email: user.email,
    role: user.role,
    verified: user.verified,
  };
}

function handleValidation(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({
      message: 'Validation failed',
      errors: errors.array().map((error) => ({
        field: error.path,
        message: error.msg,
      })),
    });
  }
  return null;
}

router.post(
  '/register',
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').isEmail().withMessage('Valid email is required'),
    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters'),
    body('role')
      .optional()
      .custom((value) => allowedRoles.has(value))
      .withMessage('Role is not supported'),
  ],
  async (req, res, next) => {
    const validationError = handleValidation(req, res);
    if (validationError) {
      return validationError;
    }

    const { name, email, password, role = 'client' } = req.body;

    try {
      await connectDB();

      const existingUser = await User.findOne({ email: email.toLowerCase() });
      if (existingUser) {
        return res.status(409).json({
          message: 'Email is already registered',
        });
      }

      const user = new User({
        name: name.trim(),
        email: email.toLowerCase(),
        role,
      });

      await user.setPassword(password);

      const access = signAccessToken(user);
      const refresh = createRefreshToken();

      user.refreshTokenHash = refresh.tokenHash;
      user.refreshTokenExpiresAt = refresh.expiresAt;
      await user.save();

      return res.status(201).json({
        token: access.token,
        refreshToken: refresh.token,
        expiresIn: access.expiresIn,
        expiresAt: access.expiresAt.toISOString(),
        user: buildUserPayload(user),
      });
    } catch (error) {
      console.error('[Auth] Registration failed:', error);
      return next(error);
    }
  }
);

router.post(
  '/login',
  [
    body('email').isEmail().withMessage('Valid email is required'),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  async (req, res, next) => {
    const validationError = handleValidation(req, res);
    if (validationError) {
      return validationError;
    }

    const { email, password } = req.body;

    try {
      await connectDB();

      const user = await User.findOne({ email: email.toLowerCase() });
      if (!user) {
        return res.status(401).json({
          message: 'Invalid email or password',
        });
      }

      const passwordMatches = await user.verifyPassword(password);
      if (!passwordMatches) {
        return res.status(401).json({
          message: 'Invalid email or password',
        });
      }

      const access = signAccessToken(user);
      const refresh = createRefreshToken();

      user.refreshTokenHash = refresh.tokenHash;
      user.refreshTokenExpiresAt = refresh.expiresAt;
      await user.save();

      return res.json({
        token: access.token,
        refreshToken: refresh.token,
        expiresIn: access.expiresIn,
        expiresAt: access.expiresAt.toISOString(),
        user: buildUserPayload(user),
      });
    } catch (error) {
      console.error('[Auth] Login failed:', error);
      return next(error);
    }
  }
);

router.post(
  '/refresh',
  [body('refreshToken').notEmpty().withMessage('Refresh token is required')],
  async (req, res, next) => {
    const validationError = handleValidation(req, res);
    if (validationError) {
      return validationError;
    }

    const { refreshToken } = req.body;

    try {
      await connectDB();

      const tokenHash = hashToken(refreshToken);
      const user = await User.findOne({ refreshTokenHash: tokenHash });

      if (!user) {
        return res.status(401).json({ message: 'Invalid refresh token' });
      }

      if (
        !user.refreshTokenExpiresAt ||
        user.refreshTokenExpiresAt.getTime() <= Date.now()
      ) {
        user.clearRefreshToken();
        await user.save();
        return res.status(401).json({ message: 'Refresh token expired' });
      }

      if (!verifyRefreshToken(refreshToken, user.refreshTokenHash)) {
        return res.status(401).json({ message: 'Invalid refresh token' });
      }

      const access = signAccessToken(user);
      const nextRefresh = createRefreshToken();

      user.refreshTokenHash = nextRefresh.tokenHash;
      user.refreshTokenExpiresAt = nextRefresh.expiresAt;
      await user.save();

      return res.json({
        token: access.token,
        refreshToken: nextRefresh.token,
        expiresIn: access.expiresIn,
        expiresAt: access.expiresAt.toISOString(),
        user: buildUserPayload(user),
      });
    } catch (error) {
      console.error('[Auth] Token refresh failed:', error);
      return next(error);
    }
  }
);

router.post(
  '/logout',
  [
    body('refreshToken')
      .optional()
      .customSanitizer((value) => value || ''),
  ],
  async (req, res, next) => {
    const { refreshToken = '' } = req.body;

    if (!refreshToken) {
      return res.status(204).send();
    }

    try {
      await connectDB();

      const tokenHash = hashToken(refreshToken);
      const user = await User.findOne({ refreshTokenHash: tokenHash });

      if (!user) {
        return res.status(204).send();
      }

      user.clearRefreshToken();
      await user.save();

      return res.status(204).send();
    } catch (error) {
      console.error('[Auth] Logout failed:', error);
      return next(error);
    }
  }
);

router.get('/me', requireAuth, async (req, res) => {
  return res.json({ user: req.user });
});

module.exports = router;
