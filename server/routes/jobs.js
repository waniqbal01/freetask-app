const express = require('express');
const { verifyFirebaseToken } = require('../middleware/firebaseAuth');

const router = express.Router();

router.get('/', verifyFirebaseToken, async (req, res) => {
  const user = req.user;
  return res.json({ ok: true, user });
});

module.exports = router;
