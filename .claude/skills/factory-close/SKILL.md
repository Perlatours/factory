---
name: factory-close
description: |
  Cierra una conexión que ha cumplido DoD (tráfico estable según umbral §0.1). Mueve pilots/<slug>/
  a case_studies/<slug>/, consolida lecciones en `catalog/known-mismatches-pull.md` (Anexo D vivo)
  y `catalog/wrappers-pull.md`, marca status='done' en DB, guarda memoria en brain.
  Invocar cuando Santi diga "cierra conexión X", "/factory-close avoris".
version: "0"
allowed-tools: [Bash, Read, Write]
---

# Factory Close

## Sintaxis

```
/factory-close <slug>                    # checks DoD + cierre completo
/factory-close <slug> --force            # cerrar aunque DoD incompleto (registra excepción)
```

## DoD checks (Pull)

```bash
SLUG="$1"

# 1. Métrica booking_error_rate < 4% en perlahub-prod durante N días
N_DIAS=${DOD_DAYS:-7}  # threshold §0.1 PLAN — confirmar valor con Pedro

LATEST_ERR=$(docker exec -i factory-db psql -U factory -d factory -t -A <<SQL
SELECT value FROM metrics
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND target_env='perlahub-prod'
  AND metric_name='booking_error_rate'
ORDER BY metric_date DESC LIMIT 1;
SQL
)

if [[ -z "$LATEST_ERR" ]] || (( $(echo "$LATEST_ERR >= 0.04" | bc -l) )); then
  echo "✗ booking_error_rate último = ${LATEST_ERR:-N/A}, threshold <4%. Usa --force si justificas."
  exit 1
fi

# 2. HITLs todos aprobados
PEND=$(docker exec -i factory-db psql -U factory -d factory -t -A <<SQL
SELECT COUNT(*) FROM hitl_gates
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND status='pending';
SQL
)
[[ "$PEND" != "0" ]] && { echo "✗ Quedan $PEND HITL gates pendientes"; exit 1; }

# 3. Sorpresas todas resueltas
OPEN_SURP=$(docker exec -i factory-db psql -U factory -d factory -t -A <<SQL
SELECT COUNT(*) FROM surprises
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND NOT resolved;
SQL
)
[[ "$OPEN_SURP" != "0" ]] && {
  echo "⚠ Quedan $OPEN_SURP sorpresas abiertas. Resuélvelas con /factory-surprise resolve o usa --force"
  exit 1
}
```

## Cierre

```bash
# 1. Consolidar lecciones a catalog/
# Anexo D — añadir nuevas filas problemáticas que se resolvieron
docker exec -i factory-db psql -U factory -d factory <<SQL > /tmp/anexo-d-additions.md
SELECT '### '||s.related_row_key||E'\n'||
       '- Primera detección: '||(SELECT slug FROM connections WHERE id=s.connection_id)||E'\n'||
       '- Resolución: '||COALESCE(s.resolution_notes,'')||E'\n'||
       '- Wrapper: TBD'||E'\n'
FROM surprises s
WHERE s.connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND s.resolved AND s.catalog_anexo='D';
SQL

cat /tmp/anexo-d-additions.md >> catalog/known-mismatches-pull.md

# 2. case_study con todo
mkdir -p case_studies/$SLUG
cp -r pilots/$SLUG/* case_studies/$SLUG/ 2>/dev/null || true
bash scripts/dump-pilot.sh $SLUG  # snapshot final
mv pilots/$SLUG/STATE.md case_studies/$SLUG/STATE-final.md

# 3. Marcar status=done en DB
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE connections SET status='done', notes=COALESCE(notes||E'\n','')||'Cerrada $(date +%Y-%m-%d)'
WHERE slug='$SLUG';
INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        (SELECT current_phase FROM connections WHERE slug='$SLUG'),
        99, 'claude/factory-close', 'DoD cumplido. Cierre conexión.');
SQL

# 4. Eliminar pilots/<slug>/ tras moverlo
rm -rf pilots/$SLUG

# 5. Regenerar
bash scripts/dump-registry.sh
git add catalog/ case_studies/$SLUG REGISTRY.md
git rm -rf pilots/$SLUG 2>/dev/null || true
git commit -m "feat(close $SLUG): conexión done · catálogo consolidado"

# 6. Actualizar brain
cat <<MEM
Crear/actualizar memoria brain:
  project_factory_close_${SLUG}_$(date +%Y%m%d).md
con: número conexión, mismatches nuevos al catálogo, wrappers usados,
horas Santi reales, días calendario, sorpresas y resoluciones.
MEM
```

## Recordar tras cierre

- ¿Hay wrapper nuevo que añadir a `catalog/wrappers-pull.md`?
- ¿La skill `factory-pull` mejora? → `docs/pull-skill-YYYY-MM-DD.md`
- ¿Decisión nueva P7+ que debe ir a `catalog/decisions-p1-p6.md`?
