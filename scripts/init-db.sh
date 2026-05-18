#!/usr/bin/env bash
# init-db.sh — levanta el container Postgres factory y verifica conectividad
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▶ Iniciando factory-db (postgres:17-alpine, port 5433)..."
docker compose up -d

echo "▶ Esperando healthcheck..."
for i in $(seq 1 30); do
  state=$(docker inspect -f '{{.State.Health.Status}}' factory-db 2>/dev/null || echo "starting")
  if [[ "$state" == "healthy" ]]; then
    echo "✓ factory-db healthy"
    break
  fi
  sleep 2
done

if [[ "${state:-}" != "healthy" ]]; then
  echo "✗ factory-db no llegó a healthy. Revisa: docker logs factory-db"
  exit 1
fi

echo "▶ Verificando schema..."
docker exec factory-db psql -U factory -d factory -c '\dt'

echo "✓ Listo. Conecta con:"
echo "  psql -h localhost -p 5433 -U factory -d factory   # password: factory_local"
