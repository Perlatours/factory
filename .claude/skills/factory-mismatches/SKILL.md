---
name: factory-mismatches
description: |
  Clasifica los mismatches detectados en una conexión (filas 🟡🔴 + sorpresas) contra el catálogo
  `catalog/known-mismatches-pull.md` y cross-conexión en checklist_responses. Separa conocidos
  (auto-clasificables) vs nuevos (flagged HITL #3 obligatorio). Es Fase 4 de Pull.
  Invocar cuando Santi diga "clasifica mismatches de X", "Fase 4 de X".
version: "0"
allowed-tools: [Bash, Read]
---

# Factory Mismatches

## Sintaxis

```
/factory-mismatches classify <slug>      # corre clasificación auto + lista lo flagged
/factory-mismatches show <slug>          # ver el output actual
```

## classify

### 1. Listar filas problemáticas

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT row_key, row_label, classification, provider_value, justification
FROM checklist_responses
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND classification IN ('yellow','red')
ORDER BY classification DESC, row_key;
SQL
```

### 2. Para cada fila, cross-conexión

```bash
# Por cada row_key 🟡🔴:
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT classification, COUNT(*), array_agg(c.slug ORDER BY c.created_at DESC) AS slugs
FROM checklist_responses cr
JOIN connections c ON c.id = cr.connection_id
WHERE cr.row_key='$ROW_KEY'
  AND c.slug != '$SLUG'
  AND cr.classification IS NOT NULL
GROUP BY classification;
SQL
```

### 3. Clasificación de confianza

Para cada `row_key` problemática:

| Precedente cross-conexión | Confianza | Acción |
|---|---|---|
| ≥3 conexiones con mismo patrón | **alta** | Auto-asociar wrapper conocido. Mostrar al humano para confirmación rápida. |
| 1-2 conexiones | **media** | Mostrar precedente, humano decide en HITL #2/#3 |
| 0 conexiones | **baja (genuinamente nueva)** | Flagged. HITL #3 obligatorio. Candidata a Anexo D nueva tras cierre. |

### 4. Generar reporte

```bash
REPORT="pilots/$SLUG/outputs/mismatches-classified.md"
mkdir -p "$(dirname "$REPORT")"

{
  echo "# Mismatches clasificados — $SLUG"
  echo ""
  echo "_Generado: $(date -u +%Y-%m-%d\ %H:%M\ UTC)_"
  echo ""
  echo "## Conocidos (alta confianza)"
  echo "..."  # lista row_key con precedente ≥3
  echo ""
  echo "## Tentativos (media confianza)"
  echo "..."  # 1-2 precedentes
  echo ""
  echo "## Genuinamente nuevos (flagged, HITL #3 obligatorio)"
  echo "..."  # 0 precedentes
  echo ""
  echo "## Wrappers Core sugeridos"
  echo "_(según catalog/wrappers-pull.md)_"
} > "$REPORT"

# Registrar action
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO actions (connection_id, phase, action_type, target_env, outcome, evidence_url)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        4, 'mismatches_classify', 'factory', 'pass', '$REPORT');
SQL
```

## Edge cases

- Sin filas 🟡🔴 → "Sin mismatches. ¿Checklist completada? Si no, /factory-checklist diff <slug>"
- Primera conexión Pull (catálogo vacío v0) → todas serán "genuinamente nuevas". Esperable.
