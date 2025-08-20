import http from 'k6/http';
import { check, sleep } from 'k6';

// Realistic Spike Test - Authentication stress + sudden traffic surge
export const options = {
  stages: [
    { duration: '1m', target: 20 },     // Normal authenticated load
    { duration: '10s', target: 200 },   // SUDDEN SPIKE! (10x increase)
    { duration: '2m', target: 200 },    // Maintain spike - test auth under pressure
    { duration: '10s', target: 20 },    // Back to normal
    { duration: '1m', target: 20 },     // Recovery observation
    { duration: '10s', target: 0 },     // Shutdown
  ],
  thresholds: {
    http_req_failed: ['rate<0.4'],       // Allow 40% failure during spike
    http_req_duration: ['p(90)<5000'],   // 90% under 5s during spike
    checks: ['rate>0.6'],                // 60% of checks pass (relaxed for spike)
  },
};

// Shared test account - will be hammered during spike
const TEST_CREDENTIALS = {
  loginId: 'test123',
  password: 'test123!!',
  loginType: 'MEMBER'
};

// Simplified auth with aggressive timeouts
function quickAuth() {
  const loginUrl = 'https://api.myce.live/api/auth/login';
  const loginPayload = JSON.stringify(TEST_CREDENTIALS);
  
  const loginRes = http.post(loginUrl, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '8s' // Shorter timeout for spike conditions
  });
  
  const authSuccess = check(loginRes, {
    'spike auth attempt': (r) => r.status === 200 || r.status === 429 || r.status === 503, // Accept rate limiting
  });
  
  return loginRes.status === 200 ? loginRes.headers['Authorization'] : null;
}

export default function () {
  // During spike, focus on core functionality
  
  // 1. Authentication stress test
  const token = quickAuth();
  
  // 2. High-frequency endpoint hits (simulate viral content)
  const coreEndpoints = [
    'https://api.myce.live/actuator/health',
    'https://api.myce.live/api/expos?page=0&size=5',
    'https://api.myce.live/actuator/info'
  ];
  
  // Random endpoint selection to spread load
  const endpoint = coreEndpoints[Math.floor(Math.random() * coreEndpoints.length)];
  
  const headers = token ? {
    'Authorization': token,
    'Content-Type': 'application/json'
  } : {};
  
  const res = http.get(endpoint, {
    headers: headers,
    timeout: '10s'
  });
  
  check(res, {
    'spike endpoint response': (r) => r.status !== 0, // Not timeout
    'acceptable spike status': (r) => [200, 429, 503, 504].includes(r.status), // Accept overload responses
  });
  
  // 3. If authenticated, try one protected operation
  if (token) {
    const memberRes = http.get('https://api.myce.live/api/members/my-info', {
      headers: { 'Authorization': token },
      timeout: '8s'
    });
    
    check(memberRes, {
      'authenticated spike access': (r) => r.status === 200 || r.status >= 500, // Success or server overload
    });
  }
  
  // Minimal sleep to create maximum spike pressure
  sleep(0.1 + Math.random() * 0.2); // 0.1-0.3 seconds
}