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

## Reglas de captura (obligatorias)

1. **Flujo COMPLETO en todos los casos.** Cada caso recorre `avail → prebook → book → cancel` de extremo a extremo, no solo hasta prebook. (Una validación parcial — p.ej. multi-room solo hasta prebook — deja sin probar el book real y se sobre-afirma "PASS".)
2. **Siempre con tarifa REEMBOLSABLE 100%** (cancelación gratis): elegir un rate con cancelación gratuita en la fecha de la prueba para que `book`+`cancel` tengan **coste 0**. Nunca NRF para estos casos.
3. **Registrar RQ y RS de cada paso** en ficheros separados (`<caso>-<step>-rq.json` / `<caso>-<step>-rs.json`). No basta el RS: muchas causas (index de travellers, paridad de token, ages-mismatch) solo se ven comparando RQ↔RS.
4. **Multi-room/multi-occupancy: capturar una RS con el desglose REAL** (≥2 rooms con su **precio por-room** `rooms[].pricing` y, si es reembolsable, **varios tramos** de política). Es la RS que la implementación usará como fixture multi-room (el mock single-room **no ejercita** la rama multi-room → el bug de "precio de opción ≠ Σ rooms" / política mal aplicada pasa desapercibido; regresión Avoris jun-2026). **Invariante a comprobar en el RS canónico: `option.Price == Σ rooms[].Price`** y la `cancelPolicy` a nivel opción con el total correcto.

## 7 casos estándar Pull

| # | Caso | Qué prueba | Flujo |
|---|---|---|---|
| 1 | basic_1_night | Happy path: 1 hotel, 1 room, 1 noche, 2 adultos | avail→prebook→book→cancel |
| 2 | multi_night | Mismo, 7 noches → ¿pricing nightly vs total? | avail→prebook→book→cancel |
| 3 | multi_room | 2 rooms en mismo booking | avail→prebook→**book→cancel** (no parar en prebook) |
| 4 | multi_occupancy | 2 adultos + 1 niño 8 años + 1 bebé | avail→prebook→book→cancel |
| 5 | currency_switch | Misma búsqueda en USD vs EUR → ¿forzable? | avail (×2 divisa) |
| 6 | edge_dates | Check-in mañana / check-in +12 meses | avail→prebook→book→cancel |
| 7 | cancel_flow | Book → cancel; medir **latencia book→cancel** (timestamps) | avail→prebook→book→cancel |

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
