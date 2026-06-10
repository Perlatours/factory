---
title: Factory Pull — Validaciones de PerlaHub (checklist por conexión nueva)
date: 2026-05-12
source: BookingFlow PerlaHub real + auditoría /Users/santiagopatinoserna/Documents/PerlaHub + análisis 665 reservas 96.24% success
parent: factory_pull_briefing_v0.md
tags: [factory, pull, rebuyers, validaciones, perlahub, booking-flow, checklist, contrato-fijo]
status: v0.1-12may-checklist-anclado-codigo
history: v0 11-may (extracción inicial); v0.1 12-may (corregido contra repo real, enfoque checklist reforzado)
---

# Factory Pull — Validaciones de PerlaHub

> **Cómo se usa este doc**: es la **checklist accionable** que cada conexión Pull nueva tiene que recorrer antes de mergear. Cada capa, endpoint, enum, decisión y bug = un ítem ✅/❌. NO es descripción pasiva del sistema.

## TL;DR

Cuando un conector Pull entrega respuestas al pipeline `search → prebook → book → cancel`, **PerlaHub aplica 9 grupos de validación** (NO son un middleware secuencial único — son validaciones distribuidas en BookingFlow + Audit + Mapping + Partners; el orden lógico se respeta). Lo que el conector debe garantizar es simétrico al doc Push, pero invertido: aquí el conector produce el dato; PerlaHub valida e ingesta.

**Contrato fijo de PerlaHub para Pull (auditado 12-may contra repo):**
- **9 grupos de validación** (auth → shape → mapping → precio → cancel → rateKey → state machine → audit → cache)
- **11 endpoints reales** (rutas `/api/...`, NO `/PerlaAdmin2/...`) — el doc previo decía 12 pero `InsertRateCodeMapping` NO existe
- **6 conectores Accommodation reales**: Dome, Expedia, Hotelbeds, Travelgate, PerlaPush, PushInternal (parcial). **Avoris NO existe** como conector en código (kickoff sin código).
- **6 estados** `BookingFlowStatus` (enum literal en `Utils/ModelDomain/Common/Enum/BookingFlowStatus.cs`)
- **18 AuditTypes** (enum literal 0-17 en `Utils/ModelDomain/Audit/AuditType.cs`) — el doc previo decía "20+"
- **6 decisiones P1-P6** que no se vuelven a discutir

Lo que **cambia entre conexiones Pull** es solo el conector (parser + auth saliente). El recipiente interno es único.

> Este doc es el simétrico de `../factory_push/factory_push_validaciones.md`. Es la **garantía de no-regresión** para cada nueva conexión Pull.

---

## 1. Los 9 grupos de validación (orden lógico — distribuidos en código)

> ⚠️ **No son un middleware secuencial único**. Son validaciones distribuidas en `BookingFlow/Application/{Search,Prebook,Book,Cancel}Service.cs`, `Partners/`, `Audit/`, `Mapping/`, etc. El orden lógico se respeta. Tu conector tiene que cumplir cada grupo en su capa correspondiente.

### Capa 1 — Auth + Autorización de credencial
**Ubicación código**: `Partners/` (módulo de credenciales), `[Authorize]` en `BookingFlow/Api/Controllers/BookingController.cs:16`.

✅ Checklist:
- [ ] `ClientCredential` activa (`isActive=true` en `partners.client_credentials`)
- [ ] JWT válido (sesión o permanent token via `POST /PartnersManage/ClientCredential/{id}/generate-permanent-token`)
- [ ] `AuthorizedProductSources` del cliente incluye el nuevo conector (registro en Partners)
- [ ] Config en L2 Redis: `ClientCredentialConfig` (distributions, markets, currencies, nationalities, excludedHotels). Verificar que `applyConfig` se ejecuta tras alta
- [ ] Mercados/nationalities permitidos del conector ⊇ los del cliente (caso bug `TravelCode market=BY` → rechazo pre-provider)

**Errores**: HTTP 401 `INVALID_CREDENTIALS` · HTTP 403 `CREDENTIAL_UNAUTHORIZED_FOR_PROVIDER`.

> Fuente: `reference_perlahub_permanent_token.md`, `reference_perlaadmin_api.md`, módulo `Partners/`.

### Capa 2 — Shape del DTO de respuesta del conector
**Ubicación código**: `Connectors/Accommodation/{Provider}/Operations/{Op}/Rq|RsValidator.cs` por conector. Las interfaces canónicas viven en `Connectors/Core/Accommodation/Domain/` (`ICoreConnectorSearch`, `ICoreConnectorPrebook`, `ICoreConnectorBook`, `ICoreConnectorCancel`, `ICoreConnectorGetBookings`).

✅ Checklist:
- [ ] Estructura del JSON/XML del conector mapea a `SearchRs` / `PrebookRsDto` / `BookRsDto` / `CancelRsDto` (`Utils.ModelDomain.BookingFlow.Api.Dto.*`)
- [ ] Campos obligatorios presentes; tipos correctos (fecha ISO 8601, currency ISO 4217)
- [ ] Payload ≤ 5 MB · JSON depth ≤ 32
- [ ] El conector implementa **las 6 interfaces canónicas** (`ICoreConnectorSearch/Prebook/Book/Cancel/GetBookings` + Static); GetBookings es opcional pero recomendado

**Errores**: HTTP 400 `VALIDATION_ERROR` · HTTP 413 `PAYLOAD_TOO_LARGE`.

> Ver §3 más abajo (DTOs normalizados).

### Capa 3 — Mapping de IDs (cross-catalog)
**Ubicación código**: `Mapping/` (módulo) + controladores en `PerlaAdmin/Api/Controllers/Mapping/Mapping{Hotel,Room,MealPlan}Controller.cs`.

✅ Checklist:
- [ ] `hotelId` provider ↔ `masters.hotel_mappings` → Masters `Hotel.InternalCode` existe
- [ ] `roomCode` ↔ `masters.room_mappings` → `RoomType.InternalCode` existe
- [ ] `mealPlanCode` ↔ `masters.meal_plan_mappings`
- [ ] Currency ISO 4217 coincide con `Hotel.CurrencyCode`
- [ ] **Decisión P4** respetada: NUNCA inventar RoomTypes/RoomAmenities — solo catálogo real
- [ ] Mappings cargados ANTES de habilitar el conector para tráfico real

**Errores**: HTTP 404 `HOTEL_NOT_FOUND` · HTTP 422 `ROOM_NOT_FOUND` / `RATE_NOT_FOUND` / `MEALPLAN_NOT_FOUND` / `CURRENCY_MISMATCH`.

**Endpoints reales de carga** (rutas auditadas 12-may):
- `POST /api/mapping/InsertHotelMapping` (no `/PerlaAdmin2/...`)
- `POST /api/mapping/InsertRoomMapping`
- `POST /api/mapping/InsertMealPlanMapping`

⚠️ **`InsertRateCodeMapping` NO existe como endpoint** — los rate codes se mapean por otra vía (revisar `Mapping/` para entender ruta actual). Antes de asumir endpoint, verificar con Pedro.

### Capa 4 — Validación de precios
**Ubicación código**: `BookingFlow/Application/Book/BookService.cs:51-70` (MarkupService aplicado).

✅ Checklist:
- [ ] `price > 0` (nunca 0 ni negativo) en search/prebook/book
- [ ] Dentro de threshold razonable (configurable por provider)
- [ ] Modelo de precio declarado y consistente:
  - **Net** → PerlaHub aplica markup: `publicPrice = net × (1 + %markup_cliente)`
  - **Commissionable** → traer % comisión hotel
  - **PVP** → ya incluye comisión hotel. **NO se le aplica markup**. `neto = pvp × (1 − %comisión)` (Decisión **P2**)
- [ ] Taxes incluidas o separadas → declarar en el response
- [ ] Currency coincide con `hotel.CurrencyCode` (si no → warning `CURRENCY_MISMATCH`)
- [ ] Si el conector tiene casos con `pvpRequired:true` → NO omitir `room.price` (replica bug PDES-113 si lo haces). Workaround validado: `room.price=0` + `pvpAmount=0`

**Errores**: HTTP 400 `INVALID_PRICE` · HTTP 422 `PRICE_EXCEEDS_THRESHOLD` · HTTP 422 `INVALID_PRICE_MODEL`.

> Reglas: `POST /PartnersManage/PriceAdjustmentRule/GetList` (markups por cliente). Campos: `adjustment` (decimal: 0.10 = +10%), `channel`, `market`, `hotelCountry`, `serviceDayFrom/To`, `isOnlyRefundable`, `isOnlyPackage`.

### Capa 5 — Validación de políticas de cancelación
**Ubicación código**: Validadores en cada conector (`Connectors/Accommodation/{Provider}/Operations/Cancel/`).

✅ Checklist:
- [ ] Formato: array de tramos con **importe** por tramo — canónico PerlaHub = `amount`; el adapter convierte % y noches → importe (corrección Pedro 18-may)
- [ ] **Decisión P5** respetada: deadlines guardados en UTC; el conector convierte el offset fijo del provider (p.ej. GMT+1) a UTC. Sin IANA per-hotel (PerlaHub guarda UTC).
- [ ] Flag `refundable` **general** presente (true si en algún momento se puede cancelar sin coste; NO por tramo) — PerlaHub NO pide flag "modificable"
- [ ] Flag non-refundable presente
- [ ] Fechas no en el pasado, no ultra-futuro
- [ ] Si conector entrega tramos solapados → última gana (last-writer-wins, documentar comportamiento)

**Errores**: HTTP 400 `INVALID_CANCELLATION_POLICY` · HTTP 422 `CANCELLATION_POLICY_TIMEZONE_ERROR`.

### Capa 6 — RateKey lifecycle + TTL + idempotencia book
**Ubicación código**: `BookingFlow/Application/Book/BookService.cs:67-70` (validación price changed).

✅ Checklist:
- [ ] `rateKey` presente y no expirado (TTL típico: HB 30min, Expedia 10min, Travelgate/Avoris variable)
- [ ] **Idempotencia book**: reintento con misma `clientReference` NO duplica reserva
- [ ] **Price changed**: si delta book vs prebook > threshold (típico ±5%), rechazar o revalidar
- [ ] El conector NO emite `BookRs 200 OK sin booking.id` (incidente TGX 17-mar-2026, 6 fallos multi-cliente)
- [ ] Si replicas patrón Dome (E9MRSZUV) — rooms no actualizando precio en prebook — habilitar el recálculo proporcional ya implementado en `BookService`
- [ ] TraceId mantiene continuidad search→prebook→book (no replicar audit gap cred 43)

**Errores**: HTTP 410 `RATEKEY_EXPIRED` · HTTP 409 `PRICE_CHANGED` · HTTP 422 `DUPLICATE_BOOKING`.

### Capa 7 — BookingFlow state machine
**Ubicación código**: enum literal en `Utils/ModelDomain/Common/Enum/BookingFlowStatus.cs`. ⚠️ NO existe máquina de estados explícita en código — las transiciones se aplican en `BookingFlow/Application/{Book,Cancel}Service.cs` ad-hoc.

✅ Checklist:
- [ ] `BookingFlow` existe en `bookingFlow.booking_flow` y está en estado permitido
- [ ] Los 6 estados del enum se respetan: `BOOKED=1` · `CANCELLED=2` · `ERROR=3` · `SIMULATED=4` · `CLOSED=5` · `BILLED=6`
- [ ] Estado `CONFIRMED` literal del provider → mapear a `BOOKED` (NO existe en PerlaHub)
- [ ] Transiciones permitidas: `BOOKED → CANCELLED/CLOSED/BILLED` · `ERROR → BOOKED (retry)`. Terminales: `CANCELLED · SIMULATED · CLOSED · BILLED`
- [ ] No duplicar booking con mismo `clientReference`

**Errores**: HTTP 409 `INVALID_STATE_TRANSITION` · HTTP 400 `BOOKING_ALREADY_EXISTS`.

> **Endpoint enum real** (auditado 12-may): `GET /api/enum/BookingFlowStatuses` en `PerlaAdmin/Api/Controllers/EnumController.cs:42` (PROD: 6 valores). El doc previo decía `/PerlaAdmin2/Enum/...` — ruta incorrecta. Doc obsoleta `_doc/APIs/Inventory/Enum/EnumController_API_Documentation.md` lista solo 4 (falta CLOSED + BILLED).

### Capa 8 — Audit / Trazabilidad obligatoria
**Ubicación código**: microservicio **separado** `Audit/` (no estaba documentado como tal antes) + `Audit/Application/AuditService.cs`. Controllers en `PerlaAdmin/Api/Controllers/Audit/AuditController.cs`.

✅ Checklist:
- [ ] Toda operación se registra con un `TraceId` (UUID único) en `bookingFlow.audit_metadata`
- [ ] Referencias en `bookingFlow.audit_references` (TraceId + AuditType + ReferenceId + AssetId + ExceptionType)
- [ ] Payload almacenado en S3/MinIO: `audit/{AuditType}/{guid}.json`
- [ ] El conector emite Connector*Rq y Provider*Rq con TraceId consistente (no replicar audit gap cred 43)
- [ ] **El `Gateway` del conector pasa un `AddAuditRq` al `HttpRequestBuilder.SendAsync(config, auditRq)` — NO `null`** (es lo que genera el `Provider*Rq`). Captura de `providerParameters`: `AuditConfigId`, `SystemUserToken`, `ProviderConnectionId`; `AuditType` por operación; header `AuditAuthorization` = `SystemUserToken`. **Patrón de referencia: `Connectors/Accommodation/Hotelbeds/Operations/Common/Gateway.cs`**

> ⚠️ **El audit del provider lo emite el CONECTOR, no el Core** (mismo encuadre que P7 con el mapping). El Core/`HttpRequestBuilder` solo persiste lo que reciba; si el `Gateway` llama `SendAsync(config, null)` **no se registra nada del provider** y el fallo es silencioso (la API levanta y responde 200 igual). Trampa real: en Avoris (fase 6, jun-2026) el `Gateway` se entregó con `auditRq = null` y el gap solo se detectó al probar el registro en local. **Verificar emisión real, no solo que "compila"**.

**`AuditType` enum REAL** (18 valores, 0-17, en `Utils/ModelDomain/Audit/AuditType.cs` — auditado 12-may; el doc previo decía "20+", error):
| ID | Tipo | Cuándo |
|----|------|--------|
| 0 | `LoginRq` | Login de credencial |
| 1 | `ClientSearchRq` | Search del cliente entrando |
| 2 | `ConnectorSearchRq` | Search transformado por conector |
| 3 | `ProviderSearchRq` | Search saliendo al provider |
| 4 | `ClientPrebookRq` | Prebook cliente |
| 5 | `ConnectorPrebookRq` | Prebook conector |
| 6 | `ProviderPrebookRq` | Prebook provider |
| 7 | `ClientBookRq` | Book cliente |
| 8 | `ConnectorBookRq` | Book conector |
| 9 | `ProviderBookRq` | Book provider |
| 10 | `ClientCancelRq` | Cancel cliente |
| 11 | `ConnectorCancelRq` | Cancel conector |
| 12 | `ProviderCancelRq` | Cancel provider |
| 13 | `BreakingRestriction` | Violación restricción (negocio) |
| 14 | `ClientGetBookingRq` | GetBooking cliente |
| 15 | `ConnectorGetBookingRq` | GetBooking conector |
| 16 | `ProviderGetBookingRq` | GetBooking provider |
| 17 | `Exception` | Captura errores en cualquier punto |

**Endpoints reales** (auditado 12-may): `POST /api/audit/GetTraces` · `POST /api/audit/GetReferences` · `POST /api/audit/GetPayload` (NO `/PerlaAdmin/audit/...` como decía doc previo). Filtros: `createdAtFrom/To`, `auditTypes[]`, `clientIds[]`, `credentialIds[]`.

> Fuente: `reference_perlaadmin_audit_api.md`.

### Capa 9 — Cache invalidation + consistencia
**Ubicación código**: `L1Cache.cs` (in-memory) + `RedisGateway.cs` (L2). Auditado 12-may.

✅ Checklist:
- [ ] El conector NO asume que L1 cache se invalida tras alta/cambio de hotel (bug abierto: tras activar hoteles, `search` devuelve `accommodations:[]` durante TTL 600s, no hay endpoint expuesto para invalidar L1)
- [ ] Tras alta del conector, ejecutar refresh L2:
  - `POST /api/Hotel/SetCache` (refresca L2 HotelInventory)
  - `PUT /api/ClientCredential/{id}/applyConfig` (refresca L2 ClientCredentialConfig)
  - Rebuyer `applyAfterUpdate=true` → `RefreshHotelsForCredentialAsync` → L2 CredentialHotels
- [ ] **Decisión P1** respetada: estáticos (hotel/room/meal names) siempre del Inventory local, nunca passthrough
- [ ] **Decisión P6** respetada: NO escribir PerlaHub PROD sin validación previa

**Realidad cache** (corrección 12-may vs doc previo):
- **L1** (`L1Cache.cs`): in-memory per-process, TTL 600s absoluto. Método `Invalidate(CustomCacheDatabase)` existe pero **NO está expuesto como endpoint HTTP** (bug abierto confirmado).
- **L2** (`RedisGateway.cs` con StackExchange.Redis): usa **database index numérico, NO key naming scheme con prefijo `pushin:*`**. Los keys `pushin:availability:{providerCode}:{hotelId}:{date}`, `pushin:hotel:{hotelId}` que el doc previo mencionaba son **del repo PerlaPush, NO de PerlaHub**. Borrar esa confusión.
- **Advisory locks PostgreSQL**: **NO implementados en PerlaHub**. El doc previo mencionaba `pg_try_advisory_xact_lock(hotelId)` — no existe en código. Probable confusión con PerlaPush.

**Errores**: HTTP 503 `SERVICE_UNAVAILABLE` (Redis caído, Masters caído).

---

## 2. Endpoints de PerlaHub relevantes para Pull (auditado 12-may)

| # | Método | Ruta REAL | Controller | Propósito | Auth |
|---|--------|-----------|------------|-----------|------|
| 1 | POST | `/Booking/search` | `BookingFlow/Api/Controllers/BookingController.cs:41` | Search consolidado multi-connector | JWT ClientCredential |
| 2 | POST | `/Booking/prebook` | `BookingController.cs:47` | Validar precio antes de book | JWT ClientCredential |
| 3 | POST | `/Booking/book` | `BookingController.cs:53` | Crear la reserva | JWT ClientCredential |
| 4 | POST | `/Booking/cancel` | `BookingController.cs:59` | Cancelar reserva | JWT ClientCredential |
| 5 | GET | `/api/enum/BookingFlowStatuses` | `PerlaAdmin/Api/Controllers/EnumController.cs:42` | Listar 6 estados | JWT PerlaAdmin |
| 6 | POST | `/api/audit/GetTraces` | `PerlaAdmin/Api/Controllers/Audit/AuditController.cs:23` | Listar trazas | JWT PerlaAdmin |
| 7 | POST | `/api/audit/GetReferences` | `AuditController.cs:29` | Referencias de traza | JWT PerlaAdmin |
| 8 | POST | `/api/audit/GetPayload` | `AuditController.cs:35` | Payload request/response | JWT PerlaAdmin |
| 9 | POST | `/api/mapping/InsertHotelMapping` | `PerlaAdmin/Api/Controllers/Mapping/MappingHotelController.cs:33` | Registrar mapping hotel | JWT PerlaAdmin |
| 10 | POST | `/api/mapping/InsertRoomMapping` | `MappingRoomController.cs:34` | Registrar mapping room | JWT PerlaAdmin |
| 11 | POST | `/api/mapping/InsertMealPlanMapping` | `MappingMealPlanController.cs:34` | Registrar mapping meal plan | JWT PerlaAdmin |

> ⚠️ **`InsertRateCodeMapping` NO existe** como controller dedicado en PerlaAdmin. Antes de asumir endpoint, verificar con Pedro la ruta real para cargar rate code mappings.
>
> ⚠️ El doc previo decía rutas con prefijo `/PerlaAdmin2/...` — **ruta histórica incorrecta**. Las rutas reales son `/api/...` (auditadas 12-may en `/Users/santiagopatinoserna/Documents/PerlaHub/`).

---

## 3. DTOs normalizados que PerlaHub espera del conector

### SearchResponse (connector → PerlaHub)
```json
{
  "hotel": {
    "id": "5482",
    "internalCode": "HTOP-AMATISTA",
    "name": "[se sobrescribe con Inventory local — P1]",
    "rooms": [
      { "code": "STD", "name": "[Inventory local]", "occupancy": 2, "amenities": [1,3,5] }
    ]
  },
  "options": [
    {
      "rateKey": "ABC123XYZ",
      "rateCode": "BB",
      "mealPlan": { "code": "BB", "name": "[Inventory local]" },
      "price": { "net": 180.50, "pvp": 200.00, "currency": "EUR", "taxes": 36.00 },
      "rooms": [
        { "code": "STD", "price": {...}, "occupancy": 1,
          "ageRanges": [{"minAge":0,"maxAge":120}] }
      ],
      "cancellationPolicy": [
        { "from":"2026-04-20T00:00:00Z", "to":"2026-05-19T23:59:59Z",
          "percent":100, "refundable":true }
      ],
      "pvpRequired": false
    }
  ]
}
```

### PrebookResponse
```json
{
  "rateKey": "ABC123XYZ",
  "price": { "net": 180.50, "pvp": 200.00, "currency": "EUR", "taxes": 36.00 },
  "cancellationPolicy": [...],
  "expiresAt": "2026-04-20T14:30:00Z"
}
```

### BookResponse
```json
{
  "confirmationNumber": "CONF-12345",
  "provider": "HTOP",
  "price": { "net": 180.50, "pvp": 200.00, "currency": "EUR" },
  "checkIn": "2026-05-20T14:00:00Z",
  "checkOut": "2026-05-25T11:00:00Z",
  "holder": { "name":"...", "email":"...", "phone":"..." },
  "roomAssignments": [ { "roomCode":"STD", "roomNumber":"201", "guestNames":["..."] } ],
  "cancellationPenalty": { "amount":50.00, "currency":"EUR",
                            "deadline":"2026-04-20T23:59:59Z" }
}
```

### CancelResponse
```json
{
  "cancellationId": "CANCEL-98765",
  "status": "CANCELLED",
  "refundAmount": 150.00,
  "currency": "EUR",
  "refundDeadline": "2026-05-30T00:00:00Z"
}
```

> **Decisión P1 aplicada**: los campos `name` de hotel/room/mealPlan en SearchResponse se **sobrescriben** con el Inventory local. Lo que envíe el provider en esos campos se ignora.

---

## 4. BookingFlowStatus — estados y transiciones

| ID | Estado | Significado | Transiciones permitidas |
|----|--------|-------------|--------------------------|
| 1 | `BOOKED` | Reserva confirmada en provider | → CANCELLED · CLOSED · BILLED |
| 2 | `CANCELLED` | Anulada | terminal |
| 3 | `ERROR` | Error en search/prebook/book/cancel | → BOOKED (retry) · CLOSED |
| 4 | `SIMULATED` | Test (no es real) | terminal |
| 5 | `CLOSED` | Cerrada por EOD/EOW | terminal |
| 6 | `BILLED` | Facturada | terminal |

> **Endpoint vivo**: `GET https://api.perlatours.com/PerlaAdmin2/Enum/BookingFlowStatuses`
> **CONFIRMED no existe** — es literal de provider, mapear a `BOOKED`.

---

## 5. Causas reales de fallo de booking (8 causas, 3.76% tasa)

Basado en análisis de 665 reservas oct-25 a abr-26 (96.24% éxito).

| # | Causa | Freq | Provider | Mensaje al cliente | Fix |
|---|-------|------|----------|--------------------|-----|
| 1 | TGX empty Locator (BookRs 200 OK sin ID) | 8/25 (32%) | TGX multi-conn | `Invalid Response` | GetBooking antes de marcar fallido + alerta operador |
| 2 | Timeout connector >60s | 4/25 (16%) | Dome (128/853/895/2208/2209) | `Connector Book response Error` | Subir timeout Book a 90-120s solo Dome |
| 3 | Dome: opción ya no disponible (ORA-20000) | 4/25 (16%) | Dome (Aurumtours 22-dic) | `Invalid Response` | Re-prebook auto o alerta |
| 4 | Prebook/Quote expiró | 3/25 (12%) | Traveltino | `Invalid Quote Response` | Cache prebook + validar TTL antes book |
| 5 | TGX insufficient allotment | 2/25 (8%) | TGX/SIDETOURS (CNBOOKING) | `Invalid Response` | Propagar "Sin disponibilidad" |
| 6 | Juniper SOAP error | 2/25 (8%) | Juniper (Traveltino) | `Invalid Response` | Mejorar parsing |
| 7 | PerlaHub rollback | 1/25 (4%) | Demo B2B | `Failed to complete booking, changes rolled back` | Investigar transacción DB |
| 8 | Expedia payment type no permitido | 1/25 (4%) | Expedia test | `Payment configuration error` | Configurar payment type |

**Hallazgo crítico**: **17/25 (68%) llegan al cliente como `Invalid Response` genérico**. La causa real solo se ve en audit. Mejora pendiente: propagar error específico al `errorMessages` del `ClientBookRq`.

> Fuente: `project_booking_errors_apr_2026.md`.

---

## 6. Bugs históricos en pipeline Pull (NO repetir — ítems de checklist)

Auditado 12-may. Cada fila = ítem ✅/❌ para tu nueva conexión.

| Bug | Provider | Descripción | Estado | Checklist para conexión nueva |
|-----|----------|-------------|--------|-------------------------------|
| L1 cache stale | PerlaHub | Tras activar hoteles, search retorna `accommodations:[]` durante TTL 600s. **NO hay endpoint expuesto** para invalidar L1 (verificado 12-may) | **Open** | [ ] Aceptar TTL 600s post-alta. Documentar al cliente. NO asumir invalidación on-demand |
| Dome price changed (E9MRSZUV) | Dome | Precio search 942.56 → prebook 994.93 por terceros. Rooms no actualizan precios | Fixed (terceros eliminados + recálculo proporcional en `BookService.cs:51-59`) | [ ] Si tu conector cambia precio entre search/prebook, garantizar recálculo proporcional de rooms |
| WHL/Albatravel pvpRequired (PDES-113) | TGX/WHL | 16/32 opciones omiten `room.price` con `pvpRequired:true` → NullRef | Fixed | [ ] NO omitir `room.price`; si no aplica, devolver `0` + `pvpAmount=0` |
| Travel Code market BY | Travel Code | Market/Nationality BY rechazado pre-provider | Bloqueado | [ ] Validar mercados/nationalities permitidos en Capa 1 antes de search |
| Aurum/Platja price changed | Dingus/Aurum | Book "price changed" + audit gap cred 43 + TGX drops errors + prebook TTL no validado | Investigating | [ ] Validar prebook TTL ANTES de book; emitir error específico si expiró |
| TGX drops errors | TGX | Errores ProviderBookRq no se propagan a ConnectorBookRq | Investigating | [ ] Propagar error específico al `errorMessages` del `ClientBookRq` (no `Invalid Response` genérico) |
| Audit gap cred 43 | Cross | Logs prebook no rastreables hasta booking (TraceId discontinúo) | Investigating | [ ] TraceId consistente search→prebook→book→cancel en cada AuditType |
| Expedia EPS IDs ≠ Content API IDs | Expedia | Mapping confunde IDs largos (Content `1064406…`) con cortos (EPS `17281`) | Fixed | [ ] Si conector tiene dos catálogos de IDs (content vs booking), declarar cuál se usa en mappings |
| Expedia mealPlan add-ons | Expedia | Connector mezcla 5 régimenes reales con 13 add-ons de tarifa | **Open** (ticket Pedro) | [ ] Distinguir régimenes vs add-ons explícitamente en mapping |

---

## 7. Decisiones críticas que NO se vuelven a discutir

| ID | Decisión | Implementación | Fuente |
|----|----------|-----------------|--------|
| **P1** | Estáticos siempre Inventory local, nunca passthrough | `SearchAggregator` sobrescribe hotel/room/meal names | `feedback_perlahub_statics_owned` |
| **P2** | PVP NO tiene markup, ya incluye comisión hotel. `neto = pvp × (1−%comisión)` | `OccupancyPriceCalculator` aplica % solo a Net | `feedback_pvp_no_markup` |
| **P3** | Re-mapping preserva matches PH↔nombre como oro, solo cambia target_id (external) | Bola nieve Expedia: preservar names PH, cambiar externalKey | `feedback_expedia_remap_strategy` |
| **P4** | NUNCA inventar RoomTypes/RoomAmenities — solo catálogo PerlaHub | Capa 3 reject si room no en Masters | `feedback_no_invent_perla_codes` |
| **P5** | Cancellation timezone: deadlines en UTC; conector convierte offset fijo del provider → UTC (sin IANA per-hotel) | `SpecifyKind(Utc)` + conector resta el offset (Avoris GMT+1 → −1h) | `project_contratos_timezone_decision` |
| **P6** | NO escribir PerlaHub PROD sin validación previa | Circuito: fetch list → validate → execute | `feedback_no_writes_to_ph_without_validation` |
| **P7** | El conector **NUNCA mapea identificadores de catálogo** (hotel/room/meal/amenity). El flujo solo **CABLEA**: copia el id del proveedor al campo canónico tal cual. El mapeo `id_provider→id_PH` es tarea **EXTERNA** del servicio de Mapping de PerlaHub, alimentado por el Inventory de PH + los estáticos consultables del proveedor (`IGetHotels/RoomTypes/MealPlans/RoomAmenities` → `{Id,Name}`) | search: `hotelCode→HotelId`, `rooms[].id→RoomTypeId`, `meal.id→MealPlanId`; mapeo en `Mapping/` (`InsertHotel/Room/MealPlanMapping`) | `feedback_connector_only_wires` (avoris-pull 2026-06-09) |

> Cualquier mismatch que toque P1-P7 → **HITL #3 obligatorio** (Paso 5 del proceso).

---

## 8. Cómo lo usa la Skill (Factory Pull)

**Paso 1 (Análisis)**: Skill produce el informe contra las 9 capas:
1. Mapear cada endpoint del conector a `search / prebook / book / cancel`.
2. Por cada capa (1-9), evaluar si el conector la satisface o requiere adaptación.
3. Marcar mismatches: directo · conocido (bug histórico §6) · nuevo.
4. Asignar scoring de complejidad (briefing §Complejidad).
5. Identificar trampas conocidas por provider similar (§6).

**Paso 3 (Mock Tests)**: los 7 casos cubren capas 2-6 + edge cases.
- Caso "price changed" toca Capa 6 + P2.
- Caso "room mapping ambiguo" toca Capa 3 + P4.
- Caso "cancel multi-tramo" toca Capa 5 + P5.

**Paso 4 (Match/Dismatch)**: cualquier mismatch que toque P1-P6 → HITL #3 obligatorio.

**Paso 10 (Monitorización)**: vigilar las 8 causas de fallo (§5). Si nueva conexión genera >1 causa adicional → input directo a la Skill al cierre.

---

## 9. Flujo completo de validación

```
[Connector entrega response]
        ↓
Capa 1: Auth + Authorization           → 401/403
        ↓
Capa 2: DTO shape                      → 400/413
        ↓
Capa 3: ID Mapping (Masters)           → 404/422
        ↓
Capa 4: Precio                         → 400/422
        ↓
Capa 5: Cancellation policies          → 400/422
        ↓
Capa 6: RateKey + TTL + idempotencia   → 410/409/422
        ↓
Capa 7: BookingFlow state machine      → 409/400
        ↓
Capa 8: Audit (TraceId + payload)      → registra siempre
        ↓
Capa 9: Cache invalidation             → 503 si lock falla
        ↓
[ACCEPT] → persistir en availability + booking_flow
```

**Tasa de éxito histórica**: 96.24% (640/665 reservas, oct-25 → abr-26).

---

## 10. Referencias

### Módulos del repo PerlaHub que toca Factory Pull (auditado 12-may)

| Módulo | Qué hace | Capa que toca |
|--------|----------|---------------|
| `BookingFlow/` | Core del pipeline search/prebook/book/cancel + state machine | Capas 2, 4, 6, 7 |
| `Connectors/Core/` | Interfaces canónicas `ICoreConnector*` | Capa 2 |
| `Connectors/Accommodation/{Dome,Expedia,Hotelbeds,Travelgate,PerlaPush,PushInternal}/` | Conectores reales | Capa 2 (nuevo conector se añade aquí) |
| `Partners/` | `ClientCredential`, `AuthorizedProductSources`, JWT, PriceAdjustmentRule | Capa 1, Capa 4 |
| `Audit/` | Microservicio separado: AuditService + S3/MinIO payloads | Capa 8 |
| `Mapping/` | Hotel/Room/MealPlan mappings provider↔PerlaHub | Capa 3 |
| `PerlaAdmin/` | Controllers admin: Enum, Audit, Mapping | Endpoints 5-11 |
| `BookingEngine/` | Motor B2B/B2C clientes — **consumer** de BookingFlow | Tangencial |
| `Mirror/` | TravelGate Mirror (statics) | Tangencial — relevante si conector pasa por TGX |
| `Inventory/` | Catálogo local hotel/room/meal — fuente de verdad estáticos (Decisión P1) | Capa 3, Capa 9 |

### Memorias y docs relacionados

| Recurso | Qué tiene |
|---------|-----------|
| `reference_perlahub_inventory_endpoints` (memoria) | Endpoints PH para crear hoteles + trampas con id=0 |
| `reference_perlahub_enums_api` (memoria) | 6 estados BookingFlowStatuses |
| `reference_perlaadmin_audit_api` (memoria) | Audit API + auditType 0-17 |
| `reference_perlaadmin_api` (memoria) | Endpoints PerlaAdmin |
| `reference_perlahub_db_prod` (memoria) | Postgres schemas audit/partners/inventory |
| `reference_perlahub_permanent_token` (memoria) | Generar JWT permanente |
| `project_booking_errors_apr_2026` (memoria) | 665 reservas, 8 causas fallo, 96.24% success |
| `project_perlahub_l1_cache_bug` (memoria) | Bug L1 cache TTL 600s |
| `project_dome_price_bug_E9MRSZUV` (memoria) | Bug precio Dome |
| `project_whl_albatravel_tgx_bug` (memoria) | Bug PDES-113 pvpRequired |
| `project_aurum_platja_price_changed` (memoria) | 3 bugs colaterales price changed |
| `factory_pull_briefing_v0.md` | Proceso paso a paso (padre) |
| `pull-skill-2026-05-11.md` | Skill ejecutable |
| `../factory_push/factory_push_validaciones.md` | Doc simétrico Push |

---

## 11. CHECKLIST FINAL — Definition of Done por conexión nueva

Recoge todos los items ✅ de las 9 capas en una única lista. Solo se mergea cuando TODOS están marcados o documentadamente justificados.

### 🔐 Capa 1 — Auth
- [ ] `ClientCredential` activa con `isActive=true`
- [ ] JWT generado y probado (sesión + permanent token)
- [ ] `AuthorizedProductSources` incluye este conector
- [ ] `ClientCredentialConfig` aplicado (`PUT /api/ClientCredential/{id}/applyConfig`)
- [ ] Mercados/nationalities del conector ⊇ los del cliente

### 📦 Capa 2 — Shape DTOs
- [ ] Conector implementa `ICoreConnectorSearch`, `Prebook`, `Book`, `Cancel`
- [ ] `ICoreConnectorGetBookings` (recomendado)
- [ ] DTOs mapean a `SearchRs/PrebookRsDto/BookRsDto/CancelRsDto`
- [ ] Payload ≤ 5 MB, JSON depth ≤ 32
- [ ] Validators de Rq/Rs por operación implementados

### 🗺️ Capa 3 — Mapping
- [ ] HotelMappings cargados (`POST /api/mapping/InsertHotelMapping`)
- [ ] RoomMappings cargados (`POST /api/mapping/InsertRoomMapping`)
- [ ] MealPlanMappings cargados (`POST /api/mapping/InsertMealPlanMapping`)
- [ ] RateCodeMappings: confirmar mecanismo con Pedro (no hay endpoint dedicado)
- [ ] Currency provider ↔ `Hotel.CurrencyCode` validada
- [ ] **P4** respetada: ningún RoomType/Amenity inventado

### 💰 Capa 4 — Precio
- [ ] `price > 0` siempre
- [ ] Modelo de precio declarado (Net / Commissionable / PVP)
- [ ] **P2** respetada: PVP no recibe markup
- [ ] Currency consistente
- [ ] No replica bug PDES-113 (`pvpRequired` con `room.price` omitido)

### 🚫 Capa 5 — Cancellation policy
- [ ] Tramos con **importe** (`amount`) válidos — el adapter convierte % y noches
- [ ] **P5** respetada: deadlines en UTC; conector convierte offset fijo del provider → UTC (sin IANA per-hotel)
- [ ] Flag `refundable` general + non-refundable presentes (PerlaHub NO pide flag "modificable")

### 🔄 Capa 6 — RateKey / Idempotencia / Price changed
- [ ] `rateKey` TTL declarado
- [ ] Reintento con misma `clientReference` no duplica
- [ ] Threshold price-changed validado (±5% default)
- [ ] No replica patrón TGX `200 OK sin booking.id`
- [ ] TraceId continuo search→prebook→book

### 🚦 Capa 7 — State machine
- [ ] Conector mapea estados provider → 6 estados `BookingFlowStatus`
- [ ] `CONFIRMED` literal del provider → `BOOKED`
- [ ] Transiciones respetadas

### 📝 Capa 8 — Audit
- [ ] Emite `ClientSearchRq`, `ConnectorSearchRq`, `ProviderSearchRq` (idem prebook/book/cancel)
- [ ] **`Gateway` del conector pasa `AddAuditRq` (no `null`) a `SendAsync` — patrón Hotelbeds `Gateway.cs`** (sin esto el `Provider*Rq` no se registra y falla en silencio)
- [ ] TraceId UUID por flujo
- [ ] Payloads en S3/MinIO
- [ ] Excepciones registradas con AuditType=17
- [ ] **Verificado en local contra la Audit API** (`docker-compose.local.yml`: postgres+minio+audit-api), no solo "compila": `AuditConfigId=1` (OnlyMetadata→Postgres) y `AuditConfigId=0` (All→S3+Postgres)

### 🗄️ Capa 9 — Cache
- [ ] Tras alta: `POST /api/Hotel/SetCache` + `PUT /api/ClientCredential/{id}/applyConfig`
- [ ] Aceptar TTL 600s L1 (sin invalidación on-demand)
- [ ] **P1** respetada: estáticos del Inventory local
- [ ] **P6** respetada: validación previa cualquier escritura PROD

### 📊 Métrica DoD
- [ ] Booking error rate < 4% durante 7 días tras go-live (métrica específica Pull)
- [ ] 0 nuevos bugs en §6
- [ ] Decisiones P1-P6 todas verificadas

---

## Pendientes v1 (actualizados 12-may)

1. ~~Listar exhaustivamente los AuditTypes~~ ✅ Hecho: 18 valores (0-17) — Capa 8 actualizada
2. Validar contrato exacto de SearchRs/PrebookRsDto/BookRsDto/CancelRsDto leyendo los .cs en `Utils.ModelDomain.BookingFlow.Api.Dto.*` (no se profundizó en campos, solo se confirmó existencia)
3. Definir threshold exacto de "price changed" en Capa 6 (placeholder ±5%)
4. Completar lista de mercados/nationalities bloqueados (caso Travel Code BY) — Capa 1
5. **Bug abierto Capa 9**: aceptar TTL 600s L1 como gap permanente, O implementar endpoint de invalidación (decidir con Pedro)
6. Aclarar mecanismo real de `RateCodeMapping` (no hay controller dedicado)
7. Calibrar todo con **Avoris** como piloto Pull (kickoff sin código aún)
