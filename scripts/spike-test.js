import http from 'k6/http';
import { check, sleep } from 'k6';

// Spike Test - Perfect for Demo!
// Shows sudden traffic surge and how system handles it
export const options = {
  stages: [
    { duration: '1m', target: 50 },     // Normal load
    { duration: '10s', target: 2000 },  // SUDDEN SPIKE! 
    { duration: '1m', target: 2000 },   // Maintain spike
    { duration: '10s', target: 50 },    // Back to normal  
    { duration: '2m', target: 50 },     // Recovery observation
    { duration: '10s', target: 0 },     // Shutdown
  ],
  thresholds: {
    http_req_failed: ['rate<0.3'],       // Allow 30% failure during spike
    http_req_duration: ['p(90)<3000'],   // 90% under 3s during spike
    http_reqs: ['rate>100'],             // Minimum throughput
  },
};

export default function () {
  const res = http.get('https://api.myce.live/actuator/health', {
    timeout: '15s',
  });
  
  check(res, {
    'status is 200 or 503': (r) => r.status === 200 || r.status === 503, // 503 = overloaded but alive
    'not timeout': (r) => r.status !== 0,
  });
  
  // Very short sleep to create maximum spike effect
  sleep(0.1);
}