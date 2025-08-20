import http from 'k6/http';
import { check, sleep } from 'k6';

// Realistic Load Test - Sustained heavy concurrent authenticated users
export const options = {
  stages: [
    // Phase 1: Gradual ramp-up
    { duration: '2m', target: 20 },    // Initial authenticated users
    { duration: '2m', target: 50 },    // Building load
    
    // Phase 2: Heavy sustained load
    { duration: '3m', target: 100 },   // Heavy concurrent users
    { duration: '5m', target: 100 },   // Sustained load test
    
    // Phase 3: Peak load
    { duration: '2m', target: 150 },   // Peak concurrent authenticated users
    { duration: '3m', target: 150 },   // Sustained peak
    
    // Phase 4: Gradual wind down
    { duration: '2m', target: 50 },    // Reducing load
    { duration: '1m', target: 0 },     // Shutdown
  ],
  thresholds: {
    http_req_failed: ['rate<0.2'],       // Less than 20% failures
    http_req_duration: ['p(95)<4000'],   // 95% under 4s
    http_req_duration: ['p(99)<8000'],   // 99% under 8s
    checks: ['rate>0.8'],                // 80% of checks pass
  },
};

// Shared test account
const TEST_CREDENTIALS = {
  loginId: 'test123',
  password: 'test123!!',
  loginType: 'MEMBER'
};

// Cache token to reduce auth load (realistic user behavior)
let cachedToken = null;
let tokenExpiry = 0;

function getAuthToken() {
  const now = Date.now();
  
  // Use cached token if still valid (simulate real user sessions)
  if (cachedToken && now < tokenExpiry) {
    return cachedToken;
  }
  
  // Get new token
  const loginUrl = 'https://api.myce.live/api/auth/login';
  const loginPayload = JSON.stringify(TEST_CREDENTIALS);
  
  const loginRes = http.post(loginUrl, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '12s'
  });
  
  const loginSuccess = check(loginRes, {
    'load test login': (r) => r.status === 200,
    'login response time reasonable': (r) => r.timings.duration < 3000,
  });
  
  if (loginSuccess) {
    cachedToken = loginRes.headers['Authorization'];
    tokenExpiry = now + (15 * 60 * 1000); // Cache for 15 minutes
    return cachedToken;
  }
  
  return null;
}

// Simulate realistic user session with multiple operations
function userSession(token) {
  const authHeaders = {
    'Authorization': token,
    'Content-Type': 'application/json'
  };
  
  // 1. User profile check (common operation)
  const profileRes = http.get('https://api.myce.live/api/members/my-info', {
    headers: authHeaders,
    timeout: '10s'
  });
  check(profileRes, {
    'profile access during load': (r) => r.status === 200,
  });
  
  sleep(1 + Math.random() * 2); // Think time
  
  // 2. Browse content (multiple pages)
  const pages = Math.floor(Math.random() * 3); // 0-2 additional pages
  for (let i = 0; i <= pages; i++) {
    const expoRes = http.get(`https://api.myce.live/api/expos?page=${i}&size=10`, {
      headers: authHeaders,
      timeout: '8s'
    });
    check(expoRes, {
      [`expo page ${i} load`]: (r) => r.status === 200 || r.status === 404,
    });
    
    sleep(0.5 + Math.random()); // Quick page browsing
  }
  
  sleep(1 + Math.random() * 2); // Think time
  
  // 3. Check system status (users monitoring their experience)
  const healthRes = http.get('https://api.myce.live/actuator/health');
  check(healthRes, {
    'system status check': (r) => r.status === 200,
    'health check fast during load': (r) => r.timings.duration < 2000,
  });
  
  // 4. Occasionally check detailed metrics (power users)
  if (Math.random() < 0.3) { // 30% chance
    const metricsRes = http.get('https://api.myce.live/actuator/metrics', {
      timeout: '5s'
    });
    check(metricsRes, {
      'metrics accessible under load': (r) => r.status === 200,
    });
  }
}

export default function () {
  // Get authentication token
  const token = getAuthToken();
  
  if (token) {
    // Execute realistic user session
    userSession(token);
  } else {
    // Fallback to public browsing if auth fails
    const healthRes = http.get('https://api.myce.live/actuator/health');
    check(healthRes, {
      'fallback health check': (r) => r.status === 200,
    });
    
    const publicExpoRes = http.get('https://api.myce.live/api/expos?page=0&size=10');
    check(publicExpoRes, {
      'fallback public access': (r) => r.status === 200 || r.status === 404,
    });
  }
  
  // Realistic user think time
  sleep(2 + Math.random() * 3); // 2-5 seconds between major actions
}