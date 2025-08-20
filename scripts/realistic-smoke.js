import http from 'k6/http';
import { check, sleep } from 'k6';

// Realistic Smoke Test - Quick health check with authentication
export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.1'],        // Less than 10% failures
    http_req_duration: ['p(95)<1000'],    // 95% under 1s
    checks: ['rate>0.95'],                // 95% of checks pass
  },
};

// Shared test account
const TEST_CREDENTIALS = {
  loginId: 'test123',
  password: 'test123!!',
  loginType: 'MEMBER'
};

// Get JWT token
function authenticate() {
  const loginUrl = 'https://api.myce.live/api/auth/login';
  const loginPayload = JSON.stringify(TEST_CREDENTIALS);
  
  const loginRes = http.post(loginUrl, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '10s'
  });
  
  const loginSuccess = check(loginRes, {
    'login status is 200': (r) => r.status === 200,
    'login response time < 2s': (r) => r.timings.duration < 2000,
  });
  
  if (!loginSuccess) {
    console.error('Login failed:', loginRes.status, loginRes.body);
    return null;
  }
  
  // Extract JWT token from Authorization header
  const authHeader = loginRes.headers['Authorization'];
  return authHeader || null;
}

export default function () {
  // Step 1: Authenticate and get JWT token
  const token = authenticate();
  
  if (!token) {
    console.error('Authentication failed, skipping authenticated tests');
    return;
  }
  
  const authHeaders = {
    'Authorization': token,
    'Content-Type': 'application/json'
  };
  
  // Step 2: Test public endpoints
  const healthRes = http.get('https://api.myce.live/actuator/health');
  check(healthRes, {
    'health check is 200': (r) => r.status === 200,
    'health response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(0.5);
  
  // Step 3: Test authenticated endpoint
  const memberInfoRes = http.get('https://api.myce.live/api/members/my-info', {
    headers: authHeaders,
    timeout: '5s'
  });
  
  check(memberInfoRes, {
    'member info is 200': (r) => r.status === 200,
    'member info response time < 1s': (r) => r.timings.duration < 1000,
    'member info has content': (r) => r.body && r.body.length > 0,
  });
  
  sleep(1);
  
  // Step 4: Test public API endpoints
  const expoListRes = http.get('https://api.myce.live/api/expos?page=0&size=10');
  check(expoListRes, {
    'expo list is accessible': (r) => r.status === 200 || r.status === 404,
    'expo list response time < 1s': (r) => r.timings.duration < 1000,
  });
  
  sleep(1);
}