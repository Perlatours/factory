---
name: factory-mocktests
description: |
  Ejecuta los 7 casos estándar Mock Tests Pull (Fase 3) contra el sandbox del provider:
  basic 1 noche, multi-night, multi-room, multi-occupancy, currency switch, edge dates,
  cancel sin penal vs con penal. Captura outputs y registra outcomes por caso.
  Invocar cuando Santi diga "mock tests de X", "Fase 3 de X", "/factory-mocktests run X".
version: "0"
allowed-tools: [Bash, Read, Write]
---

# Factory Mock Tests

## 7 casos estándar Pull

| # | Caso | Qué prueba |
|---|---|---|
| 1 | basic_1_night | Happy path: 1 hotel, 1 room, 1 noche, 2 adultos |
| 2 | multi_night | Mismo, 7 noches → ¿pricing nightly vs total? |
| 3 | multi_room | 2 rooms en mismo booking |
| 4 | multi_occupancy | 2 adultos + 1 niño 8 años + 1 bebé |
| 5 | currency_switch | Misma búsqueda en USD vs EUR → ¿forzable? |
| 6 | edge_dates | Check-in mañana / check-in +12 meses |
| 7 | cancel_flow | Book → cancel sin penal vs cancel con penal |

## Sintaxis

```
/factory-mocktests run <slug> [--env perlahub-dev]   # ejecuta los 7 casos
/factory-mocktests result <slug>                     # tabla resumen últimos resultados
/factory-mocktests run <slug> --case <n>             # un caso solo
```

## run

```bash
SLUG="$1"
ENV="${2:-perlahub-dev}"
PILOT="pilots/$SLUG"
TS=$(date +%Y%m%d-%H%M)
EVID="$PILOT/evidence/mocktests-$TS"
mkdir -p "$EVID"

# Cargar credenciales y endpoints
set -a; source "$PILOT/inputs/03-credentials.local.env"; set +a

CASES=(basic_1_night multi_night multi_room multi_occupancy currency_switch edge_dates cancel_flow)
for c in "${CASES[@]}"; do
  # Ejecutar caso N (estructura específica por provider, plantilla en templates/pull/mock-cases/)
  echo "▶ caso $c"
  bash "$PILOT/inputs/mock-cases/$c.sh" > "$EVID/$c.out" 2>&1
  RC=$?
  OUTCOME=$( [[ $RC -eq 0 ]] && echo "pass" || echo "fail" )

  docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO actions (connection_id, phase, action_type, target_env, outcome, evidence_url, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        3, 'mock_test', '$ENV', '$OUTCOME',
        '$EVID/$c.out', '$c');
SQL
done

# Tabla resumen
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT notes AS caso, outcome, occurred_at
FROM actions
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND action_type='mock_test'
  AND occurred_at > NOW() - INTERVAL '5 minutes'
ORDER BY occurred_at;
SQL
```

## result

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT notes AS caso,
       outcome,
       MAX(occurred_at) AS last_run
FROM actions
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
  AND action_type='mock_test'
GROUP BY notes, outcome
ORDER BY notes;
SQL
```

## Edge cases

- `$PILOT/inputs/mock-cases/` no existe → "Crea los scripts de caso primero. Plantilla en `templates/pull/mock-cases/`"
- Sandbox provider down → outcome='skipped' + surprise
