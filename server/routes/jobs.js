const express = require('express');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireAuth, async (req, res) => {
  return res.json({ ok: true, user: req.user });
});

module.exports = router;
