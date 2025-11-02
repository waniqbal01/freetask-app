const mongoose = require('mongoose');

let cachedConnection = null;
let pendingConnection = null;

function resolveConnectionString(uri) {
  const connectionString = uri || process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/freetask';
  if (!connectionString) {
    throw new Error('MongoDB connection string is required');
  }
  return connectionString;
}

function attachConnectionHandlers(connection) {
  if (connection._hasFreetaskListeners) {
    return;
  }

  connection._hasFreetaskListeners = true;

  connection.on('disconnected', () => {
    cachedConnection = null;
    console.warn('[DB] MongoDB connection lost. Attempting to reconnect on next request.');
  });

  connection.on('error', (error) => {
    console.error('[DB] MongoDB connection error:', error);
  });
}

async function connectDB(uri) {
  const connectionString = resolveConnectionString(uri);

  if (cachedConnection?.readyState === 1) {
    return cachedConnection;
  }

  if (pendingConnection) {
    return pendingConnection;
  }

  mongoose.set('strictQuery', true);

  const maxPoolSize = Number.parseInt(process.env.MONGODB_MAX_POOL_SIZE || '10', 10);
  const serverSelectionTimeoutMS = Number.parseInt(
    process.env.MONGODB_SERVER_SELECTION_TIMEOUT || '5000',
    10,
  );

  pendingConnection = mongoose
    .connect(connectionString, {
      maxPoolSize,
      serverSelectionTimeoutMS,
    })
    .then((mongooseInstance) => {
      cachedConnection = mongooseInstance.connection;
      attachConnectionHandlers(cachedConnection);
      console.log(
        `[DB] Connected to MongoDB at ${cachedConnection.host}:${cachedConnection.port}/${cachedConnection.name}`,
      );
      return cachedConnection;
    })
    .catch((error) => {
      pendingConnection = null;
      console.error('[DB] Failed to connect to MongoDB:', error.message);
      throw error;
    });

  try {
    return await pendingConnection;
  } finally {
    pendingConnection = null;
  }
}

module.exports = { connectDB };
