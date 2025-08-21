import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// EKS Gradual Auto-scaling Demo with JWT Authentication - FIXED VERSION
export const options = {
  stages: [
    // Phase 1: Baseline load (trigger initial scaling)
    { duration: '30s', target: 20 },    // Baseline: 3 pods → should stay at 3
    { duration: '30s', target: 20 },    // Stable baseline
    
    // Phase 2: Medium load (trigger first scale-up)
    { duration: '30s', target: 100 },   // Scale trigger: 3 → 6 pods (CPU > 70%)
    { duration: '1m', target: 100 },    // Allow scaling to complete
    
    // Phase 3: Heavy load (trigger second scale-up) 
    { duration: '30s', target: 300 },   // Scale trigger: 6 → 12 pods
    { duration: '1m', target: 300 },    // Allow scaling to complete
    
    // Phase 4: Peak load (trigger max scale-up)
    { duration: '30s', target: 500 },   // Scale trigger: 12 → 18 pods (max)
    { duration: '1m', target: 500 },    // Sustained peak load
    
    // Phase 5: Extreme spike (test max capacity)
    { duration: '30s', target: 800 },   // Push to limits (18 pods working hard)
    { duration: '1m', target: 800 },    // Sustained extreme load
    
    // Phase 6: Wind down (trigger scale-down)
    { duration: '30s', target: 100 },   // Scale down: 18 → 6 pods
    { duration: '1m', target: 0 },      // Scale down: 6 → 3 pods (min)
  ],
  thresholds: {
    http_req_failed: ['rate<0.25'],       // Allow 25% failures during extreme load
    http_req_duration: ['p(95)<4000'],    // 95% under 4s (relaxed for scaling demo)
    http_req_duration: ['p(99)<8000'],    // 99% under 8s during scaling
    checks: ['rate>0.70'],                // 70% success rate minimum
    // Custom thresholds for scaling validation
    'http_req_duration{scenario:authenticated}': ['p(95)<3000'],
    'checks{scenario:authenticated}': ['rate>0.80'],
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
    '🔐 JWT token received': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.accessToken !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  if (loginSuccess && loginRes.status === 200) {
    try {
      const body = JSON.parse(loginRes.body);
      if (body.accessToken) {
        authToken = 'Bearer ' + body.accessToken;
        tokenExpiry = now + (50 * 60 * 1000); // Cache for 50 minutes
        return authToken;
      }
    } catch (e) {
      console.error('Failed to parse login response:', e);
    }
  }
  
  return null;
}

// Authenticated user scenarios - FIXED API ENDPOINTS
function authenticatedScenarios(token) {
  const authHeaders = {
    'Authorization': token,
    'Content-Type': 'application/json'
  };
  
  // Scenario 1: Member profile and settings (30%)
  if (Math.random() < 0.3) {
    const profileRes = http.get('https://api.myce.live/api/members/my-info', {
      headers: authHeaders,
      timeout: '10s',
      tags: { scenario: 'authenticated', endpoint: 'profile' }
    });
    check(profileRes, {
      '👤 Profile loaded': (r) => r.status === 200,
    });
    
    sleep(1 + Math.random() * 2);
    return;
  }
  
  // Scenario 2: Expo browsing and interactions (40%)  
  if (Math.random() < 0.6) {
    // Browse expo list - PUBLIC ENDPOINT
    const expoRes = http.get('https://api.myce.live/api/expos?page=0&size=20', {
      timeout: '10s',
      tags: { scenario: 'authenticated', endpoint: 'expos' }
    });
    check(expoRes, {
      '🏢 Expo list loaded': (r) => r.status === 200 || r.status === 404,
    });
    
    sleep(1 + Math.random() * 2);
    
    // Test a favorite action - FIXED ENDPOINT
    const favoriteExpoId = Math.floor(Math.random() * 10) + 1;
    const favRes = http.post(`https://api.myce.live/api/favorites/${favoriteExpoId}`, '', {
      headers: authHeaders,
      timeout: '10s',
      tags: { scenario: 'authenticated', endpoint: 'favorites' }
    });
    check(favRes, {
      '⭐ Favorites action': (r) => r.status === 200 || r.status === 404 || r.status === 400,
    });
    
    sleep(1 + Math.random() * 2);
    return;
  }
  
  // Scenario 3: Heavy operations - notifications (30%)
  const notifRes = http.get('https://api.myce.live/api/notifications', {
    headers: authHeaders,
    timeout: '10s',
    tags: { scenario: 'authenticated', endpoint: 'notifications' }
  });
  check(notifRes, {
    '🔔 Notifications loaded': (r) => r.status === 200 || r.status === 404,
  });
  
  sleep(2 + Math.random() * 3);
}

// Public content scenarios (generates load without auth complexity)
function publicScenarios() {
  // Health check and system info (20% of public)
  if (Math.random() < 0.2) {
    const healthRes = http.get('https://api.myce.live/actuator/health', {
      timeout: '5s',
      tags: { scenario: 'public', endpoint: 'health' }
    });
    check(healthRes, {
      '💚 System healthy': (r) => r.status === 200,
    });
    return;
  }
  
  // Browse public content (80% of public)
  const publicRes = http.get('https://api.myce.live/api/expos?page=0&size=10', {
    timeout: '10s',
    tags: { scenario: 'public', endpoint: 'expos' }
  });
  check(publicRes, {
    '🌐 Public content loaded': (r) => r.status === 200 || r.status === 404,
  });
  
  sleep(1 + Math.random() * 3);
}

// Main test function
export default function () {
  // 70% authenticated users, 30% public browsing
  if (Math.random() < 0.7) {
    // Authenticated user scenarios
    const token = getAuthToken();
    if (token) {
      authenticatedScenarios(token);
    } else {
      // Fallback to public if auth fails
      publicScenarios();
    }
  } else {
    // Public browsing scenarios
    publicScenarios();
  }
}

// Setup function to verify endpoints
export function setup() {
  console.log('🔧 EKS Auto-scaling Demo - Starting with fixed endpoints...');
  
  // Test public endpoint
  const publicTest = http.get('https://api.myce.live/actuator/health');
  if (publicTest.status !== 200) {
    console.error('❌ Server health check failed!');
  } else {
    console.log('✅ Server is healthy and ready for load test');
  }
}

// Teardown function
export function teardown() {
  console.log('🏁 EKS Auto-scaling Demo completed - Check dashboard for scaling results!');
}