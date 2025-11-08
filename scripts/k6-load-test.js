import http from 'k6/http';
import { check, group } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

export const options = {
  vus: Number(__ENV.VUS) || 5,
  duration: __ENV.DURATION || '1m',
  thresholds: {
    http_req_duration: ['p(50)<400', 'p(95)<1000'],
    http_req_failed: ['rate<0.01']
  }
};

function authenticate(baseUrl, email) {
  const loginRes = http.post(
    `${baseUrl}/api/auth/login`,
    JSON.stringify({ email }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  check(loginRes, {
    'login status 200': (r) => r.status === 200,
    'login has otp': (r) => !!r.json()?.data?.otp,
  });
  const otp = loginRes.json().data.otp;
  const verifyRes = http.post(
    `${baseUrl}/api/auth/verify-otp`,
    JSON.stringify({ email, otp }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  check(verifyRes, {
    'verify status 200': (r) => r.status === 200,
    'token received': (r) => !!r.json()?.data?.accessToken,
  });
  return {
    accessToken: verifyRes.json().data.accessToken,
    refreshToken: verifyRes.json().data.refreshToken,
  };
}

export function setup() {
  const baseUrl = __ENV.BASE_URL || 'https://localhost:4000';
  const clientEmail = __ENV.CLIENT_EMAIL || 'client@example.com';
  const freelancerEmail = __ENV.FREELANCER_EMAIL || 'freelancer@example.com';

  const client = authenticate(baseUrl, clientEmail);
  const freelancer = authenticate(baseUrl, freelancerEmail);

  return { baseUrl, client, freelancer };
}

export default function ({ baseUrl, client, freelancer }) {
  group('auth heartbeat', () => {
    const loginRes = http.post(
      `${baseUrl}/api/auth/login`,
      JSON.stringify({ email: __ENV.CLIENT_EMAIL || 'client@example.com' }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    check(loginRes, {
      'heartbeat login 200': (r) => r.status === 200,
    });
  });

  group('jobs lifecycle', () => {
    const jobPayload = {
      title: `Automation job ${Date.now()}`,
      description: 'API created via k6',
      category: 'Automation',
      budget: 900,
    };
    const createRes = http.post(
      `${baseUrl}/jobs`,
      JSON.stringify(jobPayload),
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${client.accessToken}`,
        },
      }
    );
    check(createRes, {
      'job created': (r) => r.status === 201,
    });
    const jobId = createRes.json()?.data?.id;

    const listRes = http.get(`${baseUrl}/jobs`, {
      headers: { Authorization: `Bearer ${freelancer.accessToken}` },
    });
    check(listRes, {
      'jobs listed': (r) => r.status === 200,
    });

    group('payments lifecycle', () => {
      const escrowRes = http.post(
        `${baseUrl}/payments/escrow`,
        JSON.stringify({ jobId, amount: jobPayload.budget }),
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${client.accessToken}`,
          },
        }
      );
      check(escrowRes, {
        'escrow created': (r) => r.status === 201,
      });

      const releaseRes = http.post(
        `${baseUrl}/payments/release`,
        JSON.stringify({ jobId }),
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${client.accessToken}`,
            'Idempotency-Key': uuidv4(),
          },
        }
      );
      check(releaseRes, {
        'payment released': (r) => r.status === 200,
      });
    });
  });
}
