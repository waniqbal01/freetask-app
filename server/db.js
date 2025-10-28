const mongoose = require('mongoose');
async function connectDB(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  console.log('[DB] Connected to MongoDB');
}
module.exports = { connectDB };
