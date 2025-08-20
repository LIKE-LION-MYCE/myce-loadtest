import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    // Phase 1: Baseline - Single User
    { duration: '30s', target: 1 },    // Start with 1 user
    
    // Phase 2: Light Load
    { duration: '1m', target: 10 },    // Ramp to 10 users
    { duration: '1m', target: 10 },    // Hold 10 users
    
    // Phase 3: Medium Load - System starts to show stress
    { duration: '1m', target: 25 },    // Ramp to 25 users
    { duration: '2m', target: 25 },    // Hold 25 users
    
    // Phase 4: Heavy Load - Single instance struggles
    { duration: '1m', target: 50 },    // Ramp to 50 users
    { duration: '2m', target: 50 },    // Hold 50 users - response times degrade
    
    // Phase 5: Critical Load - System near breaking point
    { duration: '1m', target: 100 },   // Ramp to 100 users
    { duration: '3m', target: 100 },   // Hold 100 users - high response times
    
    // Phase 6: Scaling Story - Future auto-scaling would kick in here
    // For now, show system recovery by reducing load
    { duration: '1m', target: 25 },    // Simulate load balancer redistribution
    { duration: '1m', target: 10 },    // Back to comfortable level
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],      // Less than 10% failures
    http_req_duration: ['p(95)<2000'],   // 95% under 2s (relaxed for demo)
    http_req_duration: ['p(99)<5000'],   // 99% under 5s (very relaxed)
  },
};

export default function () {
  // Test realistic endpoints
  const endpoints = [
    'https://api.myce.live/actuator/health',
    'https://api.myce.live/actuator/info',
    'https://api.myce.live/actuator/metrics',
  ];
  
  // Pick random endpoint to simulate varied load
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  const res = http.get(endpoint);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 5000ms': (r) => r.timings.duration < 5000,
    'response has content': (r) => r.body && r.body.length > 0,
  });
  
  // Realistic user think time (1-3 seconds)
  sleep(Math.random() * 2 + 1);
}