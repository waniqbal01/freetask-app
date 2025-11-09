const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const userSchema = new mongoose.Schema(
  {
    name: { type: String, trim: true },
    email: {
      type: String,
      unique: true,
      lowercase: true,
      index: true,
      required: true,
    },
    passwordHash: { type: String, required: true },
    role: {
      type: String,
      enum: ['client', 'freelancer', 'admin', 'seller', 'support', 'manager'],
      default: 'client',
    },
    verified: { type: Boolean, default: false },
    refreshTokenHash: { type: String },
    refreshTokenExpiresAt: { type: Date },
  },
  { timestamps: true }
);

userSchema.methods.setPassword = async function setPassword(plain) {
  this.passwordHash = await bcrypt.hash(plain, 10);
};

userSchema.methods.verifyPassword = function verifyPassword(plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

userSchema.methods.clearRefreshToken = function clearRefreshToken() {
  this.refreshTokenHash = undefined;
  this.refreshTokenExpiresAt = undefined;
};

module.exports = mongoose.model('User', userSchema);
