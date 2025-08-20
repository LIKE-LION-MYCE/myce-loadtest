import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 100 },   // Quick ramp to 100 users
    { duration: '1m', target: 100 },    // Stay at 100 users (baseline)
    { duration: '30s', target: 1000 },  // Spike to 1000 users (STRESS!)
    { duration: '3m', target: 1000 },   // Maintain stress for 3 minutes
    { duration: '30s', target: 100 },   // Drop back to 100 users
    { duration: '2m', target: 100 },    // Recovery period
    { duration: '30s', target: 0 },     // Ramp down to 0
  ],
  thresholds: {
    http_req_failed: ['rate<0.2'],       // Allow 20% failure rate under extreme stress
    http_req_duration: ['p(90)<2000'],   // 90% of requests should be below 2s
    http_req_duration: ['p(95)<5000'],   // 95% of requests should be below 5s
    http_reqs: ['rate>500'],             // Should handle at least 500 RPS
  },
};

export default function () {
  // Stress test focuses on the main health endpoint
  const res = http.get('https://api.myce.live/actuator/health', {
    timeout: '10s', // Longer timeout for stress conditions
  });
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'not server error': (r) => r.status < 500,
    'response received': (r) => r.status !== 0, // Any response is better than timeout
  });
  
  // Minimal sleep to maximize load
  sleep(Math.random() * 1);
}