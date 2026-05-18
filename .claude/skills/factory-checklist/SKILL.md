---
name: factory-checklist
description: |
  Marca filas del checklist 🟢🟡🔴 para una conexión, ve diff de progreso, finaliza la checklist
  (todas marcadas → habilita HITL #1) o consulta patterns cross-conexión sobre una fila concreta.
  Invocar cuando Santi diga "marca rate_key_ttl rojo en X", "qué falta de checklist en Y",
  "finaliza checklist Z", "cómo va rate_key_ttl en otras conexiones".
version: "0"
allowed-tools: [Bash, Read]
---

# Factory Checklist

## Sintaxis

```
/factory-checklist mark <slug> --row <row_key> --class <green|yellow|red|na> [--evidence "..."] [--notes "..."]
/factory-checklist diff <slug>                  # qué falta vs total + resumen por sección
/factory-checklist finalize <slug>              # verifica que todas marcadas → marca HITL #1 ready
/factory-checklist patterns <row_key>           # cross-conexión: cómo se ha clasificado en otras
```

## mark

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE checklist_responses
SET classification='$CLASS',
    provider_value=$PROVIDER_VAL_SQL,
    evidence_ref=$EVIDENCE_SQL,
    justification=$NOTES_SQL,
    marked_by='claude/factory-checklist',
    marked_at=NOW()
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND row_key='$ROW_KEY';
SQL
```

Si row_key no existe en la checklist clonada: error "Fila desconocida. Filas disponibles para esta factory: ..." (listar).

## diff

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT section,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE classification IS NULL) AS pending,
       COUNT(*) FILTER (WHERE classification='green')  AS green,
       COUNT(*) FILTER (WHERE classification='yellow') AS yellow,
       COUNT(*) FILTER (WHERE classification='red')    AS red,
       COUNT(*) FILTER (WHERE classification='na')     AS na
FROM checklist_responses
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
GROUP BY section
ORDER BY section;

-- Filas pendientes (sin clasificar)
SELECT section, row_key, row_label
FROM checklist_responses
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND classification IS NULL
ORDER BY section, row_key
LIMIT 20;
SQL
```

## finalize

```bash
# 1. Verificar todas marcadas
PENDING=$(docker exec -i factory-db psql -U factory -d factory -t -A <<SQL
SELECT COUNT(*) FROM checklist_responses
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND classification IS NULL;
SQL
)
if [[ "$PENDING" != "0" ]]; then
  echo "✗ Quedan $PENDING filas sin clasificar. Usa /factory-checklist diff $SLUG"
  exit 1
fi

# 2. Marcar HITL #1 ready (no aprobado aún, listo para review)
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE hitl_gates SET notes='checklist finalizado, listo para review'
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG') AND gate_number=1;
SQL
echo "✓ Checklist finalizado. HITL #1 listo para review por Pedro."
```

## patterns <row_key>

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT cr.classification,
       COUNT(*),
       array_agg(c.slug ORDER BY c.created_at DESC)
FROM checklist_responses cr
JOIN connections c ON cr.connection_id=c.id
WHERE cr.row_key='$ROW_KEY'
  AND c.status IN ('done','active')
  AND cr.classification IS NOT NULL
GROUP BY cr.classification
ORDER BY COUNT(*) DESC;
SQL
```

Output recomendado al humano:

```
Fila `rate_key_ttl`:
  Histórico cross-conexión:
    🔴 en 3/5 conexiones (HB, Dome, Expedia)
    🟡 en 2/5 conexiones (Roibos, Avoris)
    🟢 en 0/5
  Confianza auto: ≥3 previas → AUTO 🔴/🟡
  Wrapper sugerido: RateKeyBuffer (catalog/wrappers-pull.md)
```

Niveles confianza:
- **≥3 previas con mismo patrón** → auto-clasificar (alta confianza)
- **1-2 previas** → tentativa (humano revisa)
- **0 previas** → flagged (HITL #3 obligatorio)
