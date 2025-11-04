function requireRole(...roles) {
  const allowed = roles.flat();
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: { message: 'Authentication required' },
        requestId: req.requestId,
      });
    }

    if (req.user.role === 'admin') {
      return next();
    }

    if (!allowed.includes(req.user.role)) {
      return res.status(403).json({
        error: {
          message: 'Insufficient permissions',
          requiredRoles: allowed,
        },
        requestId: req.requestId,
      });
    }

    return next();
  };
}

function userHasRole(user, roles) {
  if (!user) return false;
  if (user.role === 'admin') return true;
  const allowed = Array.isArray(roles) ? roles : [roles];
  return allowed.includes(user.role);
}

module.exports = { requireRole, userHasRole };
