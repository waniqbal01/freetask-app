const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const userSchema = new mongoose.Schema({
  name: { type: String, trim: true },
  email: { type: String, unique: true, lowercase: true, index: true, required: true },
  passwordHash: { type: String, required: true },
  role: { type: String, enum: ['client','freelancer','admin'], default: 'client' },
  verified: { type: Boolean, default: false },
}, { timestamps: true });
userSchema.methods.setPassword = async function (plain) { this.passwordHash = await bcrypt.hash(plain, 10); };
userSchema.methods.verifyPassword = function (plain) { return bcrypt.compare(plain, this.passwordHash); };
module.exports = mongoose.model('User', userSchema);
