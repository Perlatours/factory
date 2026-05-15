---
title: Walkthrough · Factory Pull (target real con Claude Code)
date: 2026-05-15
status: example
purpose: Mostrar que una conexión industrial cabe en 1-2 días
audience: Santi, Pedro, futuro Claude
---

# Walkthrough · Factory Pull con Claude Code

## TL;DR — La curva real

```
#1 Avoris (calibración):     ~5-7 días · ~6-8h Santi · construye los 4 activos
#2 (1ª iteración):            ~3 días   · ~3-4h Santi · catálogo a 5-10 entradas
#3-4 (afinando):              ~2 días   · ~2h Santi   · catálogo a 15-25 entradas
#5+ (industrial):             ~1-2 días · ~1-2h Santi · catálogo cubre 90%+

Cuello duro restante: 24h tráfico estable (no 7 días — el catálogo predice)
                       Pedro disponible mismo día
                       Ventana deploy a coordinar (puede ser día, no necesariamente madrugada)
```

## Por qué cambia tanto vs el walkthrough anterior

Antes asumí dogmas que no aplican en factory madura:
- ❌ "7 días tráfico estable" → **24h bastan**, el catálogo predice sorpresas
- ❌ "Pedro async, espera 15-30 min/HITL" → **Pedro sincrónico** el día agendado
- ❌ "Deploy PROD solo madrugada" → **revisar política**, varias ventanas posibles
- ❌ "Fases activas en días" → **Fases 1-5 caben en ~1h** con Claude Code

---

# Walkthrough principal · Conexión #5 (industrial estable), 2 días totales

Provider: **AcmeBeds** (Pull). Factory tiene 4 conexiones cerradas. Catálogo con 22 mismatches conocidos. 6 wrappers Core vivos en PerlaHub.

## Día 1 · Lunes — ~2h Santi efectivos, todo el ciclo activo

### 09:00 — 10 min — Registro + inputs

```
/factory-new acmebeds --type pull --contact "Jane Smith <jane@acmebeds.com>"
```

Santi arrastra a `pilots/acmebeds/inputs/`:
- `01-api-doc.pdf`
- `02-postman.collection.json`
- `03-credentials.local.env`
- `00-context.md` (3 líneas)

### 09:10 — 15 min — Fase 1 análisis (Claude trabaja)

```
/factory-pull acmebeds
```

Output:
```
✓ Catálogo: 22 mismatches conocidos cargados
✓ 150 filas clasificadas:
    - 144 con precedente alto (≥3 prev) → auto-aprobadas
    - 4 con precedente medio → marcadas tentativas
    - 2 nuevas → flagged HITL #3 desde ya
✓ Score 11/18 (modo B medio-alto)
✓ Banderas rojas: 2 (todas conocidas, wrappers existen)
✓ Generado pilots/acmebeds/outputs/01-fase1-checklist.md
✓ Estimación adapter: ~25 líneas únicas + scaffold + 4 wrappers
```

Santi revisa solo las 4 tentativas + 2 nuevas (5 min). Acepta 5, ajusta 1.

```
/factory-checklist finalize acmebeds --by Santi
```

### 09:25 — 10 min — HITL #1 (Pedro disponible)

Santi pinga Pedro: "AcmeBeds Fase 1 lista, 2 mismatches nuevos, ¿revisas en 5 min?"

Pedro abre el MD en GitHub web mientras está en otra call. Responde Slack 09:32: "OK, los 2 nuevos parecen passthrough estándar, OK con sandbox".

```
/factory-update acmebeds --hitl-approve 1 --by "Pedro"
```

### 09:35 — 15 min — Sandbox + Mock Tests paralelos

```
/factory-sandbox validate acmebeds
```

Claude lanza 6 endpoints en paralelo, ~30s wall-clock. Detecta 2 discrepancias menores. Auto-update filas.

```
/factory-mocktests run acmebeds
```

Claude lanza 7 casos en paralelo, ~3 min wall-clock. 7/7 OK (1 partial expected).

### 09:50 — 5 min — Mismatches classification (auto)

```
/factory-mismatches classify acmebeds
```

```
22 yellow + 6 red:
  Conocidos (catálogo): 26 → wrappers existentes
  NUEVOS: 2 (ya detectados en Fase 1)
    - loyalty_id_passthrough
    - preferred_currency_per_market
```

### 09:55 — 10 min — HITL #2+#3 combinados (Pedro disponible)

Santi: "Mock tests 7/7 OK + 2 mismatches nuevos detectados. ¿Combinamos HITL #2+#3? Loyalty como metadata + currency forcer wrapper".

Pedro 10:00: "OK ambos. Currency forcer ya lo usamos en HB, mismo patrón".

```
/factory-update acmebeds --hitl-approve 2 --by "Pedro"
/factory-update acmebeds --hitl-approve 3 --by "Pedro" \
    --note "loyalty → metadata, currency → CurrencyForcer wrapper"
```

### 10:10 — 30 min — Fase 6 codificación con Claude Code

Santi abre otro Claude Code en `REPOS/perlahub/`. Prompt:

> Clona Connectors/Accommodation/Roibos/ (más cercano a AcmeBeds). Aplica 4 wrappers: RateKeyBuffer, TimezoneResolver, BackoffExpStrategy, CurrencyForcer. Capturar loyalty_id como BookingMetadata.providerLoyaltyId. Adapter específico AcmeBeds: ver outputs/05-final-report.md en factory repo.

Claude Code 20 min wall-clock:
- Scaffold de `Connectors/Accommodation/AcmeBeds/` (clon Roibos)
- 4 wrappers wired (1 línea de config cada uno)
- Adapter AcmeBeds: ~25 líneas únicas
- Tests unitarios mínimos
- PR draft levantado

Santi revisa diff (10 min). Mínimo cambio. Aprueba.

### 10:40 — 20 min — Merge dev + deploy DEV

Pedro hace PR review (5 min via GitHub web), aprueba.
Santi merge a `dev`. Auto-deploy DEV (~10 min CI/CD).

```
/factory-update acmebeds --phase 6 \
    --dev-pr "https://github.com/Perlatours/perlahub/pull/187"
/factory-update acmebeds --action deploy --env perlahub-dev \
    --dev-commit "9f3b21e" --outcome pass
```

### 11:00 — 15 min — Fase 7 E2E desde PerlaHub DEV

```
/factory-mocktests run acmebeds --env perlahub-dev
```

Claude lanza 7 casos desde PerlaHub DEV → AcmeBeds sandbox. 7/7 OK en ~5 min.

```
/factory-update acmebeds --action e2e_test --env perlahub-dev --outcome pass
/factory-update acmebeds --phase 7
```

### 11:15 — 10 min — HITL #4 + ventana PROD

Santi: "E2E DEV OK. ¿Ventana PROD esta tarde 16:00 (tráfico bajo) o esperamos madrugada?"

Pedro: "16:00 OK, tenemos canary deploy y rollback < 5min".

```
/factory-update acmebeds --hitl-approve 4 --by "Pedro+Santi" \
    --note "ventana 16:00 hoy, canary + rollback < 5min"
```

### 11:30 — Pausa hasta 16:00

(Santi hace otras cosas. Factory listo para PROD.)

### 16:00 — 15 min — Deploy PROD + smoke

Pedro mergea `dev` → `main` PerlaHub. Auto-deploy con canary (10% tráfico primero).

Santi monitorea Grafana 5 min. P95 latency OK, 0 errores.

Canary → 100%. Smoke 20 reservas reales en 10 min.

```
/factory-update acmebeds --action deploy --env perlahub-prod \
    --prod-commit "c4d8a91" --outcome pass --note "canary 10%→100% OK"
/factory-update acmebeds --action prod_smoke --env perlahub-prod \
    --outcome pass --note "20 reservas, P95 312ms, 0 errores"
/factory-update acmebeds --phase 8
```

```sql
UPDATE connections SET prod_status='live', prod_commit='c4d8a91' WHERE id=10;
```

**Estado al cierre Día 1**:

| AcmeBeds | Pull | 8 — Go-live | – | tested | **live** | Pedro+Eva | 2026-05-19 |

---

## Día 2 · Martes — Monitoreo + cierre, ~30 min Santi

### Durante el día — Cron auto

Cron diario lee Grafana, registra métricas:
```sql
INSERT INTO metrics VALUES (10, 'perlahub-prod', '2026-05-20',
    'booking_error_rate', 1.4, 'grafana');
```

Santi NO interviene salvo si alerta dispara. Hoy no dispara.

### 16:00 — 15 min — Revisión 24h tráfico estable

Santi abre Streamlit dashboard o consulta:

```
/factory-status acmebeds --metrics
```

```
AcmeBeds · 24h post go-live
  Reservas exitosas:        287
  booking_error_rate:       1.4% (target <4% ✓)
  price_changed_rate:       3.8% (normal)
  ratekey_expired_rate:     0.2%
  Sorpresas detectadas:     0
  
DoD check:
  [x] Mock tests pasados
  [x] 24h tráfico estable
  [x] Error rate < 4%
  [x] Mapeo cerrado (47/47 hoteles Eva confirmó 11:00)
  [x] 0 sorpresas pendientes
```

### 16:15 — 15 min — Cierre

```
/factory-close acmebeds
```

Detrás:
1. Genera case_study auto desde DB
2. Mueve `pilots/acmebeds/` → `case_studies/acmebeds/`
3. Consolida 2 mismatches nuevos al catálogo (loyalty_id_passthrough + preferred_currency_per_market) → ahora son 24 entradas
4. Memoria brain `project_factory_acmebeds_done.md`
5. UPDATE connections.status='done'
6. Commit + push

```
[main d2f4e8a] factory: close acmebeds (#5 done, 2 días, ~2.5h Santi, 1.4% error rate)
```

---

# Resumen día-por-día

```
Día 1 · Lunes
  09:00 → 11:30  Trabajo activo Claude+Santi (Fases 0-7)
                 - registro, inputs, análisis, sandbox, mocktests, mismatches,
                   codificación, deploy DEV, E2E DEV
                 - 4 HITLs aprobados (Pedro síncrono)
                 - ~2h Santi efectivos
  
  11:30 → 16:00  Pausa (Santi en otras cosas, factory listo)
  
  16:00 → 16:15  Deploy PROD + smoke (canary + 20 reservas)
                 - 15 min total
                 - PROD live

Día 2 · Martes
  Mañana         Cron auto registra métricas (Santi nada activo)
  
  16:00 → 16:30  Revisión 24h + cierre (DoD ok, factory-close)
                 - 30 min total

TOTAL:  ~2.5h Santi · 2 días calendario · 287 reservas reales día 1-2
```

---

# Cuándo NO se completa en 2 días (problemas reales)

| Situación | Días extra | Justificación |
|---|---|---|
| Provider sandbox falla / no responde | +1-3 días | Esperar a contacto externo (Jane) |
| Mismatches genuinamente nuevos requieren reunión Pedro+Eva con tema gordo | +1 día | Decisión arquitectónica, no async-able |
| Provider quiere extender el contenedor canónico con campo nuevo | +1-7 días | Decisión Eva/Pedro/Santi + posible implementación |
| Smoke PROD falla → rollback → debug → re-deploy | +1-2 días | Bug real que no salió en DEV |
| Score 12+ (alta complejidad genuina, no aplica patrón existente) | +1-3 días | Más código nuevo, más test |
| Provider con auth exótica (SOAP+WS-Security legacy, mTLS custom) | +1-2 días | Setup auth a mano |
| Métricas día 2 anomalías → mantener tráfico 2-3d más antes de cierre | +1-3 días | Confianza adicional |

**El target 2 días asume**:
- ✅ Pedro disponible misma jornada
- ✅ Provider sandbox responde normal
- ✅ Score ≤ 11 (modo B medio-alto o más simple)
- ✅ Ventana PROD coordinable mismo día
- ✅ Catálogo factory cubre 80%+ de mismatches
- ✅ Métricas día 2 sin anomalías

Si CUALQUIERA de estos falla, los días extra son **trabajo real**, no fricción del proceso.

---

# Conexión #1 (Avoris) — la inversión inicial

Por qué Avoris tarda más (5-7 días, ~6-8h Santi):
- Catálogo vacío → no hay precedente, Santi clasifica más filas a mano
- 0 wrappers Core → primer adapter define los wrappers que luego se reutilizan
- 0 templates → primer conector define el scaffold
- Skill v0 inestable → calibra con cada decisión

**Avoris construye los activos. La 2ª se beneficia inmediatamente. La 5ª opera al ritmo industrial.**

---

# El target estable

A partir de conexión #5:

| Métrica | Target |
|---|---|
| Días calendario | 2 |
| Horas Santi efectivas | 1.5-2.5h |
| Trabajo Claude Code automático | ~70% de las fases |
| HITLs en bloque | sí (Pedro 1 sesión 30min) |
| Tráfico estable mínimo | 24h |
| Sorpresas esperadas | 0-1 (catálogo predice) |

**Si una conexión madura tarda > 3 días sin razón listada arriba → algo del proceso falla, revisar.**

---

# Riesgos al pintar 2 días como target

1. **Pedro no siempre disponible misma jornada** — solución: agendar conexión con Pedro la víspera, bloque 2h reservado.
2. **Ventana PROD madrugada por política** — solución: revisar política Perlatours, ¿se puede deploy 16:00 con canary?
3. **24h tráfico estable es poco si surge bug raro** — solución: rollback < 5min siempre listo + monitoreo Grafana alerta automática.
4. **Smoke 20 reservas no detecta edge case de 1/1000** — aceptado: detectaremos día 3-7 con cron, hot-patch si pasa.

→ El target 2 días **es achievable Y arriesgado**. La diferencia vs 7 días = velocidad. Decisión negocio.
