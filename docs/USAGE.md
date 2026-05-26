# Factory · Cómo se usa (guía para desarrolladores)

> **Lo que tienes que entender en 30 segundos**:
>
> 1. **Tú nunca escribes en la DB a mano**. Usas skills de Claude Code (`/factory-new`, `/factory-update`, etc.).
> 2. La skill ejecuta SQL contra Postgres + escribe archivos en `pilots/<slug>/`.
> 3. **El panel Streamlit es solo lectura** — muestra lo que está en la DB. Refresh y ves el cambio.
> 4. **El front no opera nada** — es para mirar. Operar = skills en terminal/Claude Code.

---

## 1. Arquitectura — cómo se conectan las piezas

```
┌─────────────────────────────────────────────────────────────────┐
│                        TÚ (Santi / dev)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
       ┌───────────────┴──────────────────┐
       │                                   │
       ▼                                   ▼
┌──────────────┐                ┌─────────────────────┐
│ Claude Code  │                │  Browser            │
│ (terminal)   │                │  localhost:8501     │
│              │                │                     │
│ /factory-*   │                │  (Streamlit panel)  │
│ skills       │                │   ← solo LECTURA    │
└──────┬───────┘                └──────────┬──────────┘
       │                                   │
       │ Bash → psql                       │ st.connection
       │ (escribe)                         │ (lee)
       ▼                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Postgres 17 (Docker)                            │
│                  localhost:5433 · db=factory                     │
│                                                                  │
│  7 tablas: connections · phase_log · hitl_gates · actions        │
│           checklist_responses · surprises · metrics              │
└─────────────────────────────────────────────────────────────────┘
                       │
                       │ scripts/dump-*.sh
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Archivos en disco (git tracked)                                 │
│  - REGISTRY.md (tabla resumen, regen tras cada cambio)           │
│  - pilots/<slug>/STATE.md (drill-down por conexión)              │
│  - pilots/<slug>/{inputs,evidence,outputs}/                      │
│  - case_studies/<slug>/ (al cerrar)                              │
└─────────────────────────────────────────────────────────────────┘
```

**Regla mental**: la DB es la fuente de verdad viva. Los archivos `.md` son volcados auto-generados. Si editas un `.md` a mano, el siguiente `dump-*.sh` lo sobrescribe.

---

## 2. El panel Streamlit — qué muestra cada pantalla

Abrir: `cd dashboard && source .venv/bin/activate && streamlit run app.py` → http://localhost:8501

### Header (siempre visible)

```
🏭 Factory · Panel de control                            [ ↻ Refresh ]
Planta autónoma de fabricación de conexiones · snapshot: YYYY-MM-DD HH:MM UTC
```

Botón `↻ Refresh` limpia cache (TTL default: 60s). El panel cachea queries para no martillear la DB.

### Banner HITLs (siempre arriba, antes de las tabs)

Tres estados posibles:

```
✅ Sin HITL gates pendientes
```
→ Nada que hacer. Ningún coche bloqueado esperando revisión humana.

```
🟡 12 HITL gates pendientes (0 >2 días esperando)              [ Ver pendientes ▾ ]
```
→ Hay HITLs sin aprobar pero ninguno crítico todavía.

```
🔴 12 HITL gates pendientes (3 >2 días esperando)              [ Ver pendientes ▾ ]
```
→ Coches bloqueados >2 días. **Acción**: ir a la conexión, ver qué falta, dar al HITL.

Al expandir muestra tabla:

| slug | factory | gate_number | gate_title | owner | days_waiting |
|---|---|---|---|---|---|
| avoris-pull | pull | 1 | Informe final (Fase 5) | Pedro | 3.2 |

---

### Tab 1 — 🏭 Piso de planta (vista principal)

**Para qué sirve**: ver el estado global de un vistazo. ¿Dónde está cada coche?

```
Filtros: [Factory: pull ▾] [Status: active + awaiting_intake ▾] [☐ Solo gap DEV/PROD]
```

Por defecto: Pull only + active+awaiting (alcance v0).

Debajo: **kanban por fase**. Columnas = fase actual (0, 1, 2, ..., 8). Cada conexión es una tarjeta:

```
### Fase 1
─────────────────
🟢 avoris-pull
Avoris (Polaris) — Pull nativo
Modo: — · HITL: #1,#2,#3,#4
Owner: Pedro
─────────────────
🟡 welcomebeds-espejo
Welcomebeds — Espejo TGX
Modo: — · HITL: —
Owner: Pedro
```

Iconos status:
- 🟢 active — el coche está siendo trabajado
- 🟡 awaiting_intake — falta input externo (doc, sandbox, contacto)
- 💤 dormant — pausado / fuera de v0
- ✅ done — cerrado
- 🚫 rejected_intake — entró pero no cumplía criterios Intake

---

### Tab 2 — 🔍 Por conexión (drill-down)

**Para qué sirve**: bucear en UNA conexión concreta.

```
Conexión: [avoris-pull ▾]

┌─────────┬──────────┬───────────────────────┐
│ Fase    │ Status   │ DEV / PROD            │
│   1     │ active   │ not_deployed / not    │
└─────────┴──────────┴───────────────────────┘

Avoris (Polaris) — Pull nativo · pull · Contacto: Vanesa
ℹ Piloto Pull v0. Kickoff 13-abr. Sandbox por configurar. Calibra la línea.
```

Tres secciones debajo:

**HITL Gates**

| gate_number | gate_title | status | approver | decided_at | notes |
|---|---|---|---|---|---|
| 1 | Informe final (Fase 5) | pending | — | — | — |
| 2 | Aprobar mismatches y wrappers (Fase 4) | pending | — | — | — |
| 3 | Aprobar PR código (Fase 6) | pending | — | — | — |
| 4 | Go-live PROD (Fase 8) | pending | — | — | — |

**Phase log (últimas 10)**

| from_phase | to_phase | actor | occurred_at | notes |
|---|---|---|---|---|
| — | 1 | seed | 2026-05-18 11:25 | Bootstrap factory v0 — estado inicial al 2026-05-18 |

**Checklist**

| section | total | pending | green | yellow | red | na |
|---|---|---|---|---|---|---|
| A | 6 | 6 | 0 | 0 | 0 | 0 |
| B | 4 | 4 | 0 | 0 | 0 | 0 |
| C | 5 | 5 | 0 | 0 | 0 | 0 |
| ... |

→ Aquí Pedro/dev ve cuánto falta de la matriz técnica para esta conexión.

**Sorpresas abiertas** — vacío al principio. Crece a medida que se descubren mismatches en sandbox/mocks.

---

### Tab 3 — 📚 Aprendizaje cross-conexión

**Para qué sirve**: ver qué filas son siempre problemáticas en todos los providers (candidatas a wrapper Core).

```
Filas con mayor tasa 🔴 cross-conexión
```

| row_key | row_label | total_marked | reds | yellows | greens | pct_red |
|---|---|---|---|---|---|---|
| rate_key_ttl | rateKey TTL | 5 | 3 | 2 | 0 | 60.0 |
| cancel_timezone | Cancellation timezone | 4 | 2 | 1 | 1 | 50.0 |

→ Si `rate_key_ttl` está 🔴 en 60% de los providers, **es wrapper Core obligatorio** (RateKeyBuffer.cs ya en `catalog/wrappers-pull.md`).

**Sorpresas resueltas (insumo Anexo D)**: cada sorpresa que un dev resolvió queda aquí. Cuando llega un nuevo provider, busca antes aquí.

→ Esta pantalla **vacía al principio**. Crece tras los primeros cierres.

---

### Tab 4 — 📊 Métricas

**Para qué sirve**: dashboard de números (booking_error_rate, tiempo calendario, etc.).

Vacía hasta tener ≥5 cierres reales. No mires antes — no hay nada que mirar.

---

## 3. Workflow del developer — operativa diaria

### Caso A — Llega un nuevo provider (Intake Fase 0)

**Trigger**: Comercial te dice "vamos a conectar AcmeBeds".

**Tú haces** (en Claude Code):

```
/factory-new acmebeds-pull --type pull \
  --display "AcmeBeds — Pull nativo" \
  --contact "Jane Doe <jane@acmebeds.com>" \
  --doc-url https://acmebeds.com/api/docs \
  --sandbox-ok yes \
  --volume "150 hoteles · 2 clientes · 50 htls/request · diaria"
```

**Qué pasa por dentro**:
1. La skill valida 4 criterios Intake (doc + sandbox + contacto + volumen)
2. Si todos OK → `INSERT INTO connections (slug, status='active', current_phase=1, ...)`
3. Crea 4 HITL gates pending
4. Crea directorio `pilots/acmebeds-pull/` con plantilla
5. Clona 39 filas checklist Pull template a `checklist_responses` (todas pending)
6. `INSERT INTO phase_log (from_phase=0, to_phase=1, actor='claude/factory-new', notes='Intake OK · 4 criterios cumplen')`
7. Regenera `REGISTRY.md` + `pilots/acmebeds-pull/STATE.md`
8. `git add` + `git commit`

**Qué ves en el panel** (refresh):
- Tab 1 → aparece tarjeta `🟢 acmebeds-pull` en columna **Fase 1**
- Banner HITLs sube +4 (cuatro nuevos pending)
- Tab 2 → seleccionas acmebeds-pull, ves los 4 gates pending + checklist con 39 filas pending

**Si falta algún criterio Intake**:

```
✗ Conexión acmebeds-pull rechazada en Intake.
Faltan criterios: sandbox_ok, volume
Status='rejected_intake' registrado para métrica.
```

En el panel → aparece en **Tab 1** con icono 🚫 (filtra status='rejected_intake' para verlo).

---

### Caso B — Marcar filas de la checklist (Fase 1)

**Trigger**: Pedro/Santi lee la doc del provider y empieza a clasificar.

**Tú haces** (una por una o en lote):

```
/factory-checklist mark acmebeds-pull --row search_rate_key --class red \
  --notes "rateKey TTL=2min, demasiado corto. Necesita RateKeyBuffer"

/factory-checklist mark acmebeds-pull --row cancel_timezone --class yellow \
  --notes "Provider entrega en CET (offset fijo), hay que convertir a UTC"

/factory-checklist mark acmebeds-pull --row op_search --class green
/factory-checklist mark acmebeds-pull --row op_prebook --class green
# ... 35 filas más
```

**Qué pasa por dentro**: cada llamada hace `UPDATE checklist_responses SET classification, justification, marked_by, marked_at WHERE connection_id=... AND row_key=...`.

**Qué ves en el panel**:
- Tab 2 (drill-down acmebeds-pull) → la tabla "Checklist" se actualiza:

| section | total | pending | green | yellow | red | na |
|---|---|---|---|---|---|---|
| A | 6 | 4 | 2 | 0 | 0 | 0 |
| C | 5 | 4 | 0 | 0 | 1 | 0 |
| D | 3 | 2 | 0 | 1 | 0 | 0 |

- Tab 3 (cross-conexión) → si `rate_key_ttl` ya estaba 🔴 en otras conexiones, sube su contador y % de red.

**Patterns cross-conexión** (cuando una fila ya tiene precedente):

```
/factory-checklist patterns search_rate_key

→ Histórico cross-conexión:
    🔴 en 3/5 previas (HB, Dome, Expedia)
    🟡 en 2/5 previas (Roibos, Avoris)
  Confianza auto: ≥3 previas → AUTO 🔴/🟡
  Wrapper sugerido: RateKeyBuffer (catalog/wrappers-pull.md)
```

**Cuando todas marcadas**:

```
/factory-checklist finalize acmebeds-pull

✓ Checklist finalizado. HITL #1 listo para review por Pedro.
```

En el panel → HITL #1 cambia su `notes` a "checklist finalizado, listo para review". Sigue pending.

---

### Caso C — Aprobar un HITL (Pedro)

**Trigger**: Pedro revisa el informe y lo aprueba.

**Pedro hace** (o tú en su nombre):

```
/factory-update acmebeds-pull --hitl-approve 1 --approver Pedro \
  --evidence https://jira.../PDES-XXX --notes "Aprobado. Wrappers identificados."
```

**Qué pasa**:
- `UPDATE hitl_gates SET status='approved', approver='Pedro', decided_at=NOW(), evidence_url=...`

**En el panel**:
- Tab 2 → HITL #1 status pasa de "pending" a "approved", approver='Pedro'
- Banner HITLs: contador baja 1
- Tab 1 → tarjeta acmebeds-pull cambia su línea "HITL: #1,#2,#3,#4" → "HITL: #2,#3,#4"

---

### Caso D — Avanzar de fase

**Tú haces**:

```
/factory-update acmebeds-pull --phase 2
```

**Qué pasa**:
- `INSERT INTO phase_log (from_phase=1, to_phase=2, actor='Santi', notes='...')`
- `UPDATE connections SET current_phase=2 WHERE slug='acmebeds-pull'`

**En el panel**:
- Tab 1 → tarjeta acmebeds-pull se mueve de columna **Fase 1** a **Fase 2**
- Tab 2 → "Phase log" muestra la nueva transición arriba

---

### Caso E — Sandbox validate (Fase 2)

**Tú haces**:

```
/factory-sandbox validate acmebeds-pull
```

**Qué pasa**:
- Lanza 6 curls paralelos contra el sandbox (auth, search, statics_hotels, statics_rooms, prebook, book_dry)
- Captura responses en `pilots/acmebeds-pull/evidence/sandbox-YYYYMMDD-HHMM/`
- `INSERT INTO actions (action_type='sandbox_validate', target_env='provider-sandbox', outcome='pass|partial|fail', evidence_url='...')`
- Para cada mismatch doc↔realidad → `INSERT INTO surprises (...)`

**En el panel**:
- Tab 2 → "Phase log" no cambia (no es transición), pero hay un registro nuevo en `actions` (visible al hacer query directa o vía drill-down con SQL)
- Tab 2 → Sorpresas abiertas: si hubo mismatches, aparecen aquí

---

### Caso F — Mock tests (Fase 3)

```
/factory-mocktests run acmebeds-pull --env perlahub-dev
```

**Qué pasa**: corre los 7 casos estándar (basic_1_night, multi_night, multi_room, multi_occupancy, currency_switch, edge_dates, cancel_flow). Cada uno graba en `actions` con outcome pass/fail.

**Resultado**:

```
/factory-mocktests result acmebeds-pull

caso             | outcome | last_run
basic_1_night    | pass    | 2026-05-18 14:32
multi_night      | pass    | 2026-05-18 14:32
multi_room       | partial | 2026-05-18 14:33
multi_occupancy  | fail    | 2026-05-18 14:33
currency_switch  | pass    | 2026-05-18 14:33
edge_dates       | pass    | 2026-05-18 14:34
cancel_flow      | fail    | 2026-05-18 14:34
```

→ Hay 2 fails. **No pasa a Fase 4 automáticamente**. Humano investiga, registra sorpresas, decide si rebobinar a Fase 1 a re-clasificar la checklist o avanzar y resolverlo en Fase 4 (mismatches).

---

### Caso G — Registrar una sorpresa

**Trigger**: encontraste algo no documentado mientras hacías sandbox o mocks.

```
/factory-surprise add acmebeds-pull --title "rateKey expira a los 90s, no 2min como doc" \
  --description "Tras llamar prebook 91s después de search, devuelve RATE_EXPIRED. Doc decía TTL 2min." \
  --anexo D --row search_rate_key
```

**En el panel**:
- Tab 2 → "Sorpresas abiertas" muestra la nueva entrada con detected_at

**Cuando se resuelve**:

```
/factory-surprise resolve acmebeds-pull --id 7 --notes "Aplicado RateKeyBuffer wrapper, TTL real 80s aceptado"
```

→ Sale de Sorpresas abiertas, va a "Sorpresas resueltas" (Tab 3, insumo Anexo D).

---

### Caso H — Rebobinado (cuando algo salió mal)

**Trigger**: estás en Fase 4 clasificando mismatches y te das cuenta de que una fila Fase 1 está mal marcada.

```
/factory-update acmebeds-pull --phase 1 --notes "Rebobinado: rate_breakdown debió ser yellow no green"
```

**Qué pasa**: 
- `INSERT INTO phase_log (from_phase=4, to_phase=1, actor='Santi', notes='Rebobinado...')`
- `UPDATE connections SET current_phase=1`
- **Las filas anteriormente marcadas se conservan**. No se borran.

**En el panel**:
- Tab 1 → tarjeta vuelve a Fase 1
- Tab 2 → Phase log muestra el rebobinado como transición explícita

Tú re-marcas las filas afectadas y re-avanzas.

---

### Caso I — Cierre (DoD cumplido)

**Trigger**: Conexión en PROD, métricas estables N días (umbral §0.1 PLAN).

```
/factory-close acmebeds-pull
```

**Qué pasa**:
1. Verifica DoD: booking_error_rate <4%, HITLs todos approved, sorpresas todas resueltas
2. Si OK → mueve `pilots/acmebeds-pull/` a `case_studies/acmebeds-pull/`
3. Consolida lecciones en `catalog/known-mismatches-pull.md` (Anexo D vivo)
4. `UPDATE connections SET status='done'`
5. git commit + push

**En el panel**:
- Tab 1 → tarjeta desaparece de active (filtro default no muestra done). Cambia filtro a "done" para verla.
- Tab 3 → si añadió mismatches al Anexo D, suben los counters cross-conexión
- Tab 4 (métricas) → suma datos a la curva de aprendizaje

---

## 4. Cheatsheet desarrollador

```bash
# Arrancar todo (sesión nueva)
cd "<Drive>/Perlatours Full time/REPOS/factory"
bash scripts/init-db.sh                                       # levanta Postgres
cd dashboard && source .venv/bin/activate && streamlit run app.py &   # panel

# Ver estado actual
/factory-status                                               # tabla resumen
/factory-status acmebeds-pull                                 # detalle conexión
/factory-status --hitls                                       # solo HITLs pending

# Operaciones más comunes
/factory-new <slug> --type pull --display "..." --contact "..." \
  --doc-url ... --sandbox-ok yes --volume "..."

/factory-checklist mark <slug> --row <row_key> --class <green|yellow|red|na>
/factory-checklist diff <slug>
/factory-checklist patterns <row_key>
/factory-checklist finalize <slug>

/factory-update <slug> --phase <N>
/factory-update <slug> --hitl-approve <N> --approver Pedro
/factory-update <slug> --action sandbox_validate --env perlahub-dev --outcome pass

/factory-sandbox validate <slug>
/factory-mocktests run <slug> --env perlahub-dev
/factory-mocktests result <slug>

/factory-mismatches classify <slug>
/factory-surprise add <slug> --title "..." --anexo D
/factory-surprise resolve <slug> --id <n>

/factory-metric <slug> --env perlahub-prod --date 2026-05-20 \
  --name booking_error_rate --value 0.024

/factory-pull <slug>                          # supervisor F1-5
/factory-close <slug>                         # cierre DoD

# Regenerar artefactos manualmente
bash scripts/dump-registry.sh                 # REGISTRY.md
bash scripts/dump-pilot.sh <slug>             # pilots/<slug>/STATE.md
bash scripts/dump-state.sh                    # snapshot pg_dump → db/snapshots/

# Acceso DB directo (debug)
psql -h localhost -p 5433 -U factory -d factory               # password: factory_local
docker exec -it factory-db psql -U factory -d factory         # alternativa
```

## 5. Consultas SQL útiles (para debug)

```sql
-- Todas las conexiones activas con su HITL pendiente más antiguo
SELECT c.slug, c.factory, c.current_phase, MIN(h.id) AS oldest_hitl
FROM connections c LEFT JOIN hitl_gates h ON h.connection_id=c.id AND h.status='pending'
WHERE c.status='active' GROUP BY c.slug, c.factory, c.current_phase;

-- Filas problemáticas cross-conexión
SELECT row_key, COUNT(*) FILTER (WHERE classification='red') AS reds,
       ROUND(100.0 * COUNT(*) FILTER (WHERE classification='red') / COUNT(*), 1) AS pct
FROM checklist_responses WHERE classification IS NOT NULL
GROUP BY row_key ORDER BY pct DESC;

-- Audit trail completo de una conexión
SELECT 'phase' AS type, occurred_at, actor, from_phase::text||'→'||to_phase::text AS detail, notes
FROM phase_log WHERE connection_id=(SELECT id FROM connections WHERE slug='acmebeds-pull')
UNION ALL
SELECT 'action', occurred_at, NULL, action_type||' '||target_env||' '||outcome, notes
FROM actions WHERE connection_id=(SELECT id FROM connections WHERE slug='acmebeds-pull')
ORDER BY occurred_at;
```

## 6. Cuándo NO usar el factory

- **Codificación del conector** — eso vive en PerlaHub/PerlaPush repos, no aquí. Factory registra el commit hash y outcome pero no codifica.
- **Decidir qué proveedor conectar** — eso es comercial.
- **Sustituir Jira** — factory tiene `jira_epic_url` como referencia, pero issue tracking sigue en Jira.
- **Sustituir reunión humana** — cuando una decisión es real (extender contenedor canónico, aprobar mismatch arquitectónico), va a reunión Pedro+Eva+Santi. Factory lo registra después.

## 7. Si algo está roto

| Síntoma | Causa probable | Fix |
|---|---|---|
| Skill falla con "container factory-db down" | Docker apagado | `bash scripts/init-db.sh` |
| Streamlit muestra error "could not connect" | Postgres no escucha | `docker ps` → si no aparece factory-db, init-db.sh |
| Skill se queja "Slug no existe" | Typo o aún no creado | `/factory-status` muestra slugs válidos |
| REGISTRY.md desincronizado con DB | Skill no regeneró tras update | `bash scripts/dump-registry.sh` |
| Panel cachea data vieja | TTL 60s o cache cargada | Botón "↻ Refresh" en panel |
| Perdí data tras `docker compose down -v` | Bajaste con `-v` (borra volumen) | Restaurar de `db/snapshots/<fecha>.sql` |

---

**Resumen final**: el front es la **ventana de la planta**. No opera nada. Operar = skills. Mirar = front. Audit = git + REGISTRY.md + case_studies/.
