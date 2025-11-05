const express = require('express');
const crypto = require('crypto');
const router = express.Router();

const BILLPLZ_API_KEY = process.env.BILLPLZ_API_KEY || '';
const COLLECTION_ID = process.env.BILLPLZ_COLLECTION_ID || '';
const X_SIGNATURE = process.env.BILLPLZ_X_SIGNATURE || '';
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || 'http://localhost:4000';

/* Create bill and return pay_url */
router.post('/create', async (req, res) => {
  try {
    const { orderId, amount, email } = req.body;
    if (!orderId || !amount) return res.status(400).json({ error: 'orderId/amount required' });

    const payload = new URLSearchParams({
      collection_id: COLLECTION_ID,
      email: email || 'buyer@example.com',
      name: 'Freetask Order ' + orderId,
      amount: String(amount), // in sen
      callback_url: PUBLIC_BASE_URL + '/payments/webhook',
      description: 'Order ' + orderId
    });

    const response = await fetch('https://www.billplz.com/api/v3/bills', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${Buffer.from(`${BILLPLZ_API_KEY}:`).toString('base64')}`,
      },
      body: payload.toString(),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Billplz error:', errorBody);
      return res.status(502).json({ error: 'failed_to_create_bill' });
    }

    const data = await response.json();

    return res.json({ pay_url: data.url, bill_id: data.id });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'failed_to_create_bill' });
  }
});

/* Webhook: verify X-Signature and update order -> paid */
router.post('/webhook', express.urlencoded({ extended: false }), async (req, res) => {
  try {
    const data = req.body; // billplz posts x-www-form-urlencoded
    const raw = `id${data.id}|paid_at${data.paid_at}|paid${data.paid}|x_signature${X_SIGNATURE}`;
    const expected = crypto.createHmac('sha256', X_SIGNATURE).update(raw).digest('hex');

    // NOTE: Billplz official signature format may vary; adjust per docs.
    if (data.x_signature !== expected) {
      return res.status(400).json({ error: 'invalid_signature' });
    }

    if (data.paid === 'true') {
      const orderId = (data.description || '').replace('Order ', '');
      // TODO: mark order as paid & move escrow -> pending release
      // e.g., await Orders.markPaid(orderId, data.id, data.paid_at);
    }
    res.status(200).send('OK');
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'webhook_error' });
  }
});

module.exports = router;
