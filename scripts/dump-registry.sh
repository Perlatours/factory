#!/usr/bin/env bash
# dump-registry.sh — regenera REGISTRY.md desde DB
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$ROOT/REGISTRY.md"

psql_cmd() {
  docker exec -i factory-db psql -U factory -d factory -t -A -F '|' "$@"
}

format_row() {
  # input: pipe-separated → markdown table row
  awk -F'|' '{
    line = "|"
    for (i=1; i<=NF; i++) line = line " " $i " |"
    print line
  }'
}

{
  echo "# Factory · REGISTRY"
  echo ""
  echo "_Auto-generado por \`scripts/dump-registry.sh\`. No editar a mano._"
  echo ""
  echo "_Última actualización: $(date -u +'%Y-%m-%d %H:%M:%S UTC')_"
  echo ""
  echo "## Conexiones activas"
  echo ""
  echo "| Slug | Factory | Modo | Fase | Status | DEV | PROD | HITL pend. | Owner |"
  echo "|---|---|---|---|---|---|---|---|---|"

  psql_cmd <<'SQL' | format_row
SELECT
  c.slug,
  c.factory,
  COALESCE(c.mode,'—'),
  c.current_phase,
  c.status,
  c.dev_status,
  c.prod_status,
  COALESCE((SELECT string_agg('#'||gate_number, ',' ORDER BY gate_number)
            FROM hitl_gates h
            WHERE h.connection_id = c.id AND h.status = 'pending'), '—'),
  COALESCE(c.owner_hitl,'—')
FROM connections c
WHERE c.status IN ('active','awaiting_intake','dormant')
ORDER BY c.factory, c.current_phase DESC, c.slug;
SQL

  echo ""
  echo "## Cerradas / done"
  echo ""
  echo "| Slug | Factory | Cerrada | Notas |"
  echo "|---|---|---|---|"
  psql_cmd <<'SQL' | format_row
SELECT c.slug, c.factory, COALESCE(c.updated_at::text,'—'), COALESCE(c.notes,'—')
FROM connections c
WHERE c.status = 'done'
ORDER BY c.updated_at DESC;
SQL

  echo ""
  echo "## Rechazadas en Intake (Fase 0)"
  echo ""
  echo "| Slug | Factory | Notas |"
  echo "|---|---|---|"
  psql_cmd <<'SQL' | format_row
SELECT c.slug, c.factory, COALESCE(c.notes,'—')
FROM connections c
WHERE c.status = 'rejected_intake'
ORDER BY c.updated_at DESC;
SQL
} > "$OUT"

echo "✓ REGISTRY.md regenerado ($(wc -l < "$OUT") líneas)"
