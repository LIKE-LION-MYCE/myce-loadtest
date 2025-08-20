import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 1,  // 1 virtual user
  duration: '10s',  // for 10 seconds
  thresholds: {
    http_req_failed: ['rate<0.1'], // http errors should be less than 10%
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
  },
};

export default function () {
  // Test your health endpoint
  const res = http.get('https://api.myce.live/actuator/health');
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}