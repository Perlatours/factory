---
name: factory-pull
description: |
  Supervisor de línea Pull. Orquesta las Fases 1-5 (análisis doc → checklist → sandbox →
  mock tests → mismatches → informe final) invocando las skills atómicas y registrando
  estado en DB. Para una conexión Pull existente con Intake aprobado.
  Invocar cuando Santi diga "ejecuta factory-pull X", "avanza Avoris hasta informe",
  "/factory-pull avoris" o "/factory-pull avoris --phase 3".
version: "0"
allowed-tools: [Bash, Read, Write]
---

# Factory Pull — Supervisor

Orquestador del flujo Pull Fases 1-5 (anti-tactical: no codifica ni hace deploy; eso es F6+ con humano).

## Sintaxis

```
/factory-pull <slug>                       # avanza desde current_phase hasta el siguiente HITL
/factory-pull <slug> --phase <N>           # ejecuta una fase concreta
/factory-pull <slug> --resume              # retoma tras una pausa o crash (idempotente)
```

## Pre-requisitos

- Conexión existe con `current_phase >= 1` (Intake aprobado)
- `pilots/<slug>/inputs/` poblado con doc + creds

## Flujo

### Fase 1 — Análisis doc + checklist (humano lee, marca con factory-checklist)

La fase 1 es **mayormente humana** — Pedro/Santi lee la doc y marca filas. La skill ayuda:
- Lista filas pendientes con su `expected`
- Cuando el humano da contexto, sugiere clasificación tentativa
- Cuando todas marcadas → llama `/factory-checklist finalize` → HITL #1 listo

### Fase 2 — Sandbox validation

```
/factory-sandbox validate <slug>
```

Si outcome='pass' → `/factory-update <slug> --phase 3`.
Si outcome='partial'/'fail' → STOP, mostrar al humano, NO avanzar automáticamente.

### Fase 3 — Mock tests

```
/factory-mocktests run <slug> --env perlahub-dev
```

Pass de los 7 casos → `/factory-update <slug> --phase 4`.
Cualquier fail → mostrar al humano.

### Fase 4 — Clasificar mismatches

```
/factory-mismatches classify <slug>
```

Genera reporte. Si hay row_keys "genuinamente nuevas" → marca HITL #3 como pending visible.

### Fase 5 — Informe final

Compila:
- `pilots/<slug>/STATE.md` (vía `bash scripts/dump-pilot.sh`)
- `pilots/<slug>/outputs/mismatches-classified.md`
- Score real (suma 5 ejes)
- Lista wrappers Core necesarios
- Recomendación: ¿proceder a Fase 6 codificación o pivotar/cancelar?

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE hitl_gates SET notes='Informe final listo, esperando review Pedro'
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG') AND gate_number=1;
SQL
```

→ **HITL #1 listo para Pedro**. Aquí termina el supervisor F1-5. F6 (codificación) y F7-8 (E2E + go-live) van fuera de la planta — se ejecutan en repo PerlaHub con humano.

## Rebobinado

```
/factory-update <slug> --phase 2   # de F4 a F2, conserva filas y artefactos
/factory-pull <slug> --resume      # retoma desde la nueva fase
```

## Idempotencia

Esta skill es **idempotente por diseño**:
- Cada llamada lee `current_phase` de DB
- Solo actúa si la fase actual corresponde
- Si una fase intermedia falló, `--resume` la repite sin duplicar registros (las skills atómicas usan ON CONFLICT donde aplica)
