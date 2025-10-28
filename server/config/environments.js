const { v4: uuidv4 } = require('uuid');

function parseNumber(value, fallback) {
  if (!value) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function buildRegex(pattern) {
  if (!pattern) {
    return null;
  }
  try {
    return new RegExp(pattern);
  } catch (error) {
    return null;
  }
}

function loadEnvironmentConfig(env) {
  const normalized = (env || 'development').toLowerCase();
  const defaultCorsOrigins = [
    process.env.CLIENT_ORIGIN || 'https://localhost:5173',
    process.env.API_ORIGIN || 'https://localhost:4000',
  ].filter(Boolean);

  const baseConfig = {
    cookies: { secure: normalized === 'production' },
    cors: {
      allowedOrigins: Array.from(new Set(defaultCorsOrigins)),
      allowPattern: buildRegex(process.env.CLIENT_ORIGIN_PATTERN || ''),
    },
    services: {
      database: process.env.DATABASE_URL || 'postgresql://localhost:5432/freetask_dev',
      queue: process.env.QUEUE_URL || 'redis://localhost:6379/0',
      storage: process.env.STORAGE_BUCKET || 'file://./.storage',
    },
    rateLimiting: {
      refresh: {
        windowMs: parseNumber(process.env.REFRESH_WINDOW_MS, 60 * 1000),
        max: parseNumber(process.env.REFRESH_MAX_REQUESTS, 20),
        useUserAgentKey: false,
      },
    },
  };

  if (normalized === 'beta') {
    return {
      ...baseConfig,
      cookies: { secure: true },
      cors: {
        allowedOrigins: [
          process.env.BETA_CLIENT_ORIGIN || 'https://beta.freetask.app',
        ],
        allowPattern: buildRegex(process.env.BETA_CLIENT_ORIGIN_PATTERN || ''),
      },
      services: {
        database:
          process.env.BETA_DATABASE_URL || 'postgresql://beta-db.internal:5432/freetask_beta',
        queue:
          process.env.BETA_QUEUE_URL || 'redis://beta-queue.internal:6379/0',
        storage:
          process.env.BETA_STORAGE_BUCKET || 's3://freetask-beta-uploads',
      },
      rateLimiting: {
        refresh: {
          windowMs: parseNumber(process.env.BETA_REFRESH_WINDOW_MS, 60 * 1000),
          max: parseNumber(process.env.BETA_REFRESH_MAX_REQUESTS, 10),
          useUserAgentKey: true,
        },
      },
    };
  }

  if (normalized === 'production') {
    return {
      ...baseConfig,
      cookies: { secure: true },
      cors: {
        allowedOrigins: [
          process.env.CLIENT_ORIGIN || 'https://app.freetask.com',
          process.env.ADMIN_CLIENT_ORIGIN || 'https://admin.freetask.com',
        ].filter(Boolean),
        allowPattern: buildRegex(process.env.CLIENT_ORIGIN_PATTERN || ''),
      },
      services: {
        database:
          process.env.DATABASE_URL || 'postgresql://prod-db.internal:5432/freetask',
        queue: process.env.QUEUE_URL || 'redis://prod-queue.internal:6379/0',
        storage: process.env.STORAGE_BUCKET || 's3://freetask-production-uploads',
      },
      rateLimiting: {
        refresh: {
          windowMs: parseNumber(process.env.REFRESH_WINDOW_MS, 60 * 1000),
          max: parseNumber(process.env.REFRESH_MAX_REQUESTS, 15),
          useUserAgentKey: true,
        },
      },
    };
  }

  return baseConfig;
}

async function seedBetaEnvironment({ db, findUserByEmail, audit, hashPassword, UserModel }) {
  const requestId = `seed-beta-${Date.now()}`;

  const ensureUser = async ({ email, name, role }) => {
    if (UserModel) {
      const existingDoc = await UserModel.findOne({ email });
      if (existingDoc) {
        return existingDoc;
      }
      const user = new UserModel({ name, email, role, verified: true });
      const password = process.env.BETA_DEFAULT_PASSWORD || 'Password123!';
      if (typeof user.setPassword === 'function') {
        await user.setPassword(password);
      } else if (hashPassword) {
        user.passwordHash = await hashPassword(password);
      }
      await user.save();
      audit({
        userId: user._id.toString(),
        action: 'SEED_USER',
        metadata: { env: 'beta', role },
        requestId,
      });
      return user;
    }

    const existing = await findUserByEmail(email);
    if (existing) {
      return existing;
    }

    const id = uuidv4();
    const now = new Date().toISOString();
    const passwordHash = await hashPassword(process.env.BETA_DEFAULT_PASSWORD || 'Password123!');
    const user = {
      id,
      name,
      email,
      role,
      verified: true,
      passwordHash,
      createdAt: now,
      updatedAt: now,
    };
    db.users.set(id, user);
    audit({
      userId: id,
      action: 'SEED_USER',
      metadata: { env: 'beta', role },
      requestId,
    });
    return user;
  };

  const client = await ensureUser({
    email: process.env.BETA_CLIENT_EMAIL || 'beta-client@example.com',
    name: 'Beta Client',
    role: 'client',
  });

  const freelancer = await ensureUser({
    email: process.env.BETA_FREELANCER_EMAIL || 'beta-freelancer@example.com',
    name: 'Beta Freelancer',
    role: 'freelancer',
  });

  const jobSeedKey = 'beta-default-job';
  let job = null;
  for (const record of db.jobs.values()) {
    if (record.metadata?.seed === jobSeedKey) {
      job = record;
      break;
    }
  }

  if (!job) {
    const jobId = uuidv4();
    const now = new Date().toISOString();
    job = {
      id: jobId,
      title: 'Beta Onboarding Project',
      description:
        'Sample project seeded for beta testers to explore the marketplace experience.',
      budget: 750,
      status: 'open',
      clientId: client.id,
      assignedFreelancerId: freelancer.id,
      createdAt: now,
      updatedAt: now,
      metadata: { seed: jobSeedKey },
    };
    db.jobs.set(jobId, job);
    audit({
      userId: client.id,
      action: 'SEED_JOB',
      metadata: { env: 'beta', jobId },
      requestId,
    });
  }

  return { client, freelancer, job };
}

async function seedEnvironmentData(env, helpers) {
  if (!env) {
    return null;
  }
  const normalized = env.toLowerCase();
  if (normalized === 'beta') {
    return seedBetaEnvironment(helpers);
  }
  return null;
}

module.exports = {
  loadEnvironmentConfig,
  seedEnvironmentData,
};

