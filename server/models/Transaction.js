const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    order: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: true, index: true },
    amount: { type: Number, required: true, min: 0 },
    platformFee: { type: Number, required: true, min: 0 },
    freelancerAmount: { type: Number, required: true, min: 0 },
    status: {
      type: String,
      enum: ['escrow', 'released', 'refunded', 'disputed'],
      default: 'escrow',
      index: true,
    },
    type: {
      type: String,
      enum: ['escrow', 'payout', 'refund'],
      default: 'escrow',
    },
    notes: { type: String },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Transaction', transactionSchema);
