---
title: Factory · Plan de Industrialización v2.1 (planta autónoma)
date: 2026-05-18
source: Santiago — diseño implementación repo factory/ (Godi.AI/factory)
author: Santiago Patino Serna
tags: [factory, industrializacion, planta, idempotencia, postgres, docker, streamlit, panel-control, skills, claude-code, schema, intake, implementacion]
status: pendiente-respuesta-pedro-decisiones-criticas
owner: Santi
director: Francesc
validator_qa_tecnico: Pedro
validator_qa_funcional: Eva
parent: factory_conexiones.md
related:
  - factory_pull/factory_pull_briefing_v0.md
  - factory_pull/factory-pull-plant-diagram.svg
  - factory_push/factory_push_briefing_v0.md
repo_externo: Godi.AI/factory (remote pendiente Perlatours/factory)
alcance_v0: Pull only en operación; Push schema+seed
history:
  - v0 (2026-05-15): diseño inicial
  - v2 (2026-05-15): integra Docker, checklist_responses, dashboard Streamlit, 4 activos, curva aprendizaje, target 2 días
  - v2.1 (2026-05-18): reframing planta autónoma + Fase 0 Intake gate + panel control + idempotencia explícita + retira estimaciones + 3 decisiones Pedro + roles supervisor/operario + alcance v0 explícito + diagrama SVG
---

# Factory · Plan de Industrialización v2

## TL;DR — Planta autónoma de fabricación de conexiones

**Factory Pull/Push NO es un orquestador de tickets ni un BI. Es una planta de fabricación.** Cada conexión nueva = un coche. La línea tiene **Fase 0 Intake + 8 estaciones + 4 HITL** (Pull; Push análogo con 5 HITL). Lo que hace distinta a esta planta —y es su razón de ser— es que **es idempotente y rebobinable**: si el coche sale con tres ruedas (mismatch detectado en E2E, sorpresa en PROD, dato malformado en mock), retrocedemos a la estación donde se torció y reanudamos sin perder lo aprendido en las anteriores. **Una planta humana no rebobina; una de agentes sí.** Esa propiedad —no la automatización en sí— es el activo.

> *"Damos al ON. Si el coche sale con tres ruedas, retrocedemos al punto donde se torció. Sin perder lo aprendido."*

**Qué hace la planta** (alcance explícito):
- Fabrica conexiones en serie con un proceso estable
- Mide cada lote (tiempo, sorpresas, retrabajos)
- Aprende: la #N hereda catálogo, wrappers, templates y skill calibrada de las N-1 anteriores
- **NO codifica conectores** — eso se mergea en repos PerlaHub/PerlaPush (estación 6)

**Infraestructura de planta** (lo que sostiene la línea):
- **Estado vivo**: Postgres 17 en Docker Compose (7 tablas — cada conexión = filas, no archivos)
- **Panel de control** (no BI): Streamlit local — "¿dónde está cada coche? ¿qué HITL bloquea?"
- **Estaciones**: ~12 skills Claude Code (`factory-status/new/update/checklist/sandbox/mocktests/mismatches/surprise/metric/close` + supervisores `factory-pull`/`factory-push`)
- **Archivo + aprendizaje**: `case_studies/` + `catalog/` (mismatches conocidos, wrappers Core, templates, skill vN)
- **SoT auditable**: `REGISTRY.md` autogenerado + git commits + push `Perlatours/factory`
- **Entornos**: DEV/PROD explícitos por conexión

**Roles en la planta** (detallados en §8):
- **Francesc** — Director de planta · diseña línea · decide qué se fabrica
- **Santi** — Supervisor de línea (NO operario) · mira panel · decide qué conexión avanza · promueve Skill vN
- **Pedro** — Control de calidad técnico · HITL #1, #3, #4 · validator de Skill · decisiones técnicas finales
- **Eva** — Control de calidad funcional · HITL campos nuevos · mapeo hoteles
- **Agente Claude Code** — Operario de skills · ejecuta estaciones cuando el supervisor da orden
- **Solicitante** — Entrega lote en Intake · comercial interno o partner externo

**Alcance v0** (importante para no inflar compromiso): **Pull only en operación**. El schema y seed contemplan también Push (`factory IN ('pull','push','espejo','pushout')`, 170 filas checklist Push pre-seed) para evitar refactor cuando llegue, pero **la Factory no se compromete a arrancar dos verticales en paralelo**. Push se activa cuando Pull esté estable.

**Sobre tiempos**: el tiempo es output empírico de la Factory, no input de este plan. Las primeras conexiones generarán datos reales (horas Santi, días calendario, mismatches nuevos) que poblarán la curva. **No prometemos cifras antes de tener evidencia.** Las únicas magnitudes cuantitativas que sí defendemos son thresholds y reglas (score complejidad 0-3 por eje, booking error rate <4%, niveles de confianza cross-conexión ≥3/1-2/0, N días tráfico estable como umbral DoD).

---

## Diagrama de la planta

![Factory Pull · Planta autónoma de fabricación de conexiones](./factory_pull/factory-pull-plant-diagram.svg)

*Para pegar en la pared del equipo técnico. Si entiendes este diagrama, entiendes el plan.*

Push tendrá un diagrama análogo (5 HITL, 8 estaciones + Modo A/B en HITL #1).

---

## Lecturas en orden para Pedro

Tres documentos, en este orden. Cada uno baja un nivel de detalle. **Si solo lees uno, lee el 1.**

| # | Documento | Qué responde | Tiempo |
|---|---|---|---|
| **1** | [`factory_pull/factory-pull-plant-diagram.svg`](./factory_pull/factory-pull-plant-diagram.svg) (arriba) | "¿Qué es esta planta y cómo se ve?" — Visión completa en una imagen | 2 min |
| **2** | [`factory_pull/factory_pull_briefing_v0.md`](./factory_pull/factory_pull_briefing_v0.md) | **El día a día operativo**: 11 pasos secuenciales + 4 HITL gates, qué pasa en cada uno, dónde se para, qué se valida. Es cómo se fabrica una conexión, paso a paso. Hotelbeds=referencia, Avoris=piloto. | 15 min |
| **3** | [`factory_pull/factory_pull_checklist.md`](./factory_pull/factory_pull_checklist.md) | **La matriz técnica**: ~150 filas (operaciones, identificación, precios, cancelación, sesión…) marcadas 🟢 Directo / 🟡 Interpretación / 🔴 Gap. Es lo que se rellena en Fase 1 por cada conexión nueva. | 20 min |

Análogos para Push: [`factory_push/factory_push_briefing_v0.md`](./factory_push/factory_push_briefing_v0.md) (12 pasos + 5 HITL) y [`factory_push/factory_push_checklist.md`](./factory_push/factory_push_checklist.md) (~170 filas). Push NO está en el v0 operativo (ver §1 decisión #11).

Lo que **este PLAN.md** agrega encima: cómo todo eso vive en un repo operable (Docker + Postgres + panel control + skills Claude Code) y se vuelve idempotente y rebobinable.

---

## 0. Decisiones críticas pendientes de Pedro

Tres decisiones binarias o casi binarias que **bloquean arranque limpio** y solo Pedro puede cerrar. Cualquier otra decisión técnica que esté a punto de cerrarse sin Pedro, pasarla aquí.

### 0.1 N días de tráfico estable para Definition of Done

El plan asumió 24h para conexiones #5+ y 7d para la #1. Mi inclinación: **7 días para las primeras 10 conexiones, evaluar bajar después**. ¿Validas o pones otro umbral?

→ Esta es la única magnitud "temporal" que se mantiene en el plan: es threshold de calidad, no estimación de duración.

### 0.2 Bug L1 cache TTL 600s sin endpoint de invalidación

Documentado en `factory_pull_validaciones.md` como bug abierto. Dos opciones:

- **(a) Aceptar como gap permanente** → la planta convive con él; las skills `factory-sandbox` y `factory-e2e` documentan "esperar 600s tras cambio config" en sus pasos. Coste: pasos de espera más largos en Fase 7.
- **(b) Exponer endpoint de invalidación antes de arrancar Avoris** → trabajo backend PerlaHub (no Factory). Coste: bloquea piloto Avoris hasta que esté.

Mi recomendación: (a) para v0 y (b) en backlog. Pero la decisión es tuya.

### 0.3 InsertRateCodeMapping — ¿endpoint real o no existe?

Las validaciones Pull marcan que el controller dedicado no existe en código. **Aclaración importante**: el Mapping de rate codes **no es una estación de la línea de 8** — es un proceso paralelo necesario para que la conexión funcione en producción (lo opera Eva u operativa, con apoyo de Perla Mapeador). Pero la planta depende de que ese endpoint exista para poder cerrar Fase 7/8 sin bloqueo.

¿Cuál es el endpoint real que usamos hoy para cargar rate code mappings? Si no existe en producción, hay que crearlo antes de que Avoris llegue a Fase 7/8.

---

## 1. Decisiones cerradas

| # | Decisión | Valor |
|---|---|---|
| 1 | Ubicación repo | `~/.../Godi.AI/factory` (remote: `Perlatours/factory`) |
| 2 | Skills ubicación | `factory/.claude/skills/` (viajan con el repo) |
| 3 | Docs | `factory/docs/` (copia **congelada** brain v0.1, no symlink) |
| 4 | SoT vivo | Postgres 17 |
| 5 | **Postgres install** | **Docker Compose** (lectura A: mismo setup reproducible, no servidor central) |
| 6 | DEV/PROD | Modelado explícito en schema + comandos |
| 7 | **Checklist** | Tabla `checklist_responses` (~150 filas/conexión) + skill `factory-checklist` |
| 8 | **Dashboard** | Nivel 1 GitHub `REGISTRY.md` (siempre) + Nivel 2 **Streamlit local** (`factory/dashboard/`) |
| 9 | Backup | Manual `dump-state.sh` (no cron) — commit periódico en `db/snapshots/` |
| 10 | Credenciales provider | `.local.env` git-ignored en `pilots/<slug>/inputs/` |
| 11 | Alcance v0 | Pull only en operación; Push presente en schema y seed para evitar refactor futuro, NO en operación v0 |

## 2. Decisiones pendientes (0 críticas)

Todo lo bloqueante está cerrado. Pendientes de calibrar **durante uso**:
- Ventana deploy PROD: ¿solo madrugada o canary diurno? (revisar política Perlatours)
- N días tráfico estable mínimo: arrancamos con 24h (#5+) y 7d (#1)
- MCP server propio para factory (fuera v0, considerar tras 10 conexiones)

---

## 3. Mapa mental

```
                              ┌────────────────────────┐
   Llega proveedor nuevo ───► │  factory/  (Santi)     │ ◄─── audit · aprendizaje
                              │  ┌──────────────────┐  │
                              │  │ Docker:          │  │
                              │  │ postgres:17      │  │  ← estado vivo
                              │  │ DB=factory       │  │  ← histórico fases
                              │  │ port 5433        │  │  ← HITL gates
                              │  └──────────────────┘  │  ← actions por env
                              │  ┌──────────────────┐  │  ← checklist 150 filas
                              │  │ Streamlit local  │  │  ← vista interactiva
                              │  │ port 8501        │  │
                              │  └──────────────────┘  │
                              │  pilots/<slug>/        │  ← doc proveedor + outputs
                              │  case_studies/         │  ← lecciones cerradas
                              │  catalog/              │  ← Anexo D consolidado
                              │  templates/            │  ← scaffold conector
                              └──────┬─────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                      ▼
        ┌──────────┐           ┌──────────┐            ┌──────────┐
        │ PerlaHub │           │PerlaPush │            │  Brain   │
        │  (Pull)  │           │  (Push)  │            │ (memoria)│
        │ DEV/PROD │           │ DEV/PROD │            │ contexto │
        │ +Wrappers│           │ +Adapter │            │ histórico│
        │  Core    │           │  pattern │            │          │
        └──────────┘           └──────────┘            └──────────┘
```

---

## 4. Arquitectura técnica

```
[Claude Code, cwd=factory/]
    │ invoca skill
    ▼
[factory/.claude/skills/factory-*/SKILL.md]
    │ Bash → psql
    ▼
[Docker container postgres-17-alpine · puerto 5433 · DB=factory]
    │
    ▼ tras cada update
[scripts/dump-registry.sh → REGISTRY.md → git commit]

[Streamlit, cwd=factory/dashboard/]
    │ st.connection("factory")
    ▼
[Same Docker container postgres-17 · puerto 5433]
    │ st.cache_data ttl=10min
    ▼
[Browser localhost:8501 · 4 pantallas]
```

**Stack final**:
- Docker Compose (postgres:17-alpine + healthcheck pg_isready)
- `psql` cliente nativo + Bash en skills
- Streamlit + `st.connection` + `psycopg2`
- Git + GitHub para audit y compartir
- Cero dependencias adicionales

---

## 5. Schema Postgres (7 tablas)

### 5.1 `connections` — 1 fila por integración

```sql
CREATE TABLE connections (
  id              SERIAL PRIMARY KEY,
  slug            TEXT UNIQUE NOT NULL,                    -- 'avoris-pull'
  display_name    TEXT NOT NULL,
  factory         TEXT CHECK (factory IN ('pull','push','espejo','pushout')),
  mode            TEXT,                                      -- 'A' | 'B' | NULL
  is_pilot        BOOLEAN DEFAULT FALSE,
  current_phase   INTEGER DEFAULT 0,
  status          TEXT DEFAULT 'active',                    -- active|dormant|done|dropped
  owner_hitl      TEXT,
  -- DEV/PROD tracking
  dev_status      TEXT DEFAULT 'not_deployed',
  prod_status     TEXT DEFAULT 'not_deployed',
  dev_commit      TEXT,
  prod_commit     TEXT,
  dev_pr_url      TEXT,
  prod_pr_url     TEXT,
  -- métricas factory
  score_initial   INTEGER,
  score_real      INTEGER,
  contact_name    TEXT,
  contact_email   TEXT,
  jira_epic_url   TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 5.2 `phase_log` — transiciones de fase

```sql
CREATE TABLE phase_log (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  from_phase    INTEGER,
  to_phase      INTEGER NOT NULL,
  actor         TEXT,                                       -- 'Santi' | 'claude/factory-pull'
  notes         TEXT,
  occurred_at   TIMESTAMPTZ DEFAULT NOW()
);
```

### 5.3 `hitl_gates`

```sql
CREATE TABLE hitl_gates (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  gate_number   INTEGER NOT NULL,
  gate_title    TEXT,
  status        TEXT DEFAULT 'pending',
  approver      TEXT,
  decided_at    TIMESTAMPTZ,
  evidence_url  TEXT,
  notes         TEXT,
  UNIQUE (connection_id, gate_number)
);
```

### 5.4 `actions` — audit granular por entorno

```sql
CREATE TABLE actions (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  phase         INTEGER,
  action_type   TEXT NOT NULL,                              -- sandbox_validate|mock_test|deploy|
                                                            -- e2e_test|prod_smoke|metric_collect|rollback
  target_env    TEXT NOT NULL,
  outcome       TEXT,                                       -- pass|fail|partial|skipped
  evidence_url  TEXT,
  notes         TEXT,
  occurred_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON actions (connection_id, occurred_at DESC);
```

### 5.5 `checklist_responses` — 150 filas / conexión Pull, 170 / Push (NUEVA)

```sql
CREATE TABLE checklist_responses (
  id              SERIAL PRIMARY KEY,
  connection_id   INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  section         TEXT NOT NULL,                            -- 'A','B',...,'N'/'Q'
  row_key         TEXT NOT NULL,                            -- 'rate_key_ttl' (slug estable)
  row_label       TEXT,                                      -- "rateKey TTL"
  expected        TEXT,                                      -- "Token opaco para Prebook/Book"
  provider_value  TEXT,                                      -- "UUID, TTL 5min según doc §4.2"
  classification  TEXT CHECK (classification IN ('green','yellow','red','na')),
  evidence_ref    TEXT,                                      -- "doc API §4.2" | "postman case 3"
  justification   TEXT,
  marked_by       TEXT,                                      -- 'claude/factory-pull' | 'Santi'
  marked_at       TIMESTAMPTZ DEFAULT NOW(),
  reviewed_by     TEXT,                                      -- humano valida finalize
  reviewed_at     TIMESTAMPTZ,
  UNIQUE (connection_id, row_key)
);

CREATE INDEX ON checklist_responses (row_key, classification);
-- ↑ permite cross-conexión: "qué % de providers son 🔴 en rate_key_ttl"

-- Pre-seed catálogo de filas estándar Pull (150) y Push (170)
-- desde docs/factory_pull_checklist.md y docs/factory_push_checklist.md
```

### 5.6 `surprises`

```sql
CREATE TABLE surprises (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  catalog_anexo TEXT,                                       -- 'B'|'C'|'D'
  related_row_key TEXT,                                      -- vincula con checklist_responses
  resolved      BOOLEAN DEFAULT FALSE,
  detected_at   TIMESTAMPTZ DEFAULT NOW(),
  resolved_at   TIMESTAMPTZ,
  resolution_notes TEXT
);
```

### 5.7 `metrics`

```sql
CREATE TABLE metrics (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  target_env    TEXT NOT NULL,
  metric_date   DATE NOT NULL,
  metric_name   TEXT NOT NULL,                              -- booking_error_rate|reject_shape_rate|...
  value         NUMERIC,
  source        TEXT,                                       -- grafana|audit_api|manual
  UNIQUE (connection_id, target_env, metric_date, metric_name)
);
```

---

## 6. Catálogo de entornos

`factory/config/environments.yml`:

```yaml
environments:
  perlahub-dev:
    type: perlahub
    stage: dev
    base_url: https://dev.api.perlatours.com
    audit_api: https://dev.api.perlatours.com/PerlaAdmin/
    branch: dev

  perlahub-prod:
    type: perlahub
    stage: prod
    base_url: https://api.perlatours.com
    audit_api: https://api.perlatours.com/PerlaAdmin3/
    branch: main
    db_host: 101.46.37.235:5432

  perlapush-dev:
    type: perlapush
    stage: dev
    base_url: https://dev.push.perlatours.com
    masters_api: https://dev.push.perlatours.com/masters/

  perlapush-prod:
    type: perlapush
    stage: prod
    base_url: https://push.perlatours.com
    masters_api: https://push.perlatours.com/masters/

# Sufijos auto-poblados desde pilots/<slug>/inputs/03-credentials.local.env:
#   provider-<slug>-sandbox
#   provider-<slug>-prod
```

`config/environments.local.yml` git-ignored para credenciales sensibles.

---

## 7. Estructura del repo (actualizada)

```
factory/
├── README.md
├── PLAN.md                                     # Este documento
├── REGISTRY.md                                 # ← Tabla auto-generada
├── docker-compose.yml                          # ← NUEVO: postgres:17-alpine
├── db/
│   ├── schema.sql                              # 7 tablas idempotentes
│   ├── seed.sql                                # 9 candidatos reales
│   ├── seed-checklist-rows.sh                  # parsea docs/, INSERT catálogo filas estándar
│   ├── migrations/
│   └── snapshots/                              # dump-state.sh outputs (git-tracked)
├── config/
│   ├── environments.yml
│   └── environments.local.yml                  # git-ignored
├── scripts/
│   ├── init-db.sh                              # docker compose up + apply schema + seed
│   ├── dump-registry.sh                        # psql → REGISTRY.md
│   ├── dump-pilot.sh                           # psql → pilots/<slug>/STATE.md
│   ├── dump-state.sh                           # pg_dump → db/snapshots/YYYY-MM-DD.sql
│   ├── restore-state.sh
│   └── scaffold-connector.sh                   # clona template a repo PerlaHub
├── dashboard/                                  # ← NUEVO: Streamlit local
│   ├── app.py
│   ├── requirements.txt
│   ├── .streamlit/secrets.toml.example         # plantilla
│   └── README.md
├── pilots/                                     # CONEXIONES ACTIVAS
│   └── <slug>/
│       ├── STATE.md
│       ├── inputs/
│       ├── evidence/
│       └── outputs/
├── case_studies/                               # CONEXIONES CERRADAS
│   └── <slug>/
├── templates/
│   ├── pull/
│   │   ├── pilot-skeleton/                     # plantilla MDs por fase
│   │   └── connector-skeleton/                 # ← NUEVO: scaffold para PerlaHub repo
│   ├── push/
│   │   ├── pilot-skeleton/
│   │   └── adapter-skeleton/                   # scaffold IProviderAdapter
│   └── espejo/
├── docs/                                       # CONGELADO desde brain v0.1
│   ├── factory_conexiones.md
│   ├── factory_pull/                           # ya copiado
│   ├── factory_push/                           # ya copiado
│   └── example-pull-walkthrough.md             # ya creado
├── catalog/                                    # APRENDIZAJE SISTÉMICO
│   ├── decisions-p1-p6.md
│   ├── decisions-d1-d6.md
│   ├── known-mismatches-pull.md                # Anexo D Pull (crece)
│   ├── known-mismatches-push.md                # Anexo D Push (crece)
│   └── wrappers-pull.md                        # ← NUEVO: manifiesto wrappers Core PerlaHub
└── .claude/skills/                             # ~12 skills
    ├── factory-status/SKILL.md
    ├── factory-new/SKILL.md
    ├── factory-update/SKILL.md
    ├── factory-checklist/SKILL.md              # ← NUEVO: mark + finalize + diff + patterns
    ├── factory-sandbox/SKILL.md                # ← NUEVO: validate endpoints
    ├── factory-mocktests/SKILL.md              # ← NUEVO: run + result + run --env
    ├── factory-mismatches/SKILL.md             # ← NUEVO: classify contra catálogo
    ├── factory-surprise/SKILL.md
    ├── factory-metric/SKILL.md
    ├── factory-close/SKILL.md
    ├── factory-pull/SKILL.md                   # workflow orquestador (iter 2)
    ├── factory-push/SKILL.md
    └── factory-espejo/SKILL.md
```

---

## 8. Roles

**Importante**: separamos explícitamente **supervisión** (qué se fabrica y cuándo, decisiones técnicas finales) de **operación** (ejecutar las estaciones cuando llega la orden). En una planta real son cosas distintas; aquí también.

| Rol | Persona | Responsabilidad |
|---|---|---|
| **Director de planta** | Francesc | Diseña la línea, decide qué se fabrica, prioriza pipeline |
| **Supervisor de línea** | Santi | Mira el panel, decide qué conexión avanza/pausa, promueve Skill vN, calibra proceso. **NO es el que ejecuta las skills** |
| **Operario de skills** | Agente Claude Code | Ejecuta estaciones cuando supervisor da orden; trabaja 24/7; idempotente |
| **Control de calidad técnico** | Pedro | HITL #1, #3, #4 + validator de Skill. **Decisiones técnicas siguen siendo suyas**, no se delegan al agente |
| **Control de calidad funcional** | Eva | HITL campos nuevos, mapeo hoteles, decisiones sobre extender contenedor canónico |
| **Codificador** | Pedro / AIDeveloper | Conector PerlaHub repo o adapter PerlaPush repo (Fase 6, fuera de la planta) |
| **Contacto externo** | Vanesa / Graeme / Noemí… | Doc + credenciales sandbox; entrega lote en Intake |
| **Operativa post** | Eva (mapeo) / Pedro (técnico) | Métricas, sorpresas, mantenimiento conexión live |

---

## 9. Skills (12 totales)

| Skill | Comando ejemplo | Hace |
|---|---|---|
| `factory-status` | `/factory-status [slug] [--filter ...]` | Lee DB, imprime tabla. Detalle si slug |
| `factory-new` | `/factory-new acme --type pull --contact "..." --volume "..." --doc-url ... --sandbox-curl ...` | **Valida 4 criterios Intake (Fase 0)** → si OK: INSERT connection (current_phase=1, status=active) + 4 hitl_gates + mkdir + commit. Si KO: INSERT con status='rejected_intake' + notas qué falta. |
| `factory-update` | `/factory-update acme --phase 2 \| --hitl-approve N \| --action deploy --env perlahub-dev` | UPDATE + INSERT log/action + regen REGISTRY + commit |
| `factory-checklist` | `/factory-checklist mark acme --row X --class Y \| diff \| finalize \| patterns <row>` | UPSERT en checklist_responses, regen MD, cross-learn |
| `factory-sandbox` | `/factory-sandbox validate acme` | Claude lanza 6 endpoints en paralelo via curl, captura, compara doc |
| `factory-mocktests` | `/factory-mocktests run acme [--env perlahub-dev]` | Ejecuta 7-10 casos estándar, captura outputs, registra `actions` |
| `factory-mismatches` | `/factory-mismatches classify acme` | Compara filas 🟡🔴 contra `catalog/known-mismatches-*.md`, separa conocidos/nuevos |
| `factory-surprise` | `/factory-surprise add \| resolve` | INSERT/UPDATE surprises |
| `factory-metric` | `/factory-metric acme --env perlahub-prod --date X --name booking_error_rate --value 2.3` | INSERT metrics |
| `factory-close` | `/factory-close acme` | DoD check + case_study + consolida catálogo + memoria brain |
| `factory-pull` | `/factory-pull acme` | (iter 2) Workflow orquestador Fases 1-5 Pull |
| `factory-push` | `/factory-push acme` | (iter 2) Análogo Push |

---

## 10. Fases con entorno explícito

### 10.0 Fase 0 — Intake (puerta de entrada · NO es precondición implícita)

**El proceso es agnóstico a quién solicita** (comercial interno, partner externo, prospecto). Lo que importa es si el lote cumple los 4 criterios. Sin los 4, **el lote no entra a la línea** y vuelve al solicitante.

**Criterios de aceptación de lote** (mínimo, los 4 obligatorios):

| # | Criterio | Forma de verificarlo |
|---|---|---|
| 1 | **Documentación técnica accesible** | Swagger / Postman collection / PDF / ejemplos request-response |
| 2 | **Credenciales sandbox válidas y probadas** | `curl` básico al endpoint de auth o salud responde |
| 3 | **Contacto técnico identificado y responsivo** | Nombre + email + último contacto < 7 días |
| 4 | **Volumen estimado declarado** | nº hoteles · clientes · hoteles/request · frecuencia |

**Outcomes posibles**:
- **Aceptado** → `connections.current_phase = 1`, arranca línea
- **Rechazado** → `connections.status = 'rejected_intake'` (nuevo valor permitido) + `notes` con qué falta; queda registrado para métrica "tiempo entre solicitud y arranque real"
- **Hold** → `status = 'awaiting_intake'` cuando faltan inputs pero hay compromiso de aportarlos (timeout configurable)

**Skill operadora**: `factory-intake` (o sub-comando de `factory-new`):

```
/factory-new acme --type pull --contact "Vanesa <v@avoris>" --volume "200 htls/2 clients/50 htls-req/diaria"
  ↳ valida 4 criterios
  ↳ si OK: INSERT connections (current_phase=1, status='active')
  ↳ si KO: INSERT connections (status='rejected_intake', notes='falta sandbox creds + doc accesible')
```

**Por qué Fase 0 importa** — sin esta puerta, la planta se atasca a mitad de línea por inputs que debieron exigirse antes de empezar. La métrica "tiempo entre solicitud y arranque real" es input directo de calidad comercial.

### 10.1 Pull (Fase 0 Intake + 8 estaciones + 4 HITL)

| Fase | Acción | Entornos | action_type |
|---|---|---|---|
| **0** | **Intake — 4 criterios lote** | — | `intake_validate` |
| 1 | Análisis doc + checklist 🟢🟡🔴 | (doc) | — |
| 2 | Sandbox validation | provider-sandbox **+ perlahub-dev** | `sandbox_validate` |
| 3 | Mock Tests 7 casos | provider-sandbox + perlahub-dev | `mock_test` |
| 4 | Clasificar mismatches | — | — |
| 5 | Informe final | — | — |
| 6 | Codificación PR → merge dev | PerlaHub repo + perlahub-dev | `deploy` |
| 7 | E2E desde PerlaHub DEV | **perlahub-dev** + provider-sandbox | `e2e_test` |
| 8 | Go-live PROD | **perlahub-prod** + provider-prod | `deploy` + `prod_smoke` |
| DoD | Métricas estables | perlahub-prod | `metric_collect` |

### 10.2 Push (Fase 0 Intake + 8 estaciones + 5 HITL)

Análogo sustituyendo `perlahub-*` → `perlapush-*`. HITL #1 extra al inicio: clasificar Modo A/B. Intake en Push exige además declarar si el channel hará webhook (Modo B típico) o consumirá nuestra API (Modo A), porque condiciona la documentación que ellos deben aportar.

### 10.3 Espejo (Fase 0 Intake + 5 estaciones + 1 HITL)

Intake adapta criterio 2: en vez de "sandbox válida" pide **logs reales del cliente conectado a TGX** (escenario A/B/C). Sin logs, el lote no entra.

### Schema impact — añadir a `connections.status` enum

```sql
-- Extender CHECK constraint si lo hay, o documentar valores válidos:
-- 'active' | 'dormant' | 'done' | 'dropped'
--   + 'rejected_intake'  ← lote no cumplió 4 criterios
--   + 'awaiting_intake'  ← inputs pendientes con compromiso
```

### Espejo (5 fases + 1 HITL)

| Fase | Acción | Entornos |
|---|---|---|
| 0 | Recopilar logs cliente | — |
| 1 | Validar auth supplier-side | perlahub-dev |
| 2 | Validar shape req/resp | perlahub-dev |
| 3 | Simulador HTTP comparativo | perlahub-dev |
| 4 | Lista mismatches → corregir | perlahub-dev |
| 5 | Go-live (cambio endpoint) | perlahub-prod |

---

## 11. Flujo end-to-end

Ver walkthrough completo en [`docs/example-pull-walkthrough.md`](docs/example-pull-walkthrough.md) — simula conexión #5 industrial en 2 días con AcmeBeds.

---

## 12. Los 4 activos que crecen (industrialización real)

**Sin estos 4 activos, factory es solo papeleo. Con ellos, cada conexión cuesta menos.**

### 12.1 Catálogo de mismatches conocidos

Vive en: `catalog/known-mismatches-pull.md` y `catalog/known-mismatches-push.md`
+ DB `checklist_responses` con histórico cross-conexión.

Crece con cada `factory-close`. Formato de entrada:

```markdown
### loyalty_id_passthrough
- Primera detección: Hotelbeds (#3)
- Resolución: capturar como `BookingMetadata.providerLoyaltyId`, no match a fidelidad PerlaHub
- Wrapper: ninguno (passthrough simple)
- Conexiones aplicadas: HB, Expedia, AcmeBeds (3)
- Probabilidad próximas: alta (~30% providers tienen loyalty)
```

### 12.2 Wrappers Core en PerlaHub/PerlaPush

Ubicación: `REPOS/perlahub/Core/Accommodation/Wrappers/` (similar en PerlaPush).

Catálogo en factory: `catalog/wrappers-pull.md` (manifiesto vivo).

Ejemplos a construir con primeras conexiones:
- `RateKeyBuffer.cs` — buffer 2min antes de book si TTL < 10min
- `TimezoneResolver.cs` — UTC + `Hotel.TimeZoneId` IANA
- `CoreCancelNotFound.cs` — normaliza 404 cancel
- `BackoffExpStrategy.cs` — 1-2-4-8s con retries configurables
- `CurrencyForcer.cs` — fuerza currency request si provider es multi-currency
- `PriceChangedTolerance.cs` — tolera <5% diff prebook→book

### 12.3 Templates de conector (scaffold 70-80%)

`factory/templates/pull/connector-skeleton/`:
- Estructura completa carpetas (AvailabilityApi/, ReservationApi/, etc.)
- Gateway HTTP boilerplate
- DTOs Core mapeo template
- Tests mínimos placeholder

Script `scripts/scaffold-connector.sh <slug>` clona al repo PerlaHub con sustitución de `{Provider}`.

### 12.4 Skill calibrada

`factory/.claude/skills/factory-pull/SKILL.md` se promueve con cada cierre que añade filas o heurísticas:
- Filas nuevas al catálogo de checklist
- Heurísticas mejoradas de clasificación
- Casos Mock Tests nuevos
- Decisiones P7+ si surgen

Histórico en `docs/pull-skill-YYYY-MM-DD.md`.

---

## 13. Cross-conexión patterns (aprendizaje automático)

Cada vez que la skill `factory-pull` clasifica una fila del checklist en una **nueva** conexión:

```sql
SELECT classification, COUNT(*), array_agg(c.slug ORDER BY c.created_at DESC)
FROM checklist_responses cr
JOIN connections c ON cr.connection_id = c.id
WHERE cr.row_key = 'rate_key_ttl'
  AND c.status IN ('done','active')
GROUP BY classification;
```

Output al humano cuando hay precedente:

```
Fila `rate_key_ttl` en AcmeBeds (nueva):
  Histórico cross-conexión:
    🔴 en 3/5 previas (HB, Dome, Expedia)
    🟡 en 2/5 previas (Roibos, Avoris)
  Wrapper aplicable: RateKeyBuffer (existente)
  Probable clasificación: 🟡-🔴 (alta confianza)
```

**Niveles de confianza** para auto-clasificar:
- ≥3 conexiones previas con mismo patrón → **auto** (alta confianza)
- 1-2 previas → **tentativa** (humano revisa)
- 0 previas → **flagged** (genuinamente nueva, HITL #3 obligatorio)

→ El % de filas auto-clasificadas crece con cada conexión. Sin compromiso de porcentajes concretos: la magnitud emerge con los datos reales.

---

## 13bis. Idempotencia y rebobinado (la propiedad que justifica la planta)

El plan ya tiene los ingredientes (estado en Postgres, artefactos en `pilots/<slug>/`, código real no se toca hasta Fase 6) pero hay que **nombrar la propiedad** explícitamente — porque es lo que justifica que esto sea una planta autónoma y no "solo skills con UI".

**Reglas de la propiedad**:

1. **Cada estación es determinista** — mismo input produce mismo output (la skill operadora hace queries SQL y llamadas HTTP idempotentes; nada de estado oculto).
2. **El estado vive en Postgres, no en memoria del agente** — si la sesión Claude muere a mitad de estación 3, otra sesión retoma desde la última fila escrita en `phase_log`/`actions`/`checklist_responses`.
3. **Artefactos en `pilots/<slug>/evidence/`** — versionados en git; los outputs de cada estación quedan congelados para auditoría posterior y para alimentar el rebobinado.
4. **Hasta Fase 6 (Codificación) la línea NO toca el código real** — todo lo que ocurre en Fases 0-5 (intake, análisis, sandbox, mocks, mismatches, informe) es papel + DB. Rebobinar de Fase 5 a Fase 2 es barato.
5. **"Coche con tres ruedas"** — si en Fase 5 (informe) descubrimos un mismatch que debió clasificarse en Fase 4, hacemos:
   ```sql
   DELETE FROM checklist_responses
   WHERE connection_id = X AND section IN ('D','E');
   UPDATE connections SET current_phase = 4 WHERE id = X;
   INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
   VALUES (X, 5, 4, 'Santi', 'Rebobinado: missing rate_breakdown row');
   ```
   Las filas de fases anteriores (sandbox validation, mocks) **se conservan** — lo aprendido no se pierde.
6. **Tras Fase 6**, rebobinar implica además **revertir PR de PerlaHub** — más caro pero documentado: skill `factory-rollback` registra `actions(action_type='rollback', target_env='perlahub-dev/prod')` + actualiza `dev_status='rolled_back'`. La línea sabe que hay que repetir Fase 6 con commit fresco.

**Una planta humana no rebobina; una de agentes sí.** Sin esta propiedad, no hay industrialización — sería solo automatización de pasos sueltos. Con ella, el coste marginal de rectificar es bajo y eso permite experimentar más en cada conexión.

---

## 14. Panel de control de la planta (NO es BI)

El dashboard **no es accesorio**. Si por cualquier razón hay que recortar alcance, esto **NO se recorta**. Sin panel, el estado de la planta solo es legible para quien sepa abrir el repo y leer SQL — la planta deja de ser visible para el equipo y deja de funcionar como planta.

**Rol real**: panel operativo de la planta. El equipo abre la URL y ve:
- Dónde está cada conexión (qué estación)
- Qué HITL está bloqueando y a quién espera
- Qué estación está esperando input (sandbox provider caído, doc incompleto…)
- Dónde hay sorpresas sin resolver
- Qué tendencias hay cross-conexión

**No es BI** (no es análisis ex post de KPIs comerciales). Es vista en vivo del piso de planta — análogo a la pantalla de turno en una fábrica real.

### Nivel 1 · GitHub `REGISTRY.md` (siempre, cero infra)

Renderizado en GitHub. Pedro/Eva/Francesc consultan sin Claude Code. Tabla con: slug, factory, fase actual, último HITL, owner, env DEV/PROD, gap, última acción.

Es el panel "de pasillo" — para quien no tiene tiempo de abrir Streamlit.

### Nivel 2 · Streamlit local — panel operativo (`factory/dashboard/`)

Patrón confirmado en docs Streamlit oficiales:

```python
# dashboard/app.py
import streamlit as st
import pandas as pd

# st.connection cache la conexión (cache_resource bajo el capó)
conn = st.connection("factory", type="sql")

# Queries cacheadas 10 min
df_connections = conn.query("SELECT * FROM connections ORDER BY updated_at DESC", ttl="10m")

# Página principal
st.title("Factory · Conexiones")
st.dataframe(df_connections)
```

`dashboard/.streamlit/secrets.toml.example`:

```toml
[connections.factory]
dialect = "postgresql"
host = "localhost"
port = 5433
database = "factory"
username = "factory"
password = "factory_local"
```

(`secrets.toml` real es git-ignored)

**4 pantallas** (orden de prioridad operativa):

1. **Piso de planta** (vista principal): kanban por estación con cada conexión como tarjeta. Filtros: factory, modo, owner, gap DEV/PROD. **Banner rojo arriba**: HITLs pendientes con tiempo de espera. Indicador visual: estación esperando input externo (provider sandbox caído, contacto sin respuesta).
2. **Por conexión** (drill-down): timeline + actions + checklist drill-down + sorpresas + métricas + decisión "qué le falta a este coche para avanzar".
3. **Aprendizaje cross-conexión**: Anexo D consolidado + P/D decisions + filas con mayor tasa 🔴 cross-conexión + wrappers más reutilizados. **Esta pantalla es la que más crece con N**.
4. **Métricas**: error rates vs targets + tiempo calendario por fase (heatmap) — usar SOLO con datos reales (≥5 conexiones cerradas); antes está vacía y eso está bien.

Lanzamiento: `cd dashboard && streamlit run app.py` → http://localhost:8501

**Compromiso**: el panel forma parte del v0 mínimo. No es Fase 4 ni "siguiente sesión". Sin panel, no hay v0.

---

## 15. Curva de aprendizaje (cualitativa)

Esperamos curva decreciente: cada conexión cuesta menos que la anterior porque los 4 activos (catálogo + wrappers + templates + skill calibrada) absorben trabajo. **La magnitud y velocidad de la curva se determina con datos reales tras los primeros cierres** — no comprometemos cifras antes de tener evidencia.

**KPI cualitativo Factory funciona**: `esfuerzo conexión N+1 < esfuerzo conexión N` durante las primeras ~10 conexiones. Si no se observa, la planta no está funcionando y revisamos.

**Cuellos duros irreducibles** (orden cualitativo, sin números):
- Tráfico estable post go-live (umbral DoD, ver §0.1 pendiente Pedro)
- Pedro disponibilidad async (mitigable con bloque agendado misma jornada)
- Ventana deploy PROD según política Perlatours

**Categorías de situaciones que requieren tiempo extra** (sin estimación numérica — depende de cada caso):
- Sandbox provider falla / no responde
- Mismatch nuevo gordo arquitectónico
- Provider pide extender contenedor canónico
- Smoke PROD falla → rollback + debug
- Score alto de complejidad genuina
- Auth exótica (SOAP+WS-Security, mTLS custom)

El tracking de cuál de estas categorías aparece en cada conexión real va a `surprises` + métricas, y poblará la curva con datos reales.

---

## 16. Plan de implementación (orden, sin estimaciones temporales)

El orden importa más que los tiempos. Cada paso se da cuando el anterior está verificado.

### Paso A — Infra Docker + Postgres
- [ ] Crear `docker-compose.yml` (postgres:17-alpine + healthcheck `pg_isready`)
- [ ] `db/schema.sql` con 7 tablas
- [ ] `scripts/init-db.sh` (docker compose up + verifica)
- [ ] `docker compose up -d` + verificar `psql -h localhost -p 5433 -U factory -d factory -c '\dt'`

### Paso B — Esqueleto repo
- [ ] `.gitignore` (incluye `*.local.*`, `.streamlit/secrets.toml`)
- [ ] `config/environments.yml`
- [ ] `scripts/`: `dump-registry.sh`, `dump-state.sh`, `dump-pilot.sh`
- [ ] `templates/{pull,push,espejo}/pilot-skeleton/` con archivos MD plantilla
- [ ] `catalog/` con `decisions-p1-p6.md`, `decisions-d1-d6.md`, `known-mismatches-*.md` vacíos v0, `wrappers-pull.md` vacío

### Paso C — Seed checklist + candidatos
- [ ] `db/seed-checklist-rows.sh` parsea `docs/factory_pull_checklist.md` y `docs/factory_push_checklist.md` → INSERT catálogo de filas estándar (sin connection_id, son template)
- [ ] `db/seed.sql` con los 9 candidatos reales:
  - Avoris Pull, SiteMinder Push, GNA Push, Hotelbeds Pull, Welcomebeds Espejo,
    Destinia Espejo, CNBooking Push directa, Expedia Pull, Top Dog Pushout
- [ ] Para cada uno: INSERT connection + hitl_gates pendientes según fase actual estimada
- [ ] `./scripts/dump-registry.sh` → primer `REGISTRY.md`

### Paso D — Skills v0 CRUD (mínimo Pull operable)
- [ ] `factory-status/SKILL.md`
- [ ] `factory-new/SKILL.md` (incluye validación 4 criterios Intake Fase 0 + pilots/ + copia template + INSERT)
- [ ] `factory-update/SKILL.md` (fase, HITL, action --env/--outcome/--evidence)
- [ ] `factory-checklist/SKILL.md` (mark, finalize, diff, patterns)
- [ ] `factory-surprise/SKILL.md`
- [ ] `factory-metric/SKILL.md`
- [ ] Test E2E: cambiar Avoris fase 1 → 2 + mark 5 filas checklist

### Paso E — Panel de control Streamlit (NO opcional, NO posponible)
- [ ] `dashboard/requirements.txt` (streamlit, psycopg2-binary, pandas, plotly)
- [ ] `dashboard/app.py` con 4 pantallas (piso de planta primero)
- [ ] `.streamlit/secrets.toml.example`
- [ ] Test: `streamlit run dashboard/app.py` → 4 pantallas funcionales, banner HITLs visible

### Paso F — Skills operativas Pull
- [ ] `factory-sandbox/SKILL.md` (curl paralelo 6 endpoints, captura, compara doc)
- [ ] `factory-mocktests/SKILL.md` (7 casos Pull)
- [ ] `factory-mismatches/SKILL.md` (classify contra catálogo)
- [ ] `factory-pull/SKILL.md` orquesta Fases 1-5
- [ ] `factory-close/SKILL.md` (DoD + case_study + consolida)
- [ ] Piloto real: correr `factory-pull avoris` Fase 1 (con catálogo vacío v0)

### Paso G — Commit inicial + push
- [ ] Verificar `.gitignore` cubre todo lo sensible
- [ ] Commit "factory v0 bootstrap"
- [ ] Push `Perlatours/factory`

### Paso H — Push (cuando Pull esté estable, NO en v0)
- [ ] `factory-push/SKILL.md` análogo (170 filas checklist Push activadas)
- [ ] Piloto SiteMinder

**No prometemos un tiempo total**. El tiempo será lo que tarde, y será dato real para la curva.

---

## 17. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Postgres local solo en Mac → pérdida | `dump-state.sh` periódico → `db/snapshots/` commiteado |
| Docker container down = skills fallan | Skills detectan `docker ps` + guían recuperación |
| Drift `REGISTRY.md` vs DB | Skills regeneran tras cada UPDATE |
| Credenciales provider expuestas | `.local.env` git-ignored + pre-commit hook scan |
| Gap DEV/PROD invisible | Estado `gap_prod` visible REGISTRY + filtro Streamlit |
| Bundle deploy multi-conexión | `actions.notes` referencia bundle |
| Rollback PROD | `actions(action_type='rollback')` + `prod_status='rolled_back'` |
| Streamlit cache stale | TTL 10min + botón "Refresh" en dashboard |
| Allowed-tools no enforced (bug Claude Code) | Documenta intent, no esperar restricción real |

---

## 18. Cross-ref brain

| Pieza | Memoria brain |
|---|---|
| Factory padre v2 | `factory_conexiones.md` |
| Pull briefing/checklist/validaciones | `factory_pull/*.md` |
| Push briefing/checklist/validaciones | `factory_push/*.md` |
| Avoris piloto Pull | `project_avoris_nativa.md` |
| GNA Push | `project_gna_pushin.md` |
| Hotelbeds cert | `project_hotelbeds_certificacion.md` |
| Welcomebeds Espejo | `project_welcomebeds_espejo_tgx.md` |
| Destinia Espejo | `project_destinia_espejo_tgx.md` |
| CNBooking | `project_cnbooking_directa.md` + skill `cnbooking-direct` |
| Expedia | `project_expedia_handoff_eva.md` |
| TopDog Pushout | `project_topdog.md` |
| DEV/PROD gap pattern | `project_perlapush_prod_deploy_pendiente.md` |
| Bundle deploy pattern | `project_perlahub_deploy_bundle_abr16.md` |
| Huawei DAS (métricas SQL) | `reference_huawei_das_sql.md` |

---

## 19. Lo que NO es factory (alcance explícito)

- **NO codifica conectores**: PRs viven en PerlaHub/PerlaPush repos
- **NO orquesta CI/CD**: solo registra commit hash y outcome tras humano confirmar
- **NO sustituye Jira**: complementa, referencia `jira_epic_url` opcional
- **NO es front Perlatours**: Eva sigue configurando `PurchaseContract` en Frontend v2 contracts
- **NO decide qué proveedor conectar**: eso es comercial
- **NO sustituye reunión humana**: HITLs siguen siendo decisión Pedro/Eva/Santi

---

## 20. Apéndice A · `docker-compose.yml` referencia

```yaml
services:
  factory-db:
    image: postgres:17-alpine
    container_name: factory-db
    environment:
      POSTGRES_DB: factory
      POSTGRES_USER: factory
      POSTGRES_PASSWORD: factory_local
    ports:
      - "5433:5432"                              # 5433 host → 5432 container
    volumes:
      - factory-db-data:/var/lib/postgresql/data
      - ./db/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
      - ./db/seed.sql:/docker-entrypoint-initdb.d/02-seed.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U factory -d factory"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped

volumes:
  factory-db-data:
```

Notas:
- Puerto 5433 host (5432 container) evita choque con Postgres nativo si existe
- `start_period: 30s` da margen al primer arranque que ejecuta init scripts
- `restart: unless-stopped` reaparece tras reboot Mac
- Init scripts solo se ejecutan en primer `up` (al crear volumen). Para re-aplicar: `docker compose down -v && docker compose up -d`

---

## 21. Apéndice B · SKILL.md frontmatter spec

Basado en investigación Claude Code docs oficial + Anthropic spec (mayo 2026):

```yaml
---
name: factory-update                            # obligatorio · slug skill
description: |                                  # obligatorio · qué hace + cuándo invocar
  Actualiza el estado de una conexión factory: transiciones de fase,
  aprobación de HITLs, registro de acciones con entorno (DEV/PROD/sandbox),
  links a PRs. Invocar cuando Santi diga "actualiza X", "marca HITL N de X",
  "registra deploy de X en env Y", "X pasa a fase N".
version: "0"                                    # opcional
allowed-tools: [Bash, Read, Edit, Write]        # opcional · documenta intent (NO enforced en 2026)
disable-model-invocation: false                 # opcional · default false
---

# Factory Update

Cuerpo del SKILL.md en markdown libre. Patrones:
- Sintaxis de los comandos (--phase, --hitl-approve, --action, --env, ...)
- Queries SQL que ejecuta (mostrar con bloques ```sql)
- Comandos Bash que invoca (psql, dump-registry.sh, git)
- Cuándo regenerar REGISTRY.md y commit
- Casos edge (qué si la conexión no existe, qué si HITL ya aprobado)
```

**Limitaciones conocidas (2026)**:
- `allowed-tools` parseado pero NO enforced: Claude tiene acceso a todas las tools aunque diga lo contrario en el frontmatter. Documenta intent, no esperar enforcement real.
- Solo aplica en Claude Code CLI, no en SDK.

---

## 22. Histórico

- **v0 (2026-05-15)**: diseño inicial, decisiones pendientes
- **v2 (2026-05-15)**: integra Docker, `checklist_responses`, dashboard Streamlit, 4 activos, curva aprendizaje, target 2 días. Investigación Claude Code skills + Postgres Docker + Streamlit incorporada
- **v2.1 (2026-05-18)** — reframing planta + 9 ajustes Santi:
  1. TL;DR reescrito con metáfora "planta autónoma de fabricación de conexiones" (cada conexión = un coche)
  2. Fase 0 Intake elevada a gate explícito con 4 criterios y status `rejected_intake`/`awaiting_intake`
  3. §14 Dashboard reescrita como "panel de control de la planta" (NO BI, NO recortable)
  4. §13bis nueva: propiedad idempotencia/rebobinado explícita con ejemplo SQL DELETE+phase_log
  5. Estimaciones temporales retiradas (TL;DR target, decisión #11 target, §15 tabla curva, §16 tiempos por fase, §15 "+1-3d" en situaciones extra). Se mantienen thresholds (score 0-3, booking err <4%, niveles confianza, N días DoD).
  6. Nueva §0 "Decisiones críticas pendientes de Pedro" con 3 preguntas binarias (N días DoD, L1 cache TTL bug, InsertRateCodeMapping endpoint real)
  7. §8 Roles separados: Supervisor (Santi, NO operario) vs Operario (agente) vs QA técnico (Pedro) vs QA funcional (Eva) vs Director (Francesc)
  8. Alcance v0 explícito: Pull only en operación; Push presente en schema/seed para no rehacer estructura, pero NO operativa en v0
  9. SVG diagrama de planta añadido (`factory_pull/factory-pull-plant-diagram.svg`), referenciado desde TL;DR
- Próximo: tras Pedro responde §0 (3 decisiones) + Paso A bootstrap

Sources investigación v2:
- [Claude Code Skills docs (anthropic)](https://code.claude.com/docs/en/skills)
- [Postgres Docker healthcheck patterns](https://dev.to/saiful7778/setting-up-postgresql-with-docker-compose-for-development-and-production-45j8)
- [Streamlit st.connection PostgreSQL](https://docs.streamlit.io/develop/tutorials/databases/postgresql)
