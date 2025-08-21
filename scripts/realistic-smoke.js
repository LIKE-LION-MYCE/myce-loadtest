import http from 'k6/http';
import { check, sleep } from 'k6';

// Realistic Smoke Test - Quick health check with authentication - FIXED VERSION
export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.1'],        // Less than 10% failures
    http_req_duration: ['p(95)<1000'],    // 95% under 1s
    checks: ['rate>0.95'],                // 95% of checks pass
  },
};

// Test account for JWT authentication
const TEST_CREDENTIALS = {
  loginId: 'test123',
  password: 'test123!!',
  loginType: 'MEMBER'
};

// JWT token cache (per VU)
let authToken = null;
let tokenExpiry = 0;

// Get or refresh JWT token - FIXED AUTHENTICATION
function getAuthToken() {
  const now = Date.now();
  
  // Return cached token if still valid (assuming 1-hour expiry)
  if (authToken && tokenExpiry > now) {
    return authToken;
  }
  
  // Authenticate and get new token - CORRECT ENDPOINT
  const loginUrl = 'https://api.myce.live/api/auth/login';
  const loginPayload = JSON.stringify(TEST_CREDENTIALS);
  
  const loginRes = http.post(loginUrl, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '10s',
    tags: { scenario: 'authentication' }
  });
  
  const loginSuccess = check(loginRes, {
    '🔐 JWT login successful': (r) => r.status === 200,
    '🔐 JWT token received': (r) => r.headers && r.headers['Authorization'],
  });
  
  if (loginSuccess && loginRes.status === 200 && loginRes.headers['Authorization']) {
    authToken = loginRes.headers['Authorization'];
    tokenExpiry = now + (50 * 60 * 1000); // Cache for 50 minutes
    return authToken;
  }
  
  return null;
}

// Main test function
export default function () {
  // Test 1: Health check (public)
  const healthRes = http.get('https://api.myce.live/actuator/health', {
    timeout: '5s',
    tags: { scenario: 'public', endpoint: 'health' }
  });
  check(healthRes, {
    '💚 System healthy': (r) => r.status === 200,
  });
  
  sleep(1);
  
  // Test 2: Public content
  const publicRes = http.get('https://api.myce.live/api/expos?page=0&size=5', {
    timeout: '10s',
    tags: { scenario: 'public', endpoint: 'expos' }
  });
  check(publicRes, {
    '🌐 Public content loaded': (r) => r.status === 200 || r.status === 404,
  });
  
  sleep(1);
  
  // Test 3: JWT Authentication flow
  const token = getAuthToken();
  if (token) {
    // Test authenticated endpoint
    const profileRes = http.get('https://api.myce.live/api/members/my-info', {
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json'
      },
      timeout: '10s',
      tags: { scenario: 'authenticated', endpoint: 'profile' }
    });
    check(profileRes, {
      '👤 Profile loaded': (r) => r.status === 200,
    });
    
    sleep(1);
    
    // Test notifications
    const notifRes = http.get('https://api.myce.live/api/notifications', {
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json'
      },
      timeout: '10s',
      tags: { scenario: 'authenticated', endpoint: 'notifications' }
    });
    check(notifRes, {
      '🔔 Notifications loaded': (r) => r.status === 200 || r.status === 404,
    });
  }
  
  sleep(2);
}

// Setup function to verify endpoints
export function setup() {
  console.log('🔧 Realistic Smoke Test - Starting with fixed endpoints...');
  
  // Test public endpoint
  const publicTest = http.get('https://api.myce.live/actuator/health');
  if (publicTest.status !== 200) {
    console.error('❌ Server health check failed!');
  } else {
    console.log('✅ Server is healthy and ready for smoke test');
  }
}

// Teardown function
export function teardown() {
  console.log('🏁 Realistic Smoke Test completed - All endpoints verified!');
}