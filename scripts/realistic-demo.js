import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Realistic Demo Test - Mixed user journeys for presentations
export const options = {
  stages: [
    // Phase 1: Users arriving and browsing
    { duration: '1m', target: 5 },    // Light browsing traffic
    { duration: '2m', target: 5 },    // Steady browsing
    
    // Phase 2: Peak engagement (users logging in)
    { duration: '1m', target: 15 },   // Authentication load
    { duration: '3m', target: 15 },   // Active authenticated users
    
    // Phase 3: Heavy activity (reservations, interactions)
    { duration: '1m', target: 25 },   // Business operations peak
    { duration: '4m', target: 25 },   // Sustained heavy load
    
    // Phase 4: Mixed load (some users leaving, new ones joining)
    { duration: '1m', target: 35 },   // Mixed scenarios
    { duration: '2m', target: 35 },   // Peak concurrent users
    
    // Phase 5: Wind down
    { duration: '1m', target: 10 },   // Users leaving
    { duration: '30s', target: 0 },   // Clean shutdown
  ],
  thresholds: {
    http_req_failed: ['rate<0.15'],       // Allow 15% failures during peak
    http_req_duration: ['p(95)<3000'],    // 95% under 3s
    http_req_duration: ['p(99)<5000'],    // 99% under 5s (relaxed for demo)
    checks: ['rate>0.85'],                // 85% of checks pass
  },
};

// Shared test account
const TEST_CREDENTIALS = {
  loginId: 'test123',
  password: 'test123!!',
  loginType: 'MEMBER'
};

// Different user behavior patterns
const USER_SCENARIOS = [
  'browser',      // Just browsing public content (40%)
  'member',       // Authenticated member activities (35%)
  'heavy_user',   // Power user with multiple operations (20%)
  'admin_check'   // Quick admin-like checks (5%)
];

// Get JWT token
function authenticate() {
  const loginUrl = 'https://api.myce.live/api/auth/login';
  const loginPayload = JSON.stringify(TEST_CREDENTIALS);
  
  const loginRes = http.post(loginUrl, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '15s'
  });
  
  const loginSuccess = check(loginRes, {
    'login successful': (r) => r.status === 200,
  });
  
  return loginSuccess ? loginRes.headers['Authorization'] : null;
}

// Public browsing scenario (no auth required)
function browserScenario() {
  // Browse expo list
  const expoListRes = http.get('https://api.myce.live/api/expos?page=0&size=20');
  check(expoListRes, {
    'expo list accessible': (r) => r.status === 200 || r.status === 404,
  });
  
  sleep(2 + Math.random() * 3); // 2-5 second think time
  
  // Check health/system status
  const healthRes = http.get('https://api.myce.live/actuator/health');
  check(healthRes, {
    'system healthy': (r) => r.status === 200,
  });
  
  sleep(1 + Math.random() * 2); // 1-3 second think time
}

// Authenticated member scenario
function memberScenario(token) {
  const authHeaders = {
    'Authorization': token,
    'Content-Type': 'application/json'
  };
  
  // Get member profile
  const profileRes = http.get('https://api.myce.live/api/members/my-info', {
    headers: authHeaders,
    timeout: '10s'
  });
  check(profileRes, {
    'profile loaded': (r) => r.status === 200,
  });
  
  sleep(1 + Math.random() * 2);
  
  // Browse expos (authenticated user gets more data)
  const expoRes = http.get('https://api.myce.live/api/expos?page=0&size=10', {
    headers: authHeaders,
  });
  check(expoRes, {
    'authenticated expo access': (r) => r.status === 200 || r.status === 404,
  });
  
  sleep(2 + Math.random() * 3);
  
  // Check for notifications/updates
  const activityRes = http.get('https://api.myce.live/actuator/info');
  check(activityRes, {
    'system info accessible': (r) => r.status === 200,
  });
  
  sleep(1 + Math.random() * 2);
}

// Heavy user scenario (multiple operations)
function heavyUserScenario(token) {
  const authHeaders = {
    'Authorization': token,
    'Content-Type': 'application/json'
  };
  
  // Multiple rapid requests simulating active usage
  const requests = [
    { method: 'GET', url: 'https://api.myce.live/api/members/my-info' },
    { method: 'GET', url: 'https://api.myce.live/api/expos?page=0&size=5' },
    { method: 'GET', url: 'https://api.myce.live/actuator/health' },
    { method: 'GET', url: 'https://api.myce.live/actuator/metrics' },
  ];
  
  // Batch requests to simulate heavy user activity
  const responses = http.batch(requests.map(req => ({
    method: req.method,
    url: req.url,
    params: { headers: authHeaders, timeout: '10s' }
  })));
  
  responses.forEach((res, index) => {
    check(res, {
      [`batch request ${index + 1} successful`]: (r) => r.status >= 200 && r.status < 400,
    });
  });
  
  sleep(0.5 + Math.random()); // Short think time for power users
}

// Admin check scenario
function adminCheckScenario() {
  // Quick system monitoring checks
  const monitoringEndpoints = [
    'https://api.myce.live/actuator/health',
    'https://api.myce.live/actuator/info',
    'https://api.myce.live/actuator/metrics',
  ];
  
  const endpoint = randomItem(monitoringEndpoints);
  const res = http.get(endpoint, { timeout: '5s' });
  
  check(res, {
    'admin monitoring check': (r) => r.status === 200,
    'monitoring response time < 1s': (r) => r.timings.duration < 1000,
  });
  
  sleep(0.5 + Math.random() * 0.5); // Quick admin checks
}

export default function () {
  // Randomly select user behavior (weighted distribution)
  const rand = Math.random();
  let scenario;
  
  if (rand < 0.40) {
    scenario = 'browser';
  } else if (rand < 0.75) {
    scenario = 'member';
  } else if (rand < 0.95) {
    scenario = 'heavy_user';
  } else {
    scenario = 'admin_check';
  }
  
  // Execute scenario
  switch (scenario) {
    case 'browser':
      browserScenario();
      break;
      
    case 'member':
    case 'heavy_user':
      const token = authenticate();
      if (token) {
        if (scenario === 'member') {
          memberScenario(token);
        } else {
          heavyUserScenario(token);
        }
      } else {
        // Fallback to browsing if auth fails
        browserScenario();
      }
      break;
      
    case 'admin_check':
      adminCheckScenario();
      break;
  }
}