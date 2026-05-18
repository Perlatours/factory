#!/usr/bin/env bash
# dump-state.sh — pg_dump completo a db/snapshots/YYYY-MM-DD-HHMM.sql
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/db/snapshots"
mkdir -p "$OUT_DIR"

TS=$(date +'%Y-%m-%d-%H%M')
OUT="$OUT_DIR/$TS.sql"

docker exec factory-db pg_dump -U factory -d factory --clean --if-exists > "$OUT"

echo "✓ Snapshot: $OUT ($(wc -l < "$OUT") líneas, $(du -h "$OUT" | cut -f1))"
