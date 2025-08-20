import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up to 100 users over 2 minutes
    { duration: '5m', target: 100 },  // Stay at 100 users for 5 minutes
    { duration: '2m', target: 200 },  // Ramp up to 200 users over 2 minutes  
    { duration: '5m', target: 200 },  // Stay at 200 users for 5 minutes
    { duration: '2m', target: 0 },    // Ramp down to 0 users over 2 minutes
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],      // HTTP errors should be less than 10%
    http_req_duration: ['p(95)<1000'],   // 95% of requests should be below 1s
    http_req_duration: ['p(99)<2000'],   // 99% of requests should be below 2s
  },
};

export default function () {
  // Test multiple endpoints to simulate realistic load
  const endpoints = [
    'https://api.myce.live/actuator/health',
    'https://api.myce.live/actuator/info',
    'https://api.myce.live/actuator/metrics',
  ];
  
  // Pick a random endpoint
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  const res = http.get(endpoint);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
    'response has content': (r) => r.body && r.body.length > 0,
  });
  
  // Random sleep between 1-3 seconds to simulate user think time
  sleep(Math.random() * 2 + 1);
}