# Factory · Planta autónoma de fabricación de conexiones

**Cada conexión = un coche. La línea es idempotente y rebobinable.**
**No codifica conectores** — eso se mergea en PerlaHub/PerlaPush (Fase 6).
**v0 alcance**: Pull only en operación; Push presente en schema/seed para no rehacer.

## Quickstart

```bash
# 1. Levantar Postgres
bash scripts/init-db.sh

# 2. Seed (template checklist + 9 candidatos reales)
docker exec -i factory-db psql -U factory -d factory < db/seed-checklist-template-pull.sql
docker exec -i factory-db psql -U factory -d factory < db/seed-candidates.sql

# 3. Primer REGISTRY.md
bash scripts/dump-registry.sh

# 4. Panel control
cd dashboard && python3 -m venv .venv && source .venv/bin/activate \
  && pip install -r requirements.txt \
  && streamlit run app.py
# → http://localhost:8501
```

## Skills disponibles (11)

| Skill | Para qué |
|---|---|
| `factory-status` | Ver estado de la planta |
| `factory-new` | Crear conexión (con Fase 0 Intake gate) |
| `factory-update` | Avance/rebobinado fase, HITLs, acciones |
| `factory-checklist` | Marcar filas 🟢🟡🔴 + cross-conexión patterns |
| `factory-surprise` | Registrar/resolver sorpresas |
| `factory-metric` | Métricas por env + fecha |
| `factory-sandbox` | Validar sandbox provider (Fase 2 Pull) |
| `factory-mocktests` | 7 casos estándar (Fase 3 Pull) |
| `factory-mismatches` | Clasificar contra catálogo (Fase 4) |
| `factory-pull` | Supervisor F1-5 (orquestador) |
| `factory-close` | Cierre + consolida catálogo + case_study |

## Estructura

```
factory/
├── PLAN.md                          # plan v2.1 (planta autónoma)
├── REGISTRY.md                      # auto-generado por scripts/dump-registry.sh
├── docker-compose.yml               # postgres:17-alpine, puerto 5433
├── db/                              # schema + seeds + snapshots
├── config/                          # environments.yml (DEV/PROD por env)
├── scripts/                         # dump-{registry,state,pilot}.sh, init-db.sh
├── dashboard/                       # Streamlit panel control (4 pantallas)
├── pilots/<slug>/                   # conexiones activas
├── case_studies/<slug>/             # conexiones cerradas
├── templates/{pull,push,espejo}/    # esqueletos por factory
├── catalog/                         # decisiones P/D, mismatches, wrappers
├── docs/                            # docs congelados desde brain v0.1
└── .claude/skills/                  # 11 skills Claude Code
```

## Documentación

- [`PLAN.md`](./PLAN.md) — Plan v2.1 completo (decisiones críticas, fases, idempotencia)
- [`docs/factory_pull/factory-pull-plant-diagram.svg`](./docs/factory_pull/factory-pull-plant-diagram.svg) — diagrama planta
- [`docs/factory_pull/factory_pull_briefing_v0.md`](./docs/factory_pull/factory_pull_briefing_v0.md) — proceso día a día
- [`docs/factory_pull/factory_pull_checklist.md`](./docs/factory_pull/factory_pull_checklist.md) — checklist técnica

## Roles

- **Director planta**: Francesc
- **Supervisor línea**: Santi (NO operario)
- **Operario**: agente Claude Code
- **QA técnico**: Pedro (HITL #1, #3, #4)
- **QA funcional**: Eva (HITL campos nuevos, mapeo)
