---
name: factory-update
description: |
  Actualiza una conexión: transiciones de fase, aprobación de HITLs, registro de acciones
  con entorno (DEV/PROD/sandbox), links a PRs. Soporta rebobinado (fase actual ← fase anterior).
  Invocar cuando Santi diga "X pasa a fase N", "apruebo HITL #N de X", "registra deploy de X",
  "rebobinar X a fase N".
version: "0"
allowed-tools: [Bash, Read]
---

# Factory Update

## Sintaxis

```
/factory-update <slug> --phase <N>                                      # avance o rebobinado
/factory-update <slug> --hitl-approve <N> [--approver Pedro] [--evidence url]
/factory-update <slug> --hitl-reject  <N> [--approver Pedro] [--notes "..."]
/factory-update <slug> --action <type> --env <env> --outcome <pass|fail|partial|skipped> [--evidence url] [--notes "..."]
/factory-update <slug> --dev-status <not_deployed|deployed|rolled_back> [--commit hash] [--pr url]
/factory-update <slug> --prod-status <not_deployed|deployed|rolled_back> [--commit hash] [--pr url]
/factory-update <slug> --score-real <0-15>
/factory-update <slug> --status <active|dormant|done|dropped>
```

## --phase N (transición o rebobinado)

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
WITH curr AS (SELECT id, current_phase FROM connections WHERE slug='$SLUG')
INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
SELECT id, current_phase, $NEW_PHASE, 'Santi', '$NOTES' FROM curr;

UPDATE connections SET current_phase = $NEW_PHASE WHERE slug='$SLUG';
SQL
```

Si `$NEW_PHASE < current_phase`: es **rebobinado** — recordar que las filas de checklist anteriores se conservan; solo se invalida si el usuario explícitamente pide `--rewind-clean section X,Y`.

## --hitl-approve N

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE hitl_gates
SET status='approved',
    approver='$APPROVER',
    decided_at=NOW(),
    evidence_url=$EVIDENCE_SQL,
    notes=$NOTES_SQL
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND gate_number=$N;
SQL
```

## --action

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO actions (connection_id, phase, action_type, target_env, outcome, evidence_url, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        (SELECT current_phase FROM connections WHERE slug='$SLUG'),
        '$ACTION_TYPE', '$ENV', '$OUTCOME', $EVIDENCE_SQL, $NOTES_SQL);
SQL
```

`action_type` válidos: `intake_validate, sandbox_validate, mock_test, deploy, e2e_test, prod_smoke, metric_collect, rollback`.

## Post-cambios (siempre)

```bash
bash scripts/dump-pilot.sh $SLUG
bash scripts/dump-registry.sh
# Commit opcional si hay cambios en archivos:
if ! git diff --quiet; then
  git add pilots/$SLUG REGISTRY.md
  git commit -m "update($SLUG): $RESUMEN"
fi
```

## Edge cases

- HITL ya aprobado → "HITL #N ya aprobado por X el Y. Usa --hitl-reset si quieres reabrir"
- Conexión status='rejected_intake' → "Esta conexión está rechazada en Intake. Usa /factory-update <slug> --intake-retry primero"
- Rebobinado a fase 6+ → avisar "Rebobinar de Fase 6+ implica revertir PR en PerlaHub/PerlaPush. Confirma."
