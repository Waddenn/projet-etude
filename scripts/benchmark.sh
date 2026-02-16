#!/bin/bash
# Load test script using k6 or fallback to hey/curl
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://localhost:8080}"
DURATION="${DURATION:-30s}"
CONCURRENCY="${CONCURRENCY:-50}"

echo "=== DevBoard Load Test ==="
echo "Target: $TARGET_URL"
echo "Duration: $DURATION"
echo "Concurrency: $CONCURRENCY"
echo ""

if command -v k6 &>/dev/null; then
  echo "Using k6..."
  k6 run --vus "$CONCURRENCY" --duration "$DURATION" - <<'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export default function () {
  const res = http.get(`${__ENV.TARGET_URL || 'http://localhost:8080'}/api/v1/projects`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
  sleep(0.1);
}
EOF
elif command -v hey &>/dev/null; then
  echo "Using hey..."
  hey -z "$DURATION" -c "$CONCURRENCY" "$TARGET_URL/api/v1/projects"
else
  echo "Neither k6 nor hey found. Install one of them:"
  echo "  k6:  https://k6.io/docs/getting-started/installation/"
  echo "  hey: go install github.com/rakyll/hey@latest"
  exit 1
fi
