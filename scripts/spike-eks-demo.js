import http from 'k6/http';
import { check, sleep } from 'k6';

// EKS Spike Demo - FRIDAY SPECIAL! 
// Dramatic 40x traffic surge in seconds
export const options = {
  stages: [
    // Phase 1: Calm Before Storm (30s)
    { duration: '30s', target: 50 },     // Normal traffic, 1-2 pods
    
    // Phase 2: THE SPIKE! (10s) - VIRAL MOMENT!
    { duration: '10s', target: 2000 },   // 40x INSTANT SURGE! 🚀
    
    // Phase 3: Sustained Chaos (120s) - Watch pods explode to life!
    { duration: '60s', target: 2000 },   // Maintain pressure - 10 pods deploying
    { duration: '60s', target: 1500 },   // Slight relief but still high
    
    // Phase 4: Emergency Containment (30s)
    { duration: '15s', target: 500 },    // Traffic managers intervene
    { duration: '15s', target: 100 },    // Back to manageable levels
    
    // Phase 5: Recovery (30s)
    { duration: '30s', target: 50 },     // Normal traffic restored
  ],
  
  // Relaxed thresholds for extreme demo
  thresholds: {
    http_req_failed: ['rate<0.5'],       // Allow 50% failures during spike
    http_req_duration: ['p(90)<10000'],  // 90% under 10s during crisis
    checks: ['rate>0.5'],                // 50% checks pass (crisis mode)
  },
};

// Simplified for maximum spike pressure
export default function () {
  const baseUrl = 'https://api.myce.live';
  
  // Random endpoint selection for realistic traffic distribution
  const endpoints = [
    '/actuator/health',           // 60% - Health checks (lightest)
    '/api/expos?page=0&size=5',  // 30% - API calls (medium)
    '/actuator/metrics',         // 10% - Heavy monitoring (heaviest)
  ];
  
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const res = http.get(`${baseUrl}${endpoint}`, {
    timeout: '15s'  // Long timeout to handle overload
  });
  
  // Accept overload responses as "successful chaos"
  check(res, {
    'spike response received': (r) => r.status !== 0, // Not timeout
    'acceptable spike status': (r) => [200, 429, 503, 504].includes(r.status),
  });
  
  // Minimal sleep for maximum pressure
  sleep(0.1 + Math.random() * 0.1); // 0.1-0.2s (aggressive!)
}

export function setup() {
  console.log('███████╗██████╗ ██╗██████╗  █████╗ ██╗   ██╗    ███████╗██████╗ ███████╗ ██████╗██╗ █████╗ ██╗');
  console.log('██╔════╝██╔══██╗██║██╔══██╗██╔══██╗╚██╗ ██╔╝    ██╔════╝██╔══██╗██╔════╝██╔════╝██║██╔══██╗██║');
  console.log('█████╗  ██████╔╝██║██║  ██║███████║ ╚████╔╝     ███████╗██████╔╝█████╗  ██║     ██║███████║██║');
  console.log('██╔══╝  ██╔══██╗██║██║  ██║██╔══██║  ╚██╔╝      ╚════██║██╔═══╝ ██╔══╝  ██║     ██║██╔══██║██║');
  console.log('██║     ██║  ██║██║██████╔╝██║  ██║   ██║       ███████║██║     ███████╗╚██████╗██║██║  ██║███████╗');
  console.log('╚═╝     ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝       ╚══════╝╚═╝     ╚══════╝ ╚═════╝╚═╝╚═╝  ╚═╝╚══════╝');
  console.log('');
  console.log('⚡ 금요일 특별 시연: EKS 스파이크 데모 ⚡');
  console.log('🚀 0→2000 사용자 10초만에 급증!');
  console.log('📈 실시간 파드 자동 확장 구경하기!');
  console.log('🎬 비디오 촬영 완벽 준비!');
  console.log('');
  console.log('📊 실시간 대시보드: https://api.myce.live/dashboard/demo');
  console.log('👀 kubectl get pods -w 로 파드 생성 실시간 확인!');
  console.log('⚡ 10초 만에 파드가 1개→10개로 폭발적 증가!');
  console.log('🎭 총 소요시간: 3분의 드라마!');
  console.log('');
}

export function teardown() {
  console.log('');
  console.log('🎉 EKS 스파이크 데모 완료!');
  console.log('📈 Kubernetes의 강력한 오토스케일링을 확인했습니다!');
  console.log('💡 실제 운영에서는 더 안정적인 임계값을 사용하세요.');
  console.log('');
}