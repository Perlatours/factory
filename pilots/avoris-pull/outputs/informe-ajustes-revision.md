# Ajustes de revisión del informe — Avoris (Polaris) · Pull nativo

_Generado: 2026-06-09 · Revisión HITL del informe Fase 5 (Pedro) · Insumo para regenerar `informe.md` y para la implementación del conector (Fase 6)_

> Este documento consolida las correcciones detectadas al revisar `informe.md` + `mismatches-classified.md` + los mocks contra la evidencia real y contra el contrato canónico de PerlaHub (`Connectors/Core/Accommodation`). Patrón general detectado: **el informe original sobre-afirmó carencias y mezcló responsabilidades conector/Core**. Cada ajuste queda registrado también en la DB (sorpresas / checklist_responses).

---

## 0. Principio rector (aplica a TODA la implementación)

**El conector NUNCA mapea identificadores de catálogo.** El flujo (`search → prebook → book → cancel`) solo **CABLEA**: copia el identificador del proveedor al campo canónico de PerlaHub, tal cual. El mapeo `id_provider → id_PerlaHub` es una **tarea EXTERNA** del servicio de **Mapping de PerlaHub**, alimentada por:
- el **Inventory de PerlaHub**, y
- los **estáticos consultables del proveedor** (operaciones `IGetHotels / IGetRoomTypes / IGetMealPlans / IGetRoomAmenities` → modelos `{Id, Name}` del Core).

Consecuencia: cualquier fila de mismatch redactada como "parsear / traducir / mapear X → catálogo PH" está **mal encuadrada**. La acción real del conector es "identificar `<campo proveedor>` y volcarlo en `<campo canónico>`". Ver decisión Pull **P7**.

---

## 1. Cableado de campos (search RS → canónico Core)

Contrato canónico verificado: `CoreReservableOption` / `CoreOptionRoom` / `CoreRoomOccupancy`.

| Dimensión | Campo Avoris | Campo canónico | Nota |
|---|---|---|---|
| Hotel | `hotels[].hotelCode` | `CoreReservableOption.HotelId` | request: nuestros HotelIds → `destination.hotelCodes[]` + `location.type:"EMPTY"` |
| MealPlan | `roomRates[].meal.id` (SA/MP/AD) | `MealPlanId` | + estático `/mealPlans` → `MealPlan{Id,Name}` |
| Room (tipo) | `roomRates[].rooms[].id` (H\|E…) | `CoreOptionRoom.RoomTypeId` | id = taxonomía global; copia directa |
| Room (ocupación) | `configuration` (`1a2\|30\|30n0b0`) | `CoreRoomOccupancy.PaxAges` | **es ocupación, NO atributo de room** |
| Tarifa | `roomRates[].rateID` (PUBLICA…) | `RateCodes` | NRF vía `rateID=NOREEMBOLSABLE` → `refundable=false` |
| Selector | `token` (opaco) | `ConnectorSearchToken` | identificador real de la opción reservable |
| Amenities hotel | `services[]` (type=SERVICES) | `hotelFacilities` (vía estáticos) | NO alimenta `RoomAmenityIds` |

Decodificación de `configuration`: `<nRooms>a<adultos>|<edad>|<edad>…n<niños>[|edades]b<bebés>[|edades]`.

---

## 2. Correcciones a sorpresas / mismatches

| Ref | Antes (informe v0) | Después (verificado) | Veredicto |
|---|---|---|---|
| **#16** `travellers[].index` | "index = habitación" (vago) | `travellers[].index` **debe reflejar `rooms[].index` del Prebook RS**; los N pax de una hab comparten el index de esa room. Confirmado E2E single-room; multi-room solo hasta prebook | regla de codificación |
| **`id_room_codes`** | "parsear `configuration` → RoomType" | `rooms[].id → RoomTypeId` (directo) · `configuration → Occupancy.PaxAges` | corregido |
| **`id_amenities`** | genérico (HotelAmenity staticdata) | `services{type:SERVICES}` es **hotel-level → `hotelFacilities`**; NO alimenta `RoomAmenityIds` | matizado |
| **#10** paridad Prebook→Book | "cualquier diff = ERROR" (difuso) | dos caras: (a) `bookToken` **literal** con precio congelado; (b) pax/ocupación coherente con el token. Sin tolerancia book-side (la tolerancia de precio es Avail→Prebook) | afinado |
| **#9** penalidad 100% in-stay | "**NO viene por API**, asumir en wrapper" | **FALSO**: SÍ viene en `cancellationPolicies` (fila con `to`=checkOut, penalidad=total). Verificado **8927/8928 rates**. El conector solo la vuelca | **corregido (era falso)** |
| **`cancel_policy_format`** | "100% in-stay implícita" | "100% in-stay **EXPLÍCITA via API**" | corregido |
| **#18** cancel inmediato falla | "confirmado en vivo PRO, retry ~3-6s" | NOT_LODGING **solo en MOCK** (token `perla-mock`); el E2E real canceló a la primera; "~3-6s" **sin evidencia** (cero timestamps) | **sobre-afirmada → rebajada** |
| **`meal_codes_mapping`** | 🟡 pendiente (tabla de mapeo) | **RESUELTO 🟢**: redundante con `id_meal_codes`; cableado + estático `/mealPlans` + mapeo en Core | resuelto |

Recomendaciones defensivas que **se mantienen** pese a la corrección del diagnóstico: wrapper de cancel con retry/backoff + idempotencia (#18); `PriceChangedTolerance` solo Avail→Prebook (#10); `RateKeyBuffer` por TTL 58 min (#8).

---

## 3. Para NEGOCIO (no técnico)

**Colapso de tipologías de habitación (#20).** Avoris no expone características de habitación estructuradas en el flujo de search (cada room trae solo `id`+`name`+`configuration`+`pricing`). Como en PerlaHub `Room = RoomTypeId + RoomAmenityIds` y no hay fuente para `RoomAmenityIds`, **todas las variantes físicas bajo un mismo `id`** (p.ej. `D|2C` "2 camas" vs "2 camas + sofá-cama"; `ROH` = Run-Of-House con 3+ tipologías) **colapsan en una única Room de inventario**. La granularidad solo vive en `name` (texto libre, sin slot canónico en search).

→ **Decisión de negocio:** aceptar la pérdida de granularidad, o exigir a Avoris (a) catálogo estructurado de room-amenities y (b) su asignación por-room en search. Evidencia: 58 casos `(hotel,id)` con múltiples nombres en los mocks.

---

## 4. Gaps de evidencia (limitaciones de esta validación)

1. **Doc/Swagger del proveedor ausente del repo** (`inputs/doc/` vacío): varios puntos quedan **inferidos, no documentados** (semántica exacta de `index`, existencia de estáticos `/roomTypes` `/roomAmenities` en Portfolio).
2. **Sin credenciales ni autorización PRO/TST** para crear más reservas: no se puede reproducir el book→cancel inmediato (#18), ni un book+cancel **multi-room** real (#16). Quedan como pendientes bloqueados.

---

## 5. Acciones para Fase 6 (implementación)

- [ ] Cablear los campos de §1 sin traducción (principio §0 / P7).
- [ ] Construir `travellers[]` con `index` = `rooms[].index` del Prebook (#16).
- [ ] Reenviar `bookToken` **literal**; no reconstruir hotel/pricing (#10).
- [ ] Volcar `cancellationPolicies` tal cual a `CoreOptionCancelPolicy` (incluye in-stay 100%) — NO inyectar penalidad (#9).
- [ ] `rateID=NOREEMBOLSABLE → refundable=false` sin cruzar con otros campos (`cancel_policy_format`).
- [ ] Implementar estáticos `/mealPlans` (y verificar `/roomTypes` `/roomAmenities` con el Swagger).
- [ ] Wrappers: `RateKeyBuffer`, `BackoffExpStrategy`+idempotencia cancel, `PriceChangedTolerance` (Avail→Prebook), `TimezoneResolver`, `CoreCancelNotFound`.
