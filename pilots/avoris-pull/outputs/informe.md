# Informe final — Avoris (Polaris) · Pull nativo

_Fase 5 · Generado 2026-06-09 · **Revisado en HITL por Pedro 2026-06-09** · Piloto Pull v0 (primera conexión de la planta)_

> Esta versión incorpora las correcciones de la revisión del informe (ver `outputs/informe-ajustes-revision.md`).
> Varias afirmaciones de la v0 estaban **sobre-afirmadas o mal encuadradas** (conector vs Core) y se han corregido contra la evidencia real y el contrato canónico de PerlaHub (`Connectors/Core/Accommodation`).

## Veredicto: ✅ **PROCEDER a Fase 6 (codificación)** · Score **11/15**

Conexión **viable sin bloqueantes rojos**. Flujo completo validado end-to-end **en single-room** (reserva creada y cancelada, coste 0); multi-room validado **hasta prebook** (book multi-room pendiente). Toda la complejidad se cubre con wrappers Core ya existentes — ninguno nuevo. El conector **solo cablea**; el mapeo de catálogo es tarea externa del Mapping de PerlaHub (decisión **P7**).

---

## Principio de implementación (P7)

El conector **NUNCA mapea identificadores de catálogo**. El flujo `search→prebook→book→cancel` solo **CABLEA**: copia el id del proveedor al campo canónico tal cual. El mapeo `id_provider→id_PH` es tarea **externa** del servicio de Mapping de PerlaHub, alimentado por el Inventory de PH + los estáticos consultables del proveedor.

| Dimensión | Avoris (search RS) | Canónico Core | 
|---|---|---|
| Hotel | `hotels[].hotelCode` | `CoreReservableOption.HotelId` |
| MealPlan | `meal.id` (SA/MP/AD) | `MealPlanId` (+ estático `/mealPlans`) |
| Room (tipo) | `rooms[].id` (H\|E…) | `CoreOptionRoom.RoomTypeId` |
| Room (ocupación) | `configuration` (`1a2\|30\|30n0b0`) | `CoreRoomOccupancy.PaxAges` |
| Tarifa | `rateID` | `RateCodes` (NRF → `refundable=false`) |
| Selector | `token` opaco | `ConnectorSearchToken` |
| Amenities hotel | `services[]` (type=SERVICES) | `hotelFacilities` (vía estáticos) |

---

## Score por ejes (0–3)

| Eje | Score | Base (corregida) |
|---|---|---|
| **1. Cobertura funcional** | **3** | Flujo `avail→prebook→book→cancel` validado **E2E single-room** en PRO + Portfolio API. Multi-room: avail+prebook OK; **book multi-room no probado** (bloqueado por falta de creds) |
| **2. Calidad de datos / mapeo** | **2** | Cableado limpio y directo (P7); pricing claro; pero **`RoomAmenityIds` sin fuente** → colapso de variantes de room (#20, a negocio); city tax en texto libre |
| **3. Complejidad de integración** | **2** | 5 wrappers Core, **todos existentes**; matices: pax `index`=habitación (#16), parity Prebook→Book (#10) |
| **4. Estabilidad / fiabilidad** | **2** | Latencias buenas (0.2–1.7s); 429 sin cifras; race avail→prebook. (Nota: el "cancel inmediato falla" #18 NO se reprodujo en vivo — solo en mock) |
| **5. Documentación / soporte** | **2** | PDF + Swagger público sólidos; gaps: auth no documentado en PDF, TST muerto, check-in/out times ausentes, **doc no incorporada al repo** |
| **TOTAL** | **11/15** | Viabilidad alta |

---

## Validación realizada (evidencia)

| Fase | Resultado | Matiz tras revisión | Evidencia |
|---|---|---|---|
| 2 · Sandbox | E2E **single-room PASS** (PRO) · reserva 802885266 creada+cancelada coste 0 | cancel real OK a la primera | `evidence/sandbox-pro-20260609-e2e/` |
| 3 · Mock tests | 7 casos ejecutados (PRO, coste 0) | **multi-room (caso 3) solo hasta prebook**; cancel-fail (caso 7) es un mock | `evidence/mocktests-20260609/` |
| 4 · Mismatches | 16 clasificados, **0 rojos** | `meal_codes_mapping` resuelto (redundante) | `outputs/mismatches-classified.md` |

> Nota: TST de Avoris no certificable (creds muertas) — validación contra PRO con tarifas reembolsables + cancelación inmediata (coste 0), avalado por §2.2 de la doc. Sin creds/autorización para más reservas en PRO.

---

## Wrappers Core necesarios (todos ya en catálogo)

| Wrapper | Para | Disparador |
|---|---|---|
| `RateKeyBuffer` | bookToken | TTL ~58min (campo `ttl` explícito en RS) |
| `TimezoneResolver` | deadlines cancelación | GMT+1 → UTC (−1h fijo) |
| `BackoffExpStrategy` | cancel, rate-limit | retry cancel (defensivo) + HTTP 429 |
| `CoreCancelNotFound` | cancel | idempotencia ALREADY_BOOK_CANCEL |
| `PriceChangedTolerance` | prebook | tolerancia Avail→Prebook (NO Prebook→Book) |

`CurrencyForcer` **descartado** — cuenta single-currency EUR.

---

## Gaps rojos: ninguno

## Sorpresas clave (revisadas · siembran Anexo D)

1. **`travellers[].index` = `rooms[].index` del Prebook RS** (#16) — los N pax de una hab comparten el index de esa room. Confirmado E2E single-room; multi-room sin book real.
2. **Paridad estricta Prebook→Book** (#10) — `bookToken` literal con precio congelado + pax coherente con el token. Sin tolerancia book-side.
3. **Penalidad 100% in-stay SÍ viene por API** (#9, **corregida**) — en `cancellationPolicies` (fila `to`=checkOut, penalidad=total; 8927/8928 rates). El conector solo la vuelca, no la inyecta.
4. **Cancel inmediato** (#18, **rebajada**) — el fallo NOT_LODGING solo aparece en un mock; el E2E real canceló a la primera. Retry+backoff se mantiene como salvaguarda.
5. **Colapso de variantes de room** (#20, **a negocio**) — sin room-amenities, las variantes bajo un mismo `id` colapsan en una Room de inventario.
6. Estados ampliados (ON_REQUEST, PRICE_CHANGED…); single-currency EUR; city tax en observations; bookToken TTL dinámico; timezone GMT+1.

---

## Para NEGOCIO

**Pérdida de granularidad de tipología de habitación (#20):** con Avoris no se pueden inferir tipologías a partir de texto libre. Decidir si es aceptable comercialmente o si se exige a Avoris un catálogo estructurado de room-amenities + su asignación por-room en search.

## Pendiente de Avoris (no bloqueante · `outputs/preguntas-avoris.md`)

- Credenciales TST válidas (o certificar contra PRO).
- Cifras de rate limits (429), política de rotación de credenciales.
- check-in/check-out time del hotel; existencia de estáticos `/roomTypes` `/roomAmenities` en Portfolio (Swagger).

## Pendientes bloqueados (sin creds/autorización PRO)

- Book+cancel **multi-room** real (cerrar #16).
- Reproducir book→cancel inmediato con timestamps (cerrar/descartar #18).

---

## Métricas del proceso (planta)

- **Tiempo total del proceso:** 14.06 días de calendario (26-may → 9-jun).
- **Tiempo efectivo de trabajo:** 8.63 h en 4 días + revisión HITL del informe.
- Fases 1–5 completas; HITL #1 y #2 aprobados (Pedro).

## Siguiente
**Fase 6 (codificación)** → comando estandarizado **`/factory-implement avoris-pull`** (repo PerlaHub, fuera de la planta; arranca desde este informe + DoD §11, aplica P7 e incluye audit Capa 8 + verificación en local). Gate #3 (aprobar PR) y #4 (go-live) quedan para esa etapa.
