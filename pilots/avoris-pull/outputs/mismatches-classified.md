# Mismatches clasificados — avoris-pull

_Generado: 2026-06-09 · Fase 4 · Avoris (Polaris) Pull nativo_

**Contexto:** primera conexión Pull de la planta → catálogo cross-conexión vacío (v0).
Por definición las 16 filas 🟡 son "genuinamente nuevas" (0 precedente) y **siembran el Anexo D**.
La mayoría ya tienen resolución concreta de los hallazgos en vivo (sandbox + mock tests + Swagger)
y de las decisiones de Pedro en la revisión Fase 1. Esto va a **HITL #2** (aprobar mismatches + wrappers).

---

## A · Ya resueltas o decididas (confirmación rápida)

| row_key | Resolución | Origen |
|---|---|---|
| `search_currency` | Cuenta **single-currency EUR**; divisa no forzable por request | mock test #5 · sorpresa #19 |
| `cancel_timezone` | Avoris **GMT+1 → UTC (−1h fijo)**; canónico P5 ya corregido | sorpresa #7 (verificado en código PH) |
| `cancel_policy_format` | **NRF en bloque**, sin cross-feeding; +penalidad 100% in-stay implícita | decisión Pedro · sorpresa #9 |
| `search_taxes` | **Pasar `observations` tal cual** (no parsear city tax/resort fees) | decisión Pedro · sorpresa #11 |
| `book_errors` | Catálogo `IntegrationError.type` (~20 enums) del Swagger → mapear a errores PH | sorpresa #14 (Swagger) |
| `book_states` | Enum ampliado (ON_REQUEST, PRICE_CHANGED, PROVIDER_CHANGED…) → manejar on-request + reconciliación | sorpresa #15 (Swagger) |

## B · Mapeo a catálogo PerlaHub (P4 · rutina de codificación)

> Wrapper: **ninguno** (mapeo en el conector). Regla P4: nunca inventar, usar catálogo real PH.

| row_key | Qué entrega Avoris | Acción conector |
|---|---|---|
| `id_hotel_codes` | `hotelCode` (Codigo AVO) + portfolio | Mapear AVO ↔ Inventory PH (P1, P3) |
| `id_room_codes` | id compuesto `H|EXT` + `configuration 1a2|30|30n0b0` | Parsear config → RoomType PH |
| `id_meal_codes` | `meal.id` (SA, AD…) + Portfolio `/mealPlans` | Mapear a board PH |
| `meal_codes_mapping` | catálogo `/mealPlans` (names+codes) | Tabla de mapeo board |
| `id_amenities` | `HotelAmenity{id,type,name}` (staticdata) | Mapear a RoomAmenities PH |

## C · A confirmar con Avoris (no bloqueante · preguntas enviadas)

| row_key | Estado | Pregunta |
|---|---|---|
| `checkin_time` / `checkout_time` | Gap: no vienen en API ni staticdata | (en lista de preguntas) |
| `auth_rate_limits` | 429 sin cifras | Q#2 |
| `auth_rotation` | Sin política documentada | Q#4 |
| `rate_minstay` | No expuesto (presumiblemente server-side) | confirmar |

---

## Wrappers Core sugeridos (catalog/wrappers-pull.md)

| Wrapper | Para | Disparador (hallazgo) |
|---|---|---|
| `RateKeyBuffer` | `search_rate_key` | bookToken TTL ~56min, campo `ttl` explícito en RS (sorpresa #8) |
| `TimezoneResolver` | `cancel_timezone` | GMT+1 fijo → UTC −1h (sorpresa #7) |
| `BackoffExpStrategy` | `op_cancel`, `auth_rate_limits` | cancel necesita retry (sorpresa #18) + 429 |
| `CoreCancelNotFound` | `op_cancel` | "Booking does not exist" tras book + idempotencia ALREADY_BOOK_CANCEL (sorpresa #18) |
| `PriceChangedTolerance` | `op_prebook` | parity Avail→Prebook; NO tolerancia Prebook→Book (sorpresa #10) |
| `CurrencyForcer` | — | **NO aplica**: cuenta single-currency EUR (sorpresa #19) |

---

## Veredicto Fase 4

- **0 rojos / 0 bloqueantes técnicos.** El conector es viable.
- 16 mismatches, todos con ruta de resolución clara (decisión, mapeo, o wrapper Core existente).
- 5 wrappers Core a aplicar (todos ya en el catálogo, ninguno nuevo) + `CurrencyForcer` descartado.
- → **HITL #2** (Pedro aprueba mismatches + wrappers) antes de Fase 5 (informe) / Fase 6 (código).
