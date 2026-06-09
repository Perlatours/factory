#!/usr/bin/env bash
# server-bootstrap.sh — levanta el factory completo (DB + panel) en un server limpio.
# Probado para Ubuntu 24.04 (Huawei Cloud ECS). Idempotente: re-ejecutar actualiza y re-levanta.
#
#   Uso (en el server):  bash scripts/server-bootstrap.sh [branch]
#
set -euo pipefail

REPO_URL="${FACTORY_REPO_URL:-https://github.com/Perlatours/factory.git}"
BRANCH="${1:-rehearsal/avoris-pull}"
DIR="${FACTORY_DIR:-$HOME/factory}"

echo "▶ 1/5 Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi
docker --version

echo "▶ 2/5 Repo ($BRANCH)"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" fetch origin
  git -C "$DIR" checkout "$BRANCH"
  git -C "$DIR" pull --ff-only
else
  git clone -b "$BRANCH" "$REPO_URL" "$DIR"
fi
cd "$DIR"

echo "▶ 3/5 Levantar DB + panel (docker compose)"
docker compose up -d --build

echo "▶ 4/5 Esperar DB healthy"
until docker exec factory-db pg_isready -U factory -d factory >/dev/null 2>&1; do
  printf '.'; sleep 2
done
echo " ok"

echo "▶ 5/5 Restaurar estado (snapshot Fase 5)"
SNAP="$(ls -t db/snapshots/*.sql 2>/dev/null | head -1 || true)"
if [ -n "$SNAP" ]; then
  echo "  restaurando $SNAP"
  docker exec -i factory-db psql -U factory -d factory -q < "$SNAP"
else
  echo "  (sin snapshot; la DB queda con schema+seed base)"
fi

EIP="$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo '<EIP>')"
echo ""
echo "✓ Factory levantado."
echo "  Panel:  http://$EIP:3000   (abrir puerto 3000 en el Security Group)"
echo "  DB:     docker exec -i factory-db psql -U factory -d factory"
echo ""
echo "  Skills: funcionan igual (docker exec -i factory-db ...). Para re-correr"
echo "  sandbox/mocktests, crea pilots/<slug>/inputs/03-credentials.local.env (git-ignored)."
