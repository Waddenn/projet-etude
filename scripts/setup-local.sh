#!/bin/bash
# Setup local development environment
set -euo pipefail

echo "=== DevBoard - Local Setup ==="

# Check prerequisites
for cmd in docker go node npm; do
  if ! command -v $cmd &>/dev/null; then
    echo "ERROR: $cmd is not installed"
    exit 1
  fi
done

echo "[1/4] Installing Go dependencies..."
cd app/backend && go mod download && cd ../..

echo "[2/4] Installing Node dependencies..."
cd app/frontend && npm ci && cd ../..

echo "[3/4] Starting services..."
docker compose up -d postgres
echo "Waiting for PostgreSQL..."
sleep 5

echo "[4/4] Running database migration..."
cd app/backend && DATABASE_URL="postgres://devboard:devboard@localhost:5432/devboard?sslmode=disable" go run ./cmd/main.go &
API_PID=$!
sleep 3
kill $API_PID 2>/dev/null || true
cd ../..

echo ""
echo "=== Setup complete! ==="
echo "Run 'make up' to start all services"
echo "Run 'make dev' to start in development mode"
echo ""
echo "Endpoints:"
echo "  Frontend: http://localhost:3000"
echo "  Backend:  http://localhost:8080"
echo "  API:      http://localhost:8080/api/v1/projects"
echo "  Health:   http://localhost:8080/health"
echo "  Metrics:  http://localhost:8080/metrics"
