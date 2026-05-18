#!/usr/bin/env bash
# dump-pilot.sh <slug> — regenera pilots/<slug>/STATE.md
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <slug>"
  exit 1
fi

SLUG="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PILOT_DIR="$ROOT/pilots/$SLUG"

if [[ ! -d "$PILOT_DIR" ]]; then
  echo "✗ pilots/$SLUG no existe. Crea la conexión primero con /factory-new"
  exit 1
fi

PSQL="docker exec -i factory-db psql -U factory -d factory -t -A -F '|'"
OUT="$PILOT_DIR/STATE.md"

{
  echo "# $SLUG · STATE"
  echo ""
  echo "_Auto-generado. Última actualización: $(date -u +'%Y-%m-%d %H:%M:%S UTC')_"
  echo ""
  echo "## Resumen"
  echo ""

  $PSQL <<SQL
SELECT '- **Factory**: '||factory||E'\n'||
       '- **Modo**: '||COALESCE(mode,'—')||E'\n'||
       '- **Fase actual**: '||current_phase||E'\n'||
       '- **Status**: '||status||E'\n'||
       '- **DEV**: '||dev_status||E'  |  **PROD**: '||prod_status||E'\n'||
       '- **Owner HITL**: '||COALESCE(owner_hitl,'—')||E'\n'||
       '- **Contacto**: '||COALESCE(contact_name,'—')||' <'||COALESCE(contact_email,'—')||'>'||E'\n'||
       '- **Volumen**: '||COALESCE(intake_volume_notes,'—')
FROM connections WHERE slug = '$SLUG';
SQL

  echo ""
  echo "## HITL Gates"
  echo ""
  echo "| # | Título | Status | Aprobador | Fecha |"
  echo "|---|---|---|---|---|"
  $PSQL <<SQL
SELECT h.gate_number, COALESCE(h.gate_title,'—'), h.status,
       COALESCE(h.approver,'—'), COALESCE(h.decided_at::text,'—')
FROM hitl_gates h
JOIN connections c ON c.id = h.connection_id
WHERE c.slug = '$SLUG'
ORDER BY h.gate_number;
SQL

  echo ""
  echo "## Phase log (últimas 10)"
  echo ""
  echo "| De | A | Actor | Cuándo | Notas |"
  echo "|---|---|---|---|---|"
  $PSQL <<SQL
SELECT COALESCE(p.from_phase::text,'—'), p.to_phase, COALESCE(p.actor,'—'),
       p.occurred_at::text, COALESCE(p.notes,'—')
FROM phase_log p
JOIN connections c ON c.id = p.connection_id
WHERE c.slug = '$SLUG'
ORDER BY p.occurred_at DESC LIMIT 10;
SQL

  echo ""
  echo "## Sorpresas abiertas"
  echo ""
  $PSQL <<SQL
SELECT '- **'||s.title||'** — '||COALESCE(s.description,'')
FROM surprises s
JOIN connections c ON c.id = s.connection_id
WHERE c.slug = '$SLUG' AND NOT s.resolved
ORDER BY s.detected_at DESC;
SQL

  echo ""
  echo "## Checklist (resumen por sección)"
  echo ""
  echo "| Sección | 🟢 | 🟡 | 🔴 | n/a |"
  echo "|---|---|---|---|---|"
  $PSQL <<SQL
SELECT cr.section,
       COUNT(*) FILTER (WHERE classification='green'),
       COUNT(*) FILTER (WHERE classification='yellow'),
       COUNT(*) FILTER (WHERE classification='red'),
       COUNT(*) FILTER (WHERE classification='na')
FROM checklist_responses cr
JOIN connections c ON c.id = cr.connection_id
WHERE c.slug = '$SLUG'
GROUP BY cr.section
ORDER BY cr.section;
SQL
} | awk -F'|' '
  /^\|/ || /^#/ || /^_/ || /^$/ || /^##/ || /^- / { print; next }
  NF >= 3 {
    line = "|"
    for (i=1; i<=NF; i++) line = line " " $i " |"
    print line
  }
' > "$OUT"

echo "✓ pilots/$SLUG/STATE.md regenerado"
