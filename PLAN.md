---
title: Factory · Plan de Industrialización v2
date: 2026-05-15
author: Santiago Patino Serna
status: pendiente-aprobacion-arranque
owner: Santi
validator: Pedro
parent_brain: brain_sps_perlatours/knowledge/perlatours/arquitectura/factory_conexiones.md
history:
  - v0 (2026-05-15): diseño inicial
  - v2 (2026-05-15): integra Docker, checklist_responses, dashboard Streamlit, 4 activos, curva aprendizaje, target 2 días
---

# Factory · Plan de Industrialización v2

## TL;DR

`factory/` orquesta el ciclo de vida de cada conexión nueva (Pull · Push · Espejo · PushOut). **No codifica conectores** — eso vive en repos PerlaHub y PerlaPush. Sí: registra estado, audit, HITL, métricas, **catálogo de aprendizaje cross-conexión**, casos de éxito.

- **SoT vivo**: Postgres 17 en Docker Compose local (7 tablas)
- **SoT auditable**: `REGISTRY.md` autogenerado + git commits + push `Perlatours/factory`
- **Vista interactiva**: Streamlit dashboard local (`factory/dashboard/`)
- **Operación**: ~12 skills Claude Code en `factory/.claude/skills/`
- **Entornos**: DEV/PROD explícitos por conexión

**Target operativo a partir de conexión #5** (industrial estable):
- 2 días calendario · ~2h Santi efectivos · 0-1 mismatch genuinamente nuevo · 24h tráfico estable

**Conexión #1 (Avoris) es inversión** que construye los 4 activos (catálogo + wrappers + templates + skill calibrada). 5-7 días, ~6-8h Santi.

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
| 11 | Target operativo | 2 días calendario para #5+ (industrial), 5-7 días para #1 (calibración) |

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

| Rol | Persona | Responsabilidad |
|---|---|---|
| Factory Owner | Santi | Opera skills, promueve versiones, calibra proceso |
| HITL técnico | Pedro | Aprueba informe, modo A/B, mismatches, go-live |
| HITL funcional | Eva | Aprueba campos nuevos, mapeo hoteles |
| Codificador | Pedro / Santi / AIDeveloper | Conector PerlaHub repo o adapter PerlaPush repo |
| Contacto externo | Vanesa / Graeme / Noemí… | Doc + credenciales sandbox |
| Operativa post | Eva (mapeo) / Pedro (técnico) | Métricas, sorpresas |

---

## 9. Skills (12 totales)

| Skill | Comando ejemplo | Hace |
|---|---|---|
| `factory-status` | `/factory-status [slug] [--filter ...]` | Lee DB, imprime tabla. Detalle si slug |
| `factory-new` | `/factory-new acme --type pull --contact "..."` | INSERT connection + 4 hitl_gates + mkdir + commit |
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

### Pull (8 fases + 4 HITL)

| Fase | Acción | Entornos | action_type |
|---|---|---|---|
| 0 | Inputs (doc, creds sandbox) | provider-sandbox | — |
| 1 | Análisis doc + checklist 🟢🟡🔴 | (doc) | — |
| 2 | Sandbox validation | provider-sandbox **+ perlahub-dev** | `sandbox_validate` |
| 3 | Mock Tests 7 casos | provider-sandbox + perlahub-dev | `mock_test` |
| 4 | Clasificar mismatches | — | — |
| 5 | Informe final | — | — |
| 6 | Codificación PR → merge dev | PerlaHub repo + perlahub-dev | `deploy` |
| 7 | E2E desde PerlaHub DEV | **perlahub-dev** + provider-sandbox | `e2e_test` |
| 8 | Go-live PROD | **perlahub-prod** + provider-prod | `deploy` + `prod_smoke` |
| DoD | Métricas estables | perlahub-prod | `metric_collect` |

### Push (8 fases + 5 HITL)

Análogo sustituyendo `perlahub-*` → `perlapush-*`. HITL #1 extra al inicio: clasificar Modo A/B.

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

→ El % de filas auto-clasificadas crece con cada conexión: #1 = 0%, #6 = 92%, #20 = 99%.

---

## 14. Dashboard (2 niveles)

### Nivel 1: GitHub web (siempre, cero infra)

`REGISTRY.md` renderizado en GitHub. Pedro/Eva/Francesc consultan sin Claude Code.

### Nivel 2: Streamlit local (`factory/dashboard/`)

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

**4 pantallas**:
1. **Vista general**: kanban por fase + filtros (factory, modo, owner, gap DEV/PROD)
2. **Por conexión**: timeline + actions + checklist drill-down + sorpresas + métricas
3. **Métricas**: error rates vs targets + tiempo calendario por fase (heatmap)
4. **Aprendizaje**: Anexo D consolidado + P/D decisions + top filas problemáticas cross-conexión

Lanzamiento: `cd dashboard && streamlit run app.py` → http://localhost:8501

---

## 15. Curva de aprendizaje + target operativo

| Conexión | Días | Horas Santi | Catálogo | Mismatches nuevos | Líneas código |
|---|---|---|---|---|---|
| **#1 Avoris** (calibra) | 5-7 | ~6-8h | 0 entradas | 4 | ~800 |
| **#2** (1ª iteración) | 3 | ~3-4h | 5-10 | 2-3 | ~200 |
| **#3-4** (afinando) | 2-3 | ~2h | 15-25 | 1-2 | ~80 |
| **#5+** (industrial) | **2** | **~2h** | 30+ | 0-1 | ~30 |
| **#20** (estable) | 1-2 | ~1.5h | 80+ | 0 | ~10 |

**KPI Factory funciona**: `horas Santi conexión N+1 < horas Santi conexión N` durante #2-#10.

**Cuello duro irreducible** (incluso #20):
- 24h tráfico estable post go-live (factory madura) / 7d (factory naciente)
- Pedro disponibilidad async (mitigable con bloque agendado misma jornada)
- Ventana deploy PROD según política Perlatours

**Situaciones que justifican días extra**:
- Sandbox provider falla / no responde → +1-3d
- Mismatch nuevo gordo arquitectónico → +1d
- Provider pide extender contenedor canónico → +1-7d
- Smoke PROD falla → rollback + debug → +1-2d
- Score ≥12 alta complejidad genuina → +1-3d
- Auth exótica (SOAP+WS-Security, mTLS custom) → +1-2d

---

## 16. Plan de implementación (6 fases · ~2 sesiones)

### Fase 0 — Infra Docker + Postgres (20 min)
- [ ] Crear `docker-compose.yml` (postgres:17-alpine + healthcheck `pg_isready`)
- [ ] `db/schema.sql` con 7 tablas
- [ ] `scripts/init-db.sh` (docker compose up + verifica)
- [ ] `docker compose up -d` + verificar `psql -h localhost -p 5433 -U factory -d factory -c '\dt'`

### Fase 1 — Esqueleto repo (30 min)
- [ ] `.gitignore` (incluye `*.local.*`, `.streamlit/secrets.toml`)
- [ ] `config/environments.yml`
- [ ] `scripts/`: `dump-registry.sh`, `dump-state.sh`, `dump-pilot.sh`
- [ ] `templates/{pull,push,espejo}/pilot-skeleton/` con archivos MD plantilla
- [ ] `catalog/` con `decisions-p1-p6.md`, `decisions-d1-d6.md`, `known-mismatches-*.md` vacíos v0, `wrappers-pull.md` vacío

### Fase 2 — Seed checklist + 9 candidatos (30 min)
- [ ] `db/seed-checklist-rows.sh` parsea `docs/factory_pull_checklist.md` y `docs/factory_push_checklist.md` → INSERT catálogo de filas estándar (sin connection_id, son template)
- [ ] `db/seed.sql` con los 9 candidatos reales:
  - Avoris Pull, SiteMinder Push, GNA Push, Hotelbeds Pull, Welcomebeds Espejo,
    Destinia Espejo, CNBooking Push directa, Expedia Pull, Top Dog Pushout
- [ ] Para cada uno: INSERT connection + hitl_gates pendientes según fase actual estimada
- [ ] `./scripts/dump-registry.sh` → primer `REGISTRY.md`

### Fase 3 — Skills v0 CRUD (1-2h)
- [ ] `factory-status/SKILL.md`
- [ ] `factory-new/SKILL.md` (con creación pilots/ + copia template + INSERT)
- [ ] `factory-update/SKILL.md` (fase, HITL, action --env/--outcome/--evidence)
- [ ] `factory-checklist/SKILL.md` (mark, finalize, diff, patterns)
- [ ] `factory-surprise/SKILL.md`
- [ ] `factory-metric/SKILL.md`
- [ ] Test E2E: cambiar Avoris fase 1 → 2 + mark 5 filas checklist

### Fase 3.5 — Dashboard Streamlit (1h)
- [ ] `dashboard/requirements.txt` (streamlit, psycopg2-binary, pandas, plotly)
- [ ] `dashboard/app.py` con 4 pantallas
- [ ] `.streamlit/secrets.toml.example`
- [ ] Test: `streamlit run dashboard/app.py` → 4 pantallas funcionales

### Fase 4 — Skills operativas (iter 2, 2-3h, próxima sesión)
- [ ] `factory-sandbox/SKILL.md` (curl paralelo 6 endpoints, captura, compara doc)
- [ ] `factory-mocktests/SKILL.md` (7 casos Pull / 10 casos Push)
- [ ] `factory-mismatches/SKILL.md` (classify contra catálogo)
- [ ] `factory-pull/SKILL.md` orquesta Fases 1-5
- [ ] `factory-push/SKILL.md` análogo
- [ ] `factory-close/SKILL.md` (DoD + case_study + consolida)
- [ ] Piloto real: correr `factory-pull avoris` Fase 1 (con catálogo vacío v0)

### Fase 5 — Commit inicial + push (15 min)
- [ ] Verificar `.gitignore` cubre todo lo sensible
- [ ] Commit "factory v0 bootstrap"
- [ ] Push `Perlatours/factory`

**Total estimado**: ~5-7h de trabajo Santi+Claude para Fases 0-3.5. Fase 4 es siguiente sesión.

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
- Próximo: tras Fase 5 + primer ciclo Avoris

Sources investigación v2:
- [Claude Code Skills docs (anthropic)](https://code.claude.com/docs/en/skills)
- [Postgres Docker healthcheck patterns](https://dev.to/saiful7778/setting-up-postgresql-with-docker-compose-for-development-and-production-45j8)
- [Streamlit st.connection PostgreSQL](https://docs.streamlit.io/develop/tutorials/databases/postgresql)
