---
title: Factory Push — Validaciones de la API Push In (checklist por conexión nueva)
date: 2026-05-12
source: Plan Push In Genérico v9 + auditoría /Users/santiagopatinoserna/Documents/Workspace_Perlahub/PerlaPush + adapters Dingus/SiteMinder/Generic
parent: factory_push_briefing_v0.md
tags: [factory, push, validaciones, perlahub, push-in-generico, adapters, checklist, contrato-fijo]
status: v0.1-12may-checklist-anclado-codigo
history: v0 11-may (extracción inicial); v0.1 12-may (corregido contra repo real, enfoque checklist reforzado)
---

# Factory Push — Validaciones contra PerlaPush

> **Cómo se usa este doc**: es la **checklist accionable** que cada conexión Push nueva tiene que recorrer antes de mergear. Cada capa, endpoint, error code, decisión y bug = un ítem ✅/❌. NO es descripción pasiva del sistema.

## TL;DR

Toda conexión Push **hereda como contrato fijo del Push-In Genérico v9** (auditado 12-may contra `/Users/santiagopatinoserna/Documents/Workspace_Perlahub/PerlaPush/`):
- **7 capas de validación** secuenciales (middleware real en `Ingestion.Generic.Api/Middleware/`)
- **10 endpoints** (rutas reales — algunas divergen del doc previo: ver §3)
- **18 códigos de error reales** en enum `PushInErrorCode` (el doc previo decía 20; nombres también divergen)
- **1 gateway de escritura a PerlaPush** (`IAvailabilityManagementGateway` — firmas auditadas, divergen del doc previo)
- **1 modelo de datos destino** (`NormalizedAvailability` + `AvailabilityPrice` — confirmado)
- **3 adapters reales en código**: `DingusAdapter` (Modo B), `SiteMinderAdapter` (Modo B), `GenericAdapter` (Modo A). `AllbedsAdapter`/`CNBookingAdapter` mencionados en docs pero **NO presentes en código actual**.

> 🚨 **GAP CRÍTICO 12-may**: el doc previo asumía **Redis** para idempotencia/rate-limit/auth cache. Código real usa **`ConcurrentDictionary` in-memory** (`IdempotencyMiddleware.cs:24`, `RateLimitMiddleware.cs:20`). **Esto rompe en clúster multi-instancia**. Cualquier conexión nueva debe ser consciente: no idempotencia distribuida hoy.

Lo que **cambia** entre conexiones (eje de complejidad para la Skill):
- Parser de entrada (Modo B = nosotros construimos un adapter; Modo A = nada que construir)
- Modo de autenticación admitido
- Modelos de precio que el provider declara (Unit / Person / Occupancy)
- Volumen del adapter (líneas de mapping según riqueza del formato externo)

> Este doc es la "definición del recipiente único" del que habló Santi en la call 11-may. Es la **garantía de no-regresión**: cada nueva conexión Push pasa por este contrato.

---

## 1. Las 7 capas de validación (orden de ejecución)

Cada request entrante atraviesa las capas en este orden. Si una capa rechaza, las siguientes no se evalúan.

### Capa 1 — Transporte / Auth
**Ubicación código**: `Ingestion.Generic.Api/Middleware/ApiKeyAuthMiddleware.cs:10-161`.

✅ Checklist:
- [ ] El conector envía header `Authorization: Bearer pk_live_{32 chars base62}` (40 chars total). Sandbox: `pk_test_*`
- [ ] El backend valida HMAC-SHA256(apiKey, serverSecret) — `ApiKeyAuthMiddleware.cs:140`
- [ ] Hash almacenado en `masters_push.providers.api_key_hash`, nunca raw
- [ ] Comparación constant-time (`CryptographicOperations` o equivalente)
- [ ] El provider está dado de alta en MastersPush con `IsActive=true` antes de tráfico

**Errores reales**: HTTP 401 `API_KEY_MISSING` / `API_KEY_INVALID` / `API_KEY_FORMAT_INVALID` · HTTP 403 `PROVIDER_SUSPENDED` / `INSUFFICIENT_PERMISSIONS`.

⚠️ **Divergencia 12-may con doc previo**:
- Doc previo decía "Cache Redis `pushin:auth:{hash}` TTL 5min". **NO implementado en Redis**: auth se valida contra DB cada vez (o cache in-process). No hay key `pushin:auth:*` en código real.
- Doc previo enumeraba 1 código (`INVALID_API_KEY`). Código real tiene **3 variantes 401**: `API_KEY_MISSING`, `API_KEY_INVALID`, `API_KEY_FORMAT_INVALID`.

> Fuente: Plan v9 §6 + auditoría 12-may en `ApiKeyAuthMiddleware.cs`.

### Capa 2 — Identidad / Tenant isolation
**Ubicación código**: `ApiKeyAuthMiddleware.cs` valida `provider.IsActive` línea 94 + asociaciones via `IMastersPushGateway`.

✅ Checklist:
- [ ] Cada `hotelId` del request tiene fila activa en `masters_push.provider_hotel_associations`
- [ ] Constraint DB `UNIQUE INDEX (hotel_id) WHERE is_active = true` respetada — un solo provider activo por hotel
- [ ] Mismo error si hotel no existe O existe pero no asociado al provider (no revelar info cross-tenant — patrón AWS S3)
- [ ] El conector NO asume orden ni listas de hoteles fuera de su asociación

**Error real**: HTTP 403 `FORBIDDEN_HOTEL` (el doc previo decía `HOTEL_ACCESS_DENIED`, nombre divergente). Código único, no diferenciar inexistente vs no-asociado.

> Fuente: Plan v9 §2 + §6 + §13 (Migration 3). Auditado 12-may.

### Capa 3 — Shape / JSON Schema (FluentValidation)
- **Campos obligatorios** según endpoint (ver §3 de este doc).
- **Fechas**: ISO 8601 `YYYY-MM-DD`. Rango **inclusivo-inclusivo** (`from` y `to` incluyen la noche). Convención respetada por todos los adapters (`DingusAdapter:125`, `SiteMinderAdapter:159`).
- **Límites duros**:
  - Payload ≤ 5 MB (Nginx 6 MB / Kestrel 6 MB / FluentValidation cap) → HTTP 413 `PAYLOAD_TOO_LARGE`.
  - `updates.Count` ≤ 1000.
  - `roomCode.Length` ≤ 200, `rateCode.Length` ≤ 200, `mealPlanCode.Length` ≤ 50, `currencyCode.Length` = 3 (ISO 4217).
  - `metadataJson.Length` ≤ 10,000.
  - JSON depth ≤ 32.
- **Error**: HTTP 400 `VALIDATION_ERROR`. Campo `field` en warningDetails apunta exacto (`updates[3].roomCode`).

> Fuente: Plan v9 §5.1-5.3 (Contratos) + §17 (Payload Limits).

### Capa 4 — Idempotencia (Stripe pattern)
**Ubicación código**: `Ingestion.Generic.Api/Middleware/IdempotencyMiddleware.cs:19-161`. SHA256(body) línea 139-143. TTL 24h línea 25.

✅ Checklist:
- [ ] El conector envía header opcional `X-Idempotency-Key: {uuid}` en POSTs que pueden reintentarse
- [ ] Si lo usa, los reintentos llevan el MISMO key
- [ ] Mismo key + mismo body → replay (HTTP 200 + `X-Idempotency-Replayed: true`)
- [ ] Mismo key + body diferente → HTTP 422 `IDEMPOTENCY_KEY_REUSED`
- [ ] El conector tolera "skip idempotencia" si cache cae (preferible duplicado a rechazar)

🚨 **GAP CRÍTICO 12-may**: el doc previo afirmaba "Redis GET `pushin:idempotency:{providerId}:{key}`". **NO implementado en Redis**: el código usa `ConcurrentDictionary` in-memory (`IdempotencyMiddleware.cs:24`). Esto significa:
- [ ] **AVISO al equipo del conector**: idempotencia NO persiste entre reinicios del servicio
- [ ] **AVISO al equipo de operaciones**: con N instancias detrás de LB, idempotencia NO es real entre instancias (replay puede no ocurrir si LB rota a otra instancia)
- [ ] Decidir con Pedro si migrar a Redis antes de Go-Live de SiteMinder/Avoris, o aceptar el gap

> Fuente: Plan v9 §9 + Decisión Francesc D1 + auditoría código 12-may.

### Capa 5 — Business rules
- **Fechas**:
  - `from > to` o rango > 365 días → HTTP 400 `INVALID_DATE_RANGE`.
  - Rango totalmente en el pasado → HTTP 400 `VALIDATION_ERROR`.
  - Rango parcialmente pasado → warning `DATE_IN_PAST` (HTTP 200, procesa el resto).
- **Disponibilidad**: `roomsToSell ≥ 0` (ajustado por bookings); `minimumStay ≤ maximumStay`.
- **Precio**: `price > 0` o warning `MISSING_PRICE`. Fuera de threshold → warning `PRICE_EXCEEDS_THRESHOLD`.
- **Ocupación**: `totalPax ≤ room.maxOccupancy` o warning `OCCUPANCY_EXCEEDS_MAX`.
- **Close/Open**: `roomCodes` OBLIGATORIO (lista explícita).
- **Expansion guard**: `SUM(dateSpan × mealPlanCount)` > 10,000 → HTTP 400 `EXPANSION_LIMIT_EXCEEDED`.

> Fuente: Plan v9 §5 (Contratos) + §7 (Expansion Guard líneas 679-694) + §5.8 (Catálogo errores).

### Capa 6 — Mapping (contra Masters / MastersPush)
**Ubicación código**: `Ingestion.Generic.Api/Adapters/GenericAdapter.cs` + `GenericIngestionService` consulta `IMastersGateway` y `IMastersPushGateway` (en `Utils/`).

✅ Checklist (cada update antes de persistir):
- [ ] `Masters.GetHotelAsync(hotelId, includeOccupancies:true)` → si no existe: HTTP 403 `FORBIDDEN_HOTEL`
- [ ] `roomCode` ∈ `hotel.Rooms.InternalCode` o warning `UNKNOWN_ROOM_CODE` (doc previo decía `ROOM_NOT_FOUND`)
- [ ] `rateCode` ∈ `hotel.RateCodes` o warning `UNKNOWN_RATE_CODE` (doc previo `RATE_NOT_FOUND`)
- [ ] `mealPlanCode` ∈ `hotel.MealPlanCodes` o warning `UNKNOWN_MEAL_PLAN` (doc previo `MEALPLAN_NOT_FOUND`)
- [ ] `currencyCode == hotel.CurrencyCode` (warning `CURRENCY_MISMATCH` — pendiente confirmar si existe en enum real)
- [ ] `ageConfig = hotelRoom.AgeConfiguration ?? hotel.AgeConfiguration` aplicado
- [ ] Antes del go-live: hotel + room/rate/mealplan catálogo poblado en Masters para los hoteles del provider

**Resiliencia Masters**: Circuit breaker + Polly (2× retry exp 200ms, timeout 3s). Si Masters caído: modelos `Occupancy` procesan sin Masters; modelos `Unit/Person` → HTTP 503 `SERVICE_UNAVAILABLE`.

⚠️ **Nota cache 12-may**: el doc previo decía "Cache `pushin:hotel:{hotelId}` TTL 1h". El string `pushin:` no aparece en código de PerlaPush (`grep` 12-may). Probablemente el cache vive en memoria o sin namespace; verificar con Pedro.

> Fuente: Plan v9 §7 + §16 + auditoría 12-may.

### Capa 7 — Persistencia / Consistencia
- **Unique key availability**: `(ProviderCode, HotelId, Date, RoomCode, RateCode)`.
- **Unique key price**: `(AvailabilityId, MealPlanCode, MinStayBasedRate, TotalPax, AgeRangesJson)`.
- **Delta (POST /availability)**: incremental, `MergePrices()` actualiza+agrega, **NUNCA elimina** (eliminar = full-refresh). Lock: `pg_try_advisory_xact_lock(hotelId)` non-blocking → HTTP 503 + `Retry-After: 5s` si ocupado.
- **Full-refresh (POST /availability/full-refresh)**: lock blocking `pg_advisory_xact_lock(hotelId)` timeout 10s. DELETE rango → INSERT con `RoomsToSell = max(0, provider.RoomsToSell - bookingCount)` calculado ANTES del DELETE. **Sobrescribe TODO, incluyendo cierres previos** (decisión D2).
- **Close/Open**: `ExecuteUpdateAsync()` set `IsClosed`. NO soporta `mealPlanCodes` (IsClosed vive en `NormalizedAvailability`, no en `Price`).
- **Last-writer-wins**: dos updates con misma key → warning `DATE_RANGE_OVERLAP`, último gana.

> Fuente: Plan v9 §2 + §11 (líneas 862-885) + §12 (líneas 892-913) + Decisión D2.

---

## 2. Catálogo de errores REAL (auditado 12-may)

**Enum literal**: `PushInResponseContracts.cs:421-499` → **18 códigos en código**, no 20.

### Bloqueantes — abortan toda la request

| # | HTTP | Código REAL | Doc previo decía | Cuándo |
|---|------|-------------|------------------|--------|
| 1 | 401 | `API_KEY_MISSING` | (no listado) | Header `Authorization` ausente |
| 2 | 401 | `API_KEY_INVALID` | `INVALID_API_KEY` | Key no encontrada o no coincide hash |
| 3 | 401 | `API_KEY_FORMAT_INVALID` | (no listado) | Formato no `pk_live/test_*` |
| 4 | 403 | `PROVIDER_SUSPENDED` | ✓ igual | `IsActive=false` en `providers` |
| 5 | 403 | `FORBIDDEN_HOTEL` | `HOTEL_ACCESS_DENIED` | Hotel no asociado al provider O no existe |
| 6 | 403 | `INSUFFICIENT_PERMISSIONS` | (no listado) | Permiso insuficiente para operación |
| 7 | 400 | `VALIDATION_ERROR` | ✓ igual | Schema/tipos/length violations |
| 8 | 400 | `INVALID_JSON` | (no listado) | JSON malformado |
| 9 | 422 | `INVALID_DATE_RANGE` | (HTTP 400 doc previo) | `from > to`, span > 365 días |
| 10 | 422 | `UNKNOWN_ROOM_CODE` | `ROOM_NOT_FOUND` | `roomCode` no en catálogo |
| 11 | 422 | `UNKNOWN_RATE_CODE` | `RATE_NOT_FOUND` | `rateCode` no en catálogo |
| 12 | 422 | `UNKNOWN_MEAL_PLAN` | `MEALPLAN_NOT_FOUND` | `mealPlanCode` no en catálogo |
| 13 | 422 | `INVALID_OCCUPANCY` | (no listado) | Ocupación inválida |
| 14 | 413 | `PAYLOAD_TOO_LARGE` | ✓ igual | Body > 5 MB |
| 15 | 409 | `CONCURRENT_UPDATE` | (no listado) | Conflicto de concurrencia |
| 16 | 422 | `IDEMPOTENCY_KEY_REUSED` | ✓ igual | Same key + body diferente (capa 4) |
| 17 | 429 | `RATE_LIMIT_EXCEEDED` | ✓ igual | Token bucket vacío |
| 18 | 503 | `SERVICE_UNAVAILABLE` | ✓ igual | Masters caído + Unit/Person, o DB lock no adquirido |

✅ Checklist para conexión nueva:
- [ ] El conector entiende los 18 códigos reales y maneja cada uno apropiadamente
- [ ] **Códigos `UNKNOWN_*` (no `*_NOT_FOUND`)** y **`FORBIDDEN_HOTEL` (no `HOTEL_ACCESS_DENIED`)** son los reales
- [ ] El conector maneja `CONCURRENT_UPDATE` con reintento exponencial

### Warnings — emitidos como mensajes en pipeline (NO en enum `PushInErrorCode`)

⚠️ **Divergencia 12-may**: el doc previo listaba 10 warnings (`DATE_IN_PAST`, `DATE_RANGE_OVERLAP`, `INVALID_PRICE_MODEL`, `MISSING_PRICE`, `PRICE_EXCEEDS_THRESHOLD`, `CURRENCY_MISMATCH`, `OCCUPANCY_EXCEEDS_MAX`, etc.). En código real, esos **NO están en el enum**; viven distribuidos en **mensajes FluentValidation** y en lógica de `GenericIngestionService`. Verificar uno por uno antes de confiar en su existencia.

Checklist warnings esperados (a confirmar con código antes de usarlos):
- [ ] `DATE_IN_PAST` — rango parcialmente pasado
- [ ] `DATE_RANGE_OVERLAP` — misma key múltiples updates
- [ ] `INVALID_PRICE_MODEL` — modelo no soportado por hotel
- [ ] `MISSING_PRICE` — todos los precios null o 0
- [ ] `PRICE_EXCEEDS_THRESHOLD` — fuera de rango razonable
- [ ] `CURRENCY_MISMATCH` — currencyCode != hotel.CurrencyCode
- [ ] `OCCUPANCY_EXCEEDS_MAX` — totalPax > room.maxOccupancy

**Estructura warning** (cuando existan):
```json
{ "updateIndex": 3, "code": "UNKNOWN_ROOM_CODE",
  "message": "Room code 'XXXL' not found in hotel 14400",
  "field": "updates[3].roomCode" }
```

> Fuente: Plan v9 §5.8 + auditoría enum `PushInErrorCode` 12-may.

---

## 3. Endpoints (contrato fijo: 10, rutas reales auditadas 12-may)

| # | Método | Ruta REAL | Controller | Status |
|---|--------|-----------|------------|--------|
| 1 | POST | **`/api/v1/availability/delta`** | `GenericAvailabilityController.cs:58` | ⚠️ Doc previo decía `/api/v1/availability` sin `/delta` |
| 2 | POST | `/api/v1/availability/full-refresh` | `GenericAvailabilityController.cs:119` | ✓ |
| 3 | POST | `/api/v1/availability/close` | `GenericStateController.cs:51` | ✓ |
| 4 | POST | `/api/v1/availability/open` | `GenericStateController.cs:110` | ✓ |
| 5 | GET  | `/api/v1/messages/{messageId:long}/status` | `GenericStatusController.cs:47` | ✓ |
| 6 | GET  | `/api/v1/availability/verify` | `GenericVerifyController.cs:50` | ✓ (lee Postgres directo, D4) |
| 7 | GET  | `/api/v1/hotels/{hotelId:long}/configuration` | `GenericConfigurationController.cs:16` | ✓ |
| 8 | GET  | **`/ping`** (sin `/api/v1`) | `HealthController.cs:71` | ⚠️ Doc previo decía `/api/v1/ping`. Sin prefix → se salta auth middleware (línea 147 ShouldSkip) |
| 9 | GET  | `/health` | `HealthController.cs:25` | ✓ |
| 10 | GET | `/health/ready` | `HealthController.cs:49` | ✓ |

✅ Checklist para conexión nueva:
- [ ] El conector NO llama a `/api/v1/availability` (no existe, es `/delta`)
- [ ] El conector usa `/ping` para health-check (no `/api/v1/ping`)
- [ ] El conector implementa retry sobre 503/429 respetando `Retry-After`
- [ ] El conector consume `/api/v1/availability/verify` para diagnóstico (es slow path, no usar en hot path)

**Headers comunes en respuestas**:
```
X-RateLimit-Limit: 500
X-RateLimit-Remaining: 487
X-RateLimit-Reset: 1712764860
X-Correlation-Id: {uuid}
X-Idempotency-Replayed: true     (solo si match)
Retry-After: 5                    (si 503/429)
```

> Fuente: Plan v9 §5 + auditoría 12-may.

---

## 4. Integración con PerlaHub

### Gateway: `IAvailabilityManagementGateway` (firmas REALES 12-may)

Namespace: `Utils.Gateways.AvailabilityManagement`. Archivo: `IAvailabilityManagementGateway.cs`. **Firmas auditadas 12-may** — divergen del doc previo:

| Operación REAL | Línea | Firma exacta | Doc previo decía |
|----------------|-------|--------------|------------------|
| `BulkUpsertAsync` | 11-14 | `Task<BulkUpdateResultDto> BulkUpsertAsync(string providerCode, List<NormalizedAvailabilityDto> items, CancellationToken)` | ✓ existe |
| `DeleteByProvider` | 51 | `DeleteByProvider(string providerCode, long hotelId)` | doc decía `DeleteByRange(provCode, hotelId, from, to)` — **rango no en firma** |
| `GetByIdsAsync` | 65-100 | `Task<List<AvailabilityDto>> GetByIdsAsync(List<Guid> ids, CancellationToken)` | doc decía `GetByProvider(...)` — **otra firma** |
| `ConsumeAvailabilityAsync` | 24 | (no documentado en doc previo) | — |
| `RestoreAvailabilityAsync` | 28 | (no documentado en doc previo) | — |
| `ResolveAvailabilityIdsAsync` | 32 | (no documentado en doc previo) | — |
| `UpdateAllotment` | 57 | (no documentado en doc previo) | — |

❌ **`BulkSetClosedAsync` NO existe** como operación pública en la interfaz. Close/Open posiblemente se hacen vía `UpdateAllotment` o internamente con `ExecuteUpdateAsync`. Verificar con Pedro.

✅ Checklist para conexión nueva:
- [ ] El conector escribe SOLO a través de `IAvailabilityManagementGateway` (no acceso directo a tabla)
- [ ] Si necesita Close/Open, confirmar con Pedro el método correcto (NO existe `BulkSetClosedAsync` público)
- [ ] Si consume disponibilidad post-booking, usar `ConsumeAvailabilityAsync` / `RestoreAvailabilityAsync`

### Tabla destino: `availability.normalized_availability` + `availability.availability_price`

**Campos `NormalizedAvailability`**:
```
Id (Guid), ProviderCode, HotelId (long), RoomCode, RateCode,
Date (DateOnly), RoomsToSell (int), ReleaseDate (int),
MinimumStay, MaximumStay?, IsClosed, ClosedToArrival?, ClosedToDeparture?,
MaxOccupancy [de Masters, NO del provider], CurrencyCode,
MetadataJson (JSONB), Version (concurrency token)
```

**Campos `AvailabilityPrice`** (1:N):
```
MealPlanCode, MinStayBasedRate (1=default, 3=3+ noches), TotalPax,
AgeRangesJson [{MinAge, MaxAge}, …], TotalPrice (decimal),
BabyCountsAsOccupancy (bool)
```

### Cache (estado REAL 12-may)

🚨 **El doc previo describía 5 claves Redis con prefijo `pushin:*`. NINGUNA existe en código real** (`grep -rn "pushin:" /PerlaPush` → sin resultados).

Realidad implementada:
- **Idempotencia**: `ConcurrentDictionary` in-memory (`IdempotencyMiddleware.cs:24`). NO Redis.
- **Rate limit**: `ConcurrentDictionary` in-memory (`RateLimitMiddleware.cs:20`). NO Redis.
- **Auth cache**: NO implementado en Redis (valida contra DB cada vez, o cache local en middleware).
- **Hotel config cache**: NO en código de `AvailabilityIngestion/` (documentado solo en Plan v9, no implementado).

✅ Checklist para conexión nueva:
- [ ] **AVISO**: idempotencia y rate limit NO persisten entre reinicios ni entre instancias en clúster
- [ ] El conector asume que el servicio backend es single-instance o que pérdida de idempotencia es aceptable
- [ ] Si conector requiere idempotencia distribuida real, escalar a Pedro como GAP a resolver antes de go-live

### Bugs históricos en cache (estado REAL 12-may)

| Bug | Doc previo | Estado real | Acción |
|-----|-----------|-------------|--------|
| BUG-1: hardcode `"EUR"` en lugar de `item.CurrencyCode` | "NO repetir" | **VIVO** en `AvailabilityManagement.Application/Services/AvailabilityService.cs:819` y `DiagnosticsController.cs:66, 90` | Fix antes de SiteMinder/Avoris go-live |
| BUG-2: hardcode `ReleaseDate=0` en lugar de `item.ReleaseDate` | "NO repetir" | **VIVO** en `AvailabilityService.cs:820` y `DiagnosticsController.cs:65, 89` | Fix antes de go-live |
| BUG-3: no escribir `ClosedToArrival` | "NO repetir" | ✓ Fixed (`AvailabilityService.cs:579-582` escribe correctamente) | OK |

✅ Checklist obligatorio:
- [ ] Tu conexión NO replica BUG-1 ni BUG-2 (verificar en su mapper)
- [ ] Reportar a Pedro que BUG-1/BUG-2 siguen vivos en path de diagnostics/fallback (aunque no en hot path principal)

> Fuente: Plan v9 §14 + auditoría 12-may en `AvailabilityService.cs` y `DiagnosticsController.cs`.

### Decisión crítica D4: `/verify` lee Postgres directo, no Redis
> ✓ Confirmado en código: `GenericVerifyController.cs:54-80` llama a `_mastersPushGateway` directo, sin cache. Latencia extra (10-50ms vs 1-5ms) es irrelevante para diagnóstico.

---

## 5. Qué cambia entre conexiones (Modo A vs Modo B)

| Aspecto | Modo A (Generic, CNBooking, GNA) | Modo B (Dingus, SiteMinder) |
|---------|----------------------------------|------------------------------|
| Formato entrada | JSON (nuestro contrato) | Custom (XML, SOAP, propietario) |
| Quién adapta | El provider | Nosotros (nuevo adapter) |
| Auth | Bearer HMAC stateless | En-banda XML / credenciales custom |
| Parser | No hay (passthrough validado) | `IProviderAdapter` específico |
| Validador | FluentValidation genérico | FluentValidation + parser-specific |
| Endpoints expuestos | Los 10 estándar | Los 10 estándar (mismo dispatcher) |
| Cómputo precio | `OccupancyPriceCalculator` (compartido) | Igual (compartido) |
| Gateway destino | `IAvailabilityManagementGateway` | Igual |
| Modelo destino | `NormalizedAvailability` | Igual |
| Rate limiting | Token bucket Redis | Heredado vía dispatcher |
| Idempotencia | `X-Idempotency-Key` Redis | Heredado vía dispatcher |

**Código que se reutiliza siempre** (no se reescribe, auditado 12-may):
- `IAvailabilityManagementGateway` (escritura a PerlaPush) — firmas en §4
- `NormalizedAvailability` (modelo DB) — §5
- Las 7 capas (middleware en `Ingestion.Generic.Api/Middleware/`)
- El catálogo de 18 errores (no 20)
- Los 10 endpoints

⚠️ **`OccupancyPriceCalculator` NO existe como clase discreta** (auditoría 12-may, no se encontró archivo). El cálculo de precios por ocupación está distribuido en `GenericIngestionService` y DTOs. Si una conexión nueva necesita lógica custom de precio por ocupación, replicar el patrón existente sin crear duplicación.

**Adapters REALES en código** (auditado 12-may):
- `DingusAdapter` (`Ingestion.Dingus.Api/Adapters/DingusAdapter.cs:18`) — Modo B, XML
- `SiteMinderAdapter` (`Ingestion.SiteMinder.Api/Adapters/SiteMinderAdapter.cs`) — Modo B, SOAP/XML
- `GenericAdapter` (`Ingestion.Generic.Api/Adapters/GenericAdapter.cs:18`) — Modo A, JSON

⚠️ `AllbedsAdapter` y `CNBookingAdapter` mencionados en docs/memorias **NO existen en código actual**. Si las conexiones existen en PROD, viven en otra forma (¿endpoints custom?, ¿integraciones externas?). Verificar con Pedro.

**Interfaz**: `IProviderAdapter` (`AvailabilityIngestion.Domain/Services/IProviderAdapter.cs:1-25`):
```csharp
public interface IProviderAdapter {
    string ProviderCode { get; }
    IReadOnlyList<string> Warnings { get; }
    Task<List<NormalizedAvailabilityDto>> NormalizeAsync(string rawPayload, CancellationToken);
    bool CanHandle(string rawPayload);
}
```

**Lo único nuevo en Modo B**: una clase `XxxAdapter : IProviderAdapter` que parsea el formato externo y produce `NormalizedAvailabilityDto`.

---

## 6. Scoring de complejidad (propuesta v0, calibrar con Pedro)

Por cada conexión nueva, evaluar en estos ejes (0-3 cada uno):

| Eje | 0 | 1 | 2 | 3 |
|-----|---|---|---|---|
| **Formato entrada** | JSON estándar (Modo A) | JSON con extensiones | XML estándar | XML/SOAP propietario |
| **Modos de precio** | Solo Unit | Unit + Person | + Occupancy | + custom variants |
| **Auth** | Bearer | OAuth2 token endpoint | Bearer + IP whitelist | SOAP+HMAC legacy |
| **Validaciones business custom** | Ninguna | 1-3 reglas extra | 4-8 reglas extra | 9+ reglas extra |
| **Full-refresh** | Endpoint separado | Flag explícito | Condicional schema | Implícito/ausente |
| **Volumen mensajes** | < 1 Dingus | 1-3 Dingus | 3-10 Dingus | > 10 Dingus |

**Score total**:
- **0-5**: **Bajo** (2-3 días para adapter funcionando E2E). Modo A es siempre 0-3.
- **6-11**: **Medio** (1 semana). SiteMinder level.
- **12-18**: **Alto** (2+ semanas). Dingus/legacy level.

> Este score alimenta la Fase 1 de la Skill (informe pre-conexión) y la **Calculadora de carga** del briefing.

---

## 7. Checklist de onboarding por conexión nueva

Antes de empezar Fase 1 de la Skill, el provider debe responder:

1. ¿Formato? (JSON nuestro / JSON propio / XML / SOAP / Custom)
2. ¿Quién adapta? (ellos → Modo A / nosotros → Modo B)
3. ¿Autenticación? (Bearer / OAuth2 / Basic / Custom HMAC)
4. ¿Campos obligatorios en SU payload? (lista exhaustiva)
5. ¿Modelos de precio? (Unit / Person / Occupancy / Combinación)
6. ¿Full-refresh? (Soportado / Cómo se marca)
7. ¿Rate limiting? (Sus límites; nuestros 500 req/min/provider por defecto)
8. ¿Idempotencia? (Soportada / Cómo)
9. ¿Discovery endpoints? (Pueden consumir nuestro `/verify` y `/configuration`?)
10. ¿Async path? (Toleran `202 + polling /messages/{id}/status`?)

---

## 8. Decisiones críticas que no se vuelven a discutir (estado REAL 12-may)

| ID | Decisión | Razón | Estado código |
|----|----------|-------|---------------|
| D1 | Idempotencia con body fingerprint SHA256 | Stripe/Square pattern. Detecta same-key body-different. | ✓ Implementado (`IdempotencyMiddleware.cs:139-143`) pero in-memory, no Redis |
| D2 | Full-refresh sobrescribe **TODO** incluyendo cierres previos | Provider es verdad absoluta. No existe override manual interno. | ✓ Confirmado (`GenericAvailabilityController:119-157`) |
| D3 | `minStayBasedRate` es nombre **definitivo** v1 | Nosotros definimos formato. No deuda de rename. | ✓ `AvailabilityPrice.cs:36` `MinStayBasedRate` (PascalCase .NET) |
| D4 | `/verify` lee **Postgres directo**, NO Redis | Post-202 cache aún no escrito. Diagnóstico precisa fuente de verdad. | ✓ Confirmado (`GenericVerifyController:54-80`) |
| D5 | HMAC server-secret rotation: **fuera de scope** Push In | Es transversal a PerlaHub. Plan global de seguridad. | ⚠ N/A en AvailabilityIngestion |
| D6 | Datos zombis: **job nightly alerta**, NO auto-purge | Auto-purge al activar nueva asociación es peligroso. Operador decide vía `/purge-provider`. | **❌ NO IMPLEMENTADO** — job nightly no existe en código. Pendiente |

✅ Checklist:
- [ ] Cualquier mismatch que toque D1-D6 → HITL #4 obligatorio en el briefing
- [ ] **D6**: aceptar el riesgo de datos zombis post-cambio de asociación O implementar job nightly antes de go-live

> Fuente: `inputdata/pushin/pushin-decisiones-feedback-francesc-v9.md` + `knowledge/perlatours/productos/perlapush/pushin-generico-decisiones-diseño.md` + auditoría 12-may.

---

## 9. Cómo lo usa la Skill (Factory Push)

En **Fase 1** (Análisis de documentación) la Skill produce el informe contra este contrato:

1. Mapear cada campo del provider a un campo del recipiente (`NormalizedAvailability` / `AvailabilityPrice`).
2. Marcar mismatches: directo / conocido / nuevo.
3. Por cada capa de validación (1-7), evaluar: ¿qué tiene que adaptar el adapter para que el request entre limpio?
4. Asignar scoring de complejidad (§6).
5. Identificar endpoints del proveedor (Modo B) que se mapean a nuestros 10.
6. Identificar warnings esperados (capa 6 mapping) según completitud del catálogo del hotel.

En **Fase 3** (Mock Tests) la Skill genera tests para los 10 casos del Anexo C del Skill, **cada uno tocando ≥1 capa**:
- Caso 1 (full snapshot) → capas 1+2+3+5+6+7.
- Caso 6 (mensaje duplicado) → capa 4.
- Caso 7 (burst) → rate limit (RATE_LIMIT_EXCEEDED).
- Caso 8 (hotel no registrado) → capa 2 + alarma "quién empieza primero" (Capa 3 del briefing, mapeo).
- Caso 9 (campo extra desconocido) → capa 3 forward-compat.
- Caso 10 (shape inválido) → capa 3.

En **Fase 4** (Match/Dismatch) la Skill clasifica cada mismatch contra el catálogo conocido (Anexo D del Skill). Cualquier mismatch que toque una de las 6 decisiones críticas (D1-D6) → HITL #4 obligatorio.

---

## 10. Referencias

### Módulos del repo PerlaPush que toca Factory Push (auditado 12-may)

| Módulo | Qué hace | Capa que toca |
|--------|----------|---------------|
| `AvailabilityIngestion/` | API de entrada: 10 endpoints + middleware 7 capas + adapters | Capas 1-7 (núcleo Factory Push) |
| `AvailabilityIngestion/Adapters/` | DingusAdapter, SiteMinderAdapter, GenericAdapter (nuevo adapter va aquí) | Capa 3 (shape) |
| `AvailabilityManagement/` | Persistencia: tablas `availability.normalized_availability` + `availability.availability_price` + servicios | Capa 7 |
| `AvailabilityQuery/` | API de lectura: consumer downstream (consultas Search/Book/Cancel para PerlaHub) | Tangencial — consumer |
| `Masters/` | Catálogo maestro de hotels/rooms/rates/mealplans | Capa 6 (mapping) — CRÍTICO |
| `MastersPush/` | Configuración providers, api keys, asociaciones hotel-provider | Capas 1-2 (auth/tenant) — CRÍTICO |
| `MastersContract/` | Contratos de POs desde partners | Fuera scope Factory Push |
| `Contracts/` | Grid visual de disponibilidad | Tangencial — consumer |
| `PushOut/` | Export/push a sistemas externos | **Probable Factory Pushout futura** |
| `Reservations/` | Flujo de reservas entrantes | Tangencial — consumer indirecto |
| `Utils/` | Gateways compartidos (`IAvailabilityManagementGateway`, `IMastersPushGateway`), DTOs | Capa 7 + auth |

### Docs y memorias relacionados

| Archivo | Qué tiene |
|---------|-----------|
| `inputdata/pushin/pushin-generico-plan-tecnico-v9.md` | Plan v9 completo (1657 líneas) — fuente principal |
| `knowledge/perlatours/productos/perlapush/pushin-generico-decisiones-diseño.md` | 418 líneas decisiones cerradas |
| `inputdata/pushin/pushin-decisiones-feedback-francesc-v9.md` | Feedback Francesc D1-D6 (126 líneas) |
| `inputdata/pushin/pushin-generico-auditoria-40-agentes-consolidado.md` | Auditoría 40 agentes |
| `knowledge/perlatours/integraciones/cnbooking_conexion_directa.md` | Conector Modo A (CNBooking) — **adapter no presente en código actual** |
| `knowledge/perlatours/integraciones/allbeds_conexion.md` | Conector Modo A (Allbeds) — **adapter no presente en código actual** |
| `inputdata/dingus/push_payloads/` | Payloads XML reales Dingus (Modo B referencia) |
| `factory_push_briefing_v0.md` | Briefing padre |
| `push-skill-2026-05-11.md` | Skill ejecutable v0 |
| `../factory_pull/factory_pull_validaciones.md` | Doc simétrico Pull |

---

## 11. CHECKLIST FINAL — Definition of Done por conexión nueva

Recoge todos los items ✅ de las 7 capas + decisiones + bugs en una única lista. Solo se mergea cuando TODOS están marcados o documentadamente justificados.

### 🔐 Capa 1 — Auth (HMAC + provider activo)
- [ ] Provider dado de alta en MastersPush con `IsActive=true`
- [ ] API key generada (`pk_live_*` o `pk_test_*` 40 chars)
- [ ] Hash HMAC-SHA256 almacenado en `masters_push.providers.api_key_hash`
- [ ] El conector envía `Authorization: Bearer pk_*` correctamente
- [ ] Tolerancia a 3 códigos 401 distintos: `API_KEY_MISSING`, `API_KEY_INVALID`, `API_KEY_FORMAT_INVALID`

### 🏨 Capa 2 — Tenant
- [ ] Asociaciones hotel-provider creadas en `masters_push.provider_hotel_associations` con `is_active=true`
- [ ] Constraint UNIQUE por hotel respetada (un solo provider activo por hotel)
- [ ] El conector entiende `FORBIDDEN_HOTEL` (no `HOTEL_ACCESS_DENIED`)

### 📦 Capa 3 — Shape
- [ ] Adapter (si Modo B) implementa `IProviderAdapter` con `NormalizeAsync`
- [ ] Payload ≤ 5 MB, depth ≤ 32
- [ ] Fechas ISO 8601, currency ISO 4217 3 chars
- [ ] Length caps respetados (roomCode≤200, rateCode≤200, mealPlanCode≤50, metadataJson≤10000)

### 🔁 Capa 4 — Idempotencia
- [ ] El conector envía `X-Idempotency-Key` en POSTs reintentables
- [ ] **AVISO**: idempotencia es in-memory (no Redis). Aceptar gap O escalar a Pedro

### 📐 Capa 5 — Business rules
- [ ] `from ≤ to`, span ≤ 365 días
- [ ] `roomsToSell ≥ 0`, `minimumStay ≤ maximumStay`
- [ ] `price > 0` o aceptar warning `MISSING_PRICE`
- [ ] `totalPax ≤ room.maxOccupancy`
- [ ] Close/Open: `roomCodes` explícito
- [ ] Expansion guard: `SUM(dateSpan × mealPlanCount) ≤ 10000`

### 🗺️ Capa 6 — Mapping (contra Masters)
- [ ] Masters poblado: hotel + rooms + rates + mealplans + currency + ageConfiguration
- [ ] Errores `UNKNOWN_ROOM_CODE` / `UNKNOWN_RATE_CODE` / `UNKNOWN_MEAL_PLAN` tolerados por el conector
- [ ] `currencyCode == hotel.CurrencyCode` validado
- [ ] Resiliencia Masters: tolera 503 si Masters caído + modelo Unit/Person

### 💾 Capa 7 — Persistencia
- [ ] El conector usa `BulkUpsertAsync` para delta y `/full-refresh` para reset
- [ ] Close/Open: confirmar método con Pedro (no hay `BulkSetClosedAsync` público)
- [ ] El conector entiende `CONCURRENT_UPDATE` (HTTP 409) y reintenta
- [ ] `DATE_RANGE_OVERLAP` → last-writer-wins documentado al provider

### 📜 Decisiones D1-D6
- [ ] D1 SHA256 body fingerprint verificado (in-memory, no Redis)
- [ ] D2 full-refresh sobrescribe TODO entendido
- [ ] D3 `MinStayBasedRate` nombre estable
- [ ] D4 `/verify` lee Postgres directo (no cache)
- [ ] D6: aceptar riesgo datos zombis o implementar job nightly

### 🐛 Bugs históricos
- [ ] Tu adapter NO replica BUG-1 (`"EUR"` hardcoded) — **gap vivo** en `AvailabilityService.cs:819` y `DiagnosticsController.cs:66, 90`. Reportar a Pedro
- [ ] Tu adapter NO replica BUG-2 (`ReleaseDate=0` hardcoded) — **gap vivo** en `AvailabilityService.cs:820` y `DiagnosticsController.cs:65, 89`. Reportar a Pedro
- [ ] BUG-3 (no escribir `ClosedToArrival`) ya fixed

### 📊 Métrica DoD
- [ ] **% rejects por shape < 2%** durante 7 días tras go-live (métrica específica Push)
- [ ] Score compatibilidad + complejidad adapter (§6) registrado pre-go-live
- [ ] 10 casos estándar del Skill Anexo C pasan en mock tests

---

## Pendientes v1 (actualizados 12-may)

1. Calibrar pesos del scoring (§6) con Pedro
2. Definir `maxReasonablePrice` per-provider (warning `PRICE_EXCEEDS_THRESHOLD` — pendiente confirmar si existe en código)
3. Definir N días en DoD del briefing (decisión equipo)
4. Llenar Anexo D del Skill con mismatches de Dingus como caso 0
5. Decidir Modo A vs B en calculadora de complejidad
6. **CRÍTICO**: decidir con Pedro si migrar idempotencia + rate limit a **Redis distribuido** antes de SiteMinder/Avoris go-live, o aceptar el gap (single-instance)
7. **CRÍTICO**: fix BUG-1 y BUG-2 vivos en `AvailabilityService.cs:819-820` y `DiagnosticsController.cs:65-66, 89-90`
8. **CRÍTICO**: implementar job nightly D6 o aceptar formalmente el gap
9. Aclarar mecanismo real de Close/Open (no hay `BulkSetClosedAsync` público en gateway)
10. Verificar warnings que el doc previo listaba (`DATE_IN_PAST`, `MISSING_PRICE`, etc.) — confirmar si están implementados en FluentValidation o solo documentados
11. Confirmar dónde viven `AllbedsAdapter` y `CNBookingAdapter` si las conexiones están en PROD (no están en código de PerlaPush actual)
