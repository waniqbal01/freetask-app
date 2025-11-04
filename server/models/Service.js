const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema(
  {
    freelancer: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true, index: true },
    price: { type: Number, required: true, min: 0 },
    deliveryTime: { type: Number, required: true, min: 1 }, // days
    media: { type: [String], default: [] },
    status: {
      type: String,
      enum: ['draft', 'published', 'suspended'],
      default: 'published',
      index: true,
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Service', serviceSchema);
