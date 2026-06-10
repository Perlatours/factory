---
name: factory-pull
description: |
  Supervisor de línea Pull. Orquesta las Fases 1-5 (análisis doc → checklist → sandbox →
  mock tests → mismatches → informe final) invocando las skills atómicas y registrando
  estado en DB. Para una conexión Pull existente con Intake aprobado.
  Invocar cuando Santi diga "ejecuta factory-pull X", "avanza Avoris hasta informe",
  "/factory-pull avoris" o "/factory-pull avoris --phase 3".
version: "1"
allowed-tools: [Bash, Read, Write]
---

# Factory Pull — Supervisor (protocolo determinista)

Orquestador del flujo Pull Fases 1-5 (anti-tactical: NO codifica ni hace deploy; eso es F6+ con humano).

## ⛔ Reglas de control (NO negociables)

1. **No inventes SQL ni nombres de columna.** Usa las queries EXACTAS de este archivo. Para
   marcar/leer checklist, sandbox, etc., **delega en las skills atómicas** (`/factory-checklist`,
   `/factory-sandbox`, `/factory-mocktests`, `/factory-mismatches`, `/factory-update`). Si necesitas
   un dato de la conexión, usa la query del **Paso 0**.
2. **No preguntes al humano menús abiertos** ("¿cómo procedo?", "¿commit o no?"). El **único punto de
   parada humano es una puerta HITL**, que el humano revisa en el panel. Entre puertas, ejecuta.
3. **Las marcas de checklist que escribe esta skill son PROVISIONALES** (`marked_by=claude/...`).
   Escribirlas **es parte del protocolo, no requiere confirmación**. Pedro las revisa en HITL #1.
4. **Idempotente.** Cada llamada lee `current_phase` (Paso 0) y actúa SOLO en la fase que corresponde.
   Re-ejecutar no duplica (las atómicas usan UPDATE / ON CONFLICT).
5. **Toda parada produce un reporte fijo** (ver §Salida estándar): fase, qué se hizo, dónde paró y por qué.

## Sintaxis

```
/factory-pull <slug>                 # ejecuta desde current_phase hasta la siguiente puerta HITL
/factory-pull <slug> --phase <N>     # fuerza ejecutar SOLO la fase N (debe coincidir con current_phase)
/factory-pull <slug> --resume        # retoma tras pausa/crash (idempotente)
```

## Paso 0 — Cargar estado (query EXACTA — no inventar columnas)

```bash
docker exec -i factory-db psql -U factory -d factory -P pager=off <<SQL
SELECT id, slug, display_name, factory, mode, current_phase, status, owner_hitl
FROM connections WHERE slug='$SLUG';
SQL
```

> Columnas reales de `connections`: `display_name`, `factory`, `current_phase`, `status`, `owner_hitl`,
> `mode`, `is_pilot`, `intake_*`, `contact_*`, `dev_status`, `prod_status`, `notes`.
> **NO existen** `provider_name` ni `flow_type`. Si dudas del esquema: `\d connections`.

**Guardas (STOP inmediato, sin crear nada):**
- Slug no encontrado → `STOP: "Slug no existe. /factory-status lista los válidos."`
- `status != 'active'` → `STOP: "Conexión en status=<x>, no se opera."`
- `current_phase < 1` → `STOP: "Intake no aprobado (fase <1). Usa /factory-new."`
- `factory != 'pull'` → `STOP: "factory-pull solo opera conexiones Pull."`

Luego salta a la sección cuya fase == `current_phase`.

---

## Fase 1 — Análisis doc + checklist

**Precondición:** `pilots/<slug>/inputs/doc/` contiene la doc del proveedor.
Si está vacío → `STOP: "Falta la doc en pilots/<slug>/inputs/doc/ (Swagger/Postman/PDF)."`

**Protocolo (determinista):**

1. Lista filas pendientes: `/factory-checklist diff <slug>`.
2. **Lee TODA la doc** de `inputs/doc/` (PDF, docx, xlsx, swagger.json). Convierte a texto si hace falta
   (`pdftotext`, `python-docx`, `openpyxl`). No clasifiques sin haber leído la doc completa.
3. **La checklist es la ÚNICA vara.** Para **cada** fila, **compara su columna `expected` (lo que pide
   PerlaHub) contra lo que hace el provider en la doc**. La clasificación sale **solo de esa comparación**.
   El canónico (P1–P6) ya está embebido en `expected` → **NO traigas decisiones ni soluciones externas**:
   - 🟢 `green` — el provider **cumple el `expected` tal cual** (cita doc §).
   - 🟡 `yellow` — cumple **parcialmente**, requiere mapeo, o la doc **no es concluyente** respecto al `expected`.
   - 🔴 `red` — el provider **contradice o no puede cumplir** el `expected` (gap).
   - ⚪ `na` — el `expected` **no aplica** al modelo Pull de este provider.
   La justificación **debe citar (a) qué pide el `expected` y (b) qué da el provider (doc §)** — y nada más.
   **NO propongas wrappers ni soluciones aquí** (eso es Fase 4 / diseño). En Fase 1 solo se **compara**.
4. **Escribe cada marca** (provisional, sin pedir permiso) con justificación y evidencia:
   ```
   /factory-checklist mark <slug> --row <row_key> --class <green|yellow|red|na> \
     --evidence "<doc §sección/página>" --notes "[conf:H|M|L] <base de la decisión>"
   ```
   (`conf` = confianza; va en notes porque no hay columna dedicada.)
5. Cuando **todas** estén marcadas: `/factory-checklist finalize <slug>` → deja **HITL #1 listo**.
6. Para cada fila 🔴 o sin precedente cross-conexión (`/factory-checklist patterns <row_key>` = 0 previas):
   registra una sorpresa (`/factory-surprise add <slug> ...`) → input de HITL #3.
7. **STOP en HITL #1.** No avances a Fase 2. Output: tally (🟢🟡🔴⚪) + lista de 🔴 y dudosas, y deja
   claro que **la revisión es una DISCUSIÓN, no un sello**:
   `"HITL #1 listo. Para revisarlo: /factory-review <slug> — Claude propone cada 🟡/🔴 y tú decides."`
   (NO sugieras `--hitl-approve` directo: eso aprobaría todo a ciegas.)

---

## Fase 2 — Sandbox validation

**Precondición:** `pilots/<slug>/inputs/03-credentials.local.env` existe (git-ignored).
Si no → `STOP: "Faltan credenciales sandbox en pilots/<slug>/inputs/03-credentials.local.env."`

```
/factory-sandbox validate <slug>
```
- `outcome=pass` → `/factory-update <slug> --phase 3` y **continúa a Fase 3**.
- `outcome=partial|fail` → **STOP**, reporta el detalle, **NO avances** (humano investiga).

---

## Fase 3 — Mock tests

```
/factory-mocktests run <slug> --env perlahub-dev
```
- 7/7 `pass` → `/factory-update <slug> --phase 4` y **continúa a Fase 4**.
- Cualquier `fail|partial` → **STOP**, reporta los casos fallidos.

---

## Fase 4 — Clasificar mismatches

```
/factory-mismatches classify <slug>
```
- Si hay row_keys **genuinamente nuevas** → **HITL #3 pending visible**, **STOP** (decisión humana).
- Si todo es conocido (catálogo Anexo D) → `/factory-update <slug> --phase 5` y **continúa a Fase 5**.

---

## Fase 5 — Informe final

1. `bash scripts/dump-pilot.sh <slug>` (regenera STATE.md).
2. Compila `pilots/<slug>/outputs/informe.md`: score real (5 ejes), wrappers Core necesarios,
   lista de 🔴 + sorpresas, y recomendación (proceder a F6 / pivotar / cancelar).
3. Marca HITL #1 listo:
   ```bash
   docker exec -i factory-db psql -U factory -d factory <<SQL
   UPDATE hitl_gates SET notes='Informe final listo, esperando review Pedro'
   WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG') AND gate_number=1;
   SQL
   ```
4. **STOP en HITL #1.** F6 (codificación) y F7-8 (E2E + go-live) van **fuera de la planta** (repo PerlaHub).
   En el informe, la sección "Siguiente" debe apuntar al comando estandarizado de F6:
   **"Fase 6 → `/factory-implement <slug>`"** (no implementar ad-hoc; ese comando arranca desde el
   informe + DoD §11 e incluye audit Capa 8 y la verificación en local).

---

## Rebobinado (idempotente)

```
/factory-update <slug> --phase 2    # p.ej. de F4 a F2; conserva filas y artefactos
/factory-pull <slug> --resume       # retoma desde la nueva current_phase
```

## Salida estándar (en TODA parada)

Reporta exactamente:
- **Conexión** y **fase actual** (tras la ejecución).
- **Qué se hizo** (acciones/marcas/transiciones, con conteos).
- **Dónde paró y por qué** (puerta HITL #N, o condición fail/precondición faltante).
- **Siguiente acción** (qué desbloquea avanzar: aprobar HITL en el panel, aportar creds, etc.).
