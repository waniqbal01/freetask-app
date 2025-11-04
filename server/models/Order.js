const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema(
  {
    service: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true, index: true },
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    freelancer: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    requirements: { type: String, default: '' },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'in_progress', 'delivered', 'completed', 'cancelled', 'refunded'],
      default: 'pending',
      index: true,
    },
    deliveredAt: { type: Date },
    deliveryDate: { type: Date },
    deliveredWork: { type: String },
    revisionNotes: { type: String },
    totalAmount: { type: Number, required: true, min: 0 },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Order', orderSchema);
