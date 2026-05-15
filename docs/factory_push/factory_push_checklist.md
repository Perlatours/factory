---
title: Factory Push — Checklist rápida para evaluar un Channel Manager nuevo
date: 2026-05-12
status: v2
audience: Santiago / lead técnico decidiendo si y cómo conectar un Channel Manager
parent: factory_push_briefing_v0.md
sibling: factory_push_validaciones.md (referencia técnica detallada)
history: v1 12-may (alto nivel); v2 12-may (granular: unidades, formatos, variantes)
---

# Factory Push — Checklist rápida

> **Objetivo**: en 10-15 minutos saber, leyendo la doc del channel, si encaja con el contenedor canónico `PurchaseContract` y cuánta interpretación necesita el adapter.
>
> **Marca por fila**:
> - 🟢 **Directo** — el channel envía el dato como lo pedimos, mismo formato/unidad
> - 🟡 **Interpretación** — hay forma de mapear, pero el adapter convierte unidad/formato/estructura
> - 🔴 **Gap** — el channel no lo manda o lo manda en forma incompatible → reunión Pedro+Eva+Santi

> Pensar en perspectiva **inversa al Pull**: aquí el channel **empuja** datos hacia nosotros, no los servimos al cliente. Lo que el channel no nos diga, no podemos vender.

---

## A. Modo de integración (decidir antes de bajar al detalle)

| Modo | Quién adapta | Adapter código nuevo | Cuándo |
|------|--------------|----------------------|--------|
| **A — Push In Genérico** | Ellos | NO (`GenericAdapter` ya existe) | Channel acepta nuestro JSON `pk_live_*` + 10 endpoints |
| **B — Conector específico** | Nosotros | SÍ (`{Channel}Adapter : IProviderAdapter`) | Channel manda formato propietario (XML, SOAP, JSON propio) |

**Referencias en código** (auditado 12-may):
- Modo A → `Ingestion.Generic.Api/Adapters/GenericAdapter.cs`
- Modo B Dingus → `Ingestion.Dingus.Api/Adapters/DingusAdapter.cs` (XML)
- Modo B SiteMinder → `Ingestion.SiteMinder.Api/Adapters/SiteMinderAdapter.cs` (SOAP/OTA)

🟢 / 🟡 / 🔴 (¿el channel puede adaptarse a Modo A, o tenemos que hacer Modo B?)

---

## B. Endpoints PerlaPush que el channel debe consumir

| # | Endpoint REAL | Obligatorio | El channel puede llamarlo |
|---|---------------|-------------|----------------------------|
| 1 | `POST /api/v1/availability/delta` | ✅ | 🟢 / 🟡 / 🔴 |
| 2 | `POST /api/v1/availability/full-refresh` | ✅ (si soporta refresh completo) | 🟢 / 🟡 / 🔴 |
| 3 | `POST /api/v1/availability/close` | ✅ (stop sales) | 🟢 / 🟡 / 🔴 |
| 4 | `POST /api/v1/availability/open` | ✅ | 🟢 / 🟡 / 🔴 |
| 5 | `GET /api/v1/messages/{id}/status` | Recomendado (async 202) | 🟢 / 🟡 / 🔴 |
| 6 | `GET /api/v1/availability/verify` | Opcional (slow, diagnóstico) | 🟢 / 🟡 / 🔴 |
| 7 | `GET /api/v1/hotels/{hotelId}/configuration` | Recomendado (discovery) | 🟢 / 🟡 / 🔴 |
| 8 | `GET /ping` (sin `/api/v1`) | Opcional (health) | 🟢 / 🟡 / 🔴 |

> En Modo B no importa qué endpoints "consume" el channel — importa que su payload se mapee a nuestros endpoints.

---

## C. Identificación y mapeo a Masters

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| `hotelId` del channel | Estable y único | propio / GIATA / IATA / múltiples (channel maneja varios PMS) / mutables |
| Quién crea el hotel primero | Perla crea + envía código (caso H-Top) | Perla primero / channel detecta y avisa / hotel inicia desde frontend del channel ("caso rebelde" Dingus) |
| Asociación `provider_hotel_associations` | Activa antes del primer payload | sí / hay que activar al recibir primer mensaje |
| `roomCode` | Estable + único por hotel | propio / mapping interno del channel / regenerado |
| `rateCode` | Estable | propio / por canal / por mercado / por fecha |
| `mealPlanCode` | OTA estandarizable (`RO/BB/HB/FB/AI`) | OTA / propios / multilingual / no soportado |
| `currencyCode` | ISO 4217 por hotel | sí ISO / por rate / por reserva / multi-currency |
| `ageRanges` | `[{minAge,maxAge}]` o `AgeConfiguration` del hotel | declarado / asume default / no soportado |

🟢 / 🟡 / 🔴 por cada fila.

---

## D. Disponibilidad (allotment)

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| `roomsToSell` (entero ≥ 0) | Por (hotel, room, fecha) | sí entero / "available"/"limited" / sin allotment (free sell) |
| Pool vs per-room | Per room type (default) | per room / pool compartido (hay que desagregar) / per rate |
| Free sell flag | Boolean | sí flag / always-true asumido / no soportado |
| Granularidad temporal del envío | Per fecha individual O rango compacto | per fecha / per rango / per semana / per mes |
| Multi-room en un mensaje | Sí (`updates[]`) | sí lista / un mensaje per room / un mensaje per (hotel,room,fecha) |
| Ajuste por bookings | PerlaPush calcula `RoomsToSell = max(0, channel - bookingCount)` | channel manda allotment bruto / channel ya descuenta bookings (no aplicar twice) |
| Hold/inventory hold | No soportado en PerlaPush | sí (ignorar) / no |

🟢 / 🟡 / 🔴 por cada fila.

---

## E. Restricciones temporales (release, minStay, maxStay, CTA/CTD, stopSale)

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| `releaseDate` (entero, días antes de check-in) | Entero | entero días / fecha absoluta (hay que convertir) / días+horas / no soportado |
| Unidad release | Días | días / horas / meses / mixto |
| `minimumStay` (entero noches) | Entero | entero / per-arrival / per-stay (diferente!) |
| Distinción minStay per-arrival vs per-stay | Per-stay (default PerlaPush) | per-stay / per-arrival / no distingue |
| `maximumStay` (opcional) | Entero | sí / no soportado |
| `closedToArrival` (CTA) | Boolean per fecha | sí / no soportado |
| `closedToDeparture` (CTD) | Boolean per fecha | sí / no soportado |
| `isClosed` (stopSale) | Boolean per (hotel,room,rate,fecha) | per granularidad fina / solo per hotel-fecha / "off-sale" como flag de rate |
| Granularidad stopSale | Per room/rate/fecha individual | granular / per hotel-fecha / per rango |
| Re-open automático | Channel manda OPEN explícito (D2: full-refresh sobrescribe TODO) | sí explícito / inferido / channel asume estado anterior |

🟢 / 🟡 / 🔴 por cada fila.

---

## F. Precio entrante

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Modelo de precio | `Unit` / `Person` / `Occupancy` / `MinStayBased` | declara modelo / asume `Unit` / mezcla / depende del rate |
| `totalPrice` (decimal por noche o por estancia) | Decimal | sí / con varios decimales / strings ("100.00 EUR") |
| `totalPax` con `ageRanges` | Soportado para multi-ocupación | sí array / solo principal / per ocupación enviada separada |
| `MinStayBasedRate` (1=default, 3=3+ noches) | Soportado para tarifas por duración | sí / minStayBasedRate = 1 siempre / no soportado |
| Taxes | Incluidas vs separadas (declarar) | incluidas / separadas / array / solo total |
| Per pax type (Adult/Child/Baby precios distintos) | Soportado | sí breakdown / total único / hay que parsear texto |
| `BabyCountsAsOccupancy` (bool) | Per (hotel,room) o global | per hotel / global / asumido / no soportado |
| Currency en el precio | Coincide con `Hotel.CurrencyCode` | sí / per rate / multi-currency |
| Comisión hotel declarada | Opcional | sí % / no aplicable (channel push, generalmente rate neto) |

🟢 / 🟡 / 🔴 por cada fila.

> **Recordatorio P2** (heredado de Pull): si hubiera PVP, ya incluye comisión hotel — no aplicar markup.

---

## G. Mealplan en detalle (entrante)

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Códigos OTA estándar (`RO/BB/HB/FB/AI`) | Mapeables a Masters | OTA / propios / descripciones / multilingual |
| Mealplan separado de add-ons | Sí — régimen ≠ add-on | claramente separados / mezclados (bug Expedia tipo) / channel manda solo régimen |
| Múltiples mealplans por rate | Soportado (`AvailabilityPrice` 1:N con MealPlanCode) | sí lista / uno solo por rate (hay que enviar N mensajes) |
| Variantes All-Inclusive | Tratadas como `AI` con metadata | `AI` único / múltiples (`UAI`/`Soft-AI`/`Premium AI`) |
| Mealplan-level a hotel vs rate | Por rate | per rate / per hotel (con override) / per room |

🟢 / 🟡 / 🔴 por cada fila.

---

## H. Cancellation policy entrante (lo más variable)

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| **Unidad** del deadline | Fecha absoluta UTC O días antes check-in | fecha absoluta / días antes / horas antes / meses / mixto |
| Granularidad de tramos | Array `[{from,to,percent,refundable}]` | un solo tramo / múltiples tramos / por ocupación |
| **Penalty type** | `percent` (%) sobre total | % / nights (X noches) / importe fijo |
| **TZ** del deadline | UTC explícito O TZ hotel (PerlaPush respeta `Hotel.TimeZoneId`) | UTC / TZ hotel / TZ booking / sin TZ |
| `refundable` flag por tramo | Explícito | flag / inferido por % |
| NRF (non-refundable rate) | Como rate type o flag global | rate type separado / flag al inicio / sin distinción |
| Modificable ≠ cancelable | Flags separados | mismo / separado / no soportado |
| Cancellation policy a nivel rate vs reserva | Per rate | per rate / per booking / per hotel |
| Cambios on-fly (channel modifica policy retroactiva) | NO permitido (PerlaPush snapshot) | channel solo manda forward / channel rewrite retroactivo (rechazar) |

🟢 / 🟡 / 🔴 por cada fila.

---

## I. Check-in / check-out (entrante como metadata)

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Horario check-in declarado | Per hotel | sí (en config Masters) / inferido / no declarado |
| Horario check-out declarado | Per hotel | sí / inferido / no declarado |
| Día llegada incluido como noche | Sí (convención) | confirma / channel asume / no declara |
| Early check-in / late check-out como add-on | Opcional | sí coste / no soportado |

🟢 / 🟡 / 🔴 por cada fila.

---

## J. Ocupación y edades entrantes

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Modelo ocupación | `totalPax + AgeRangesJson` | adults+children+babies / totalPax+ageList / solo totalPax (asumir adulto) |
| `ageRanges` declarados | `[{minAge,maxAge}]` | rangos explícitos / categorías (Adult/Child/Baby) / no soportado |
| `adultMinAge` / `babyMaxAge` / `seniorMinAge` configurables | Por hotel (`AgeConfiguration`) | per hotel / global / hardcoded |
| Bebé cuenta en `MaxOccupancy` | Flag `BabyCountsAsOccupancy` per hotel | per hotel / global / asume false / asume true |
| Múltiples ocupaciones en un mensaje | `updates[]` con varias ocupaciones | sí array / un mensaje per ocupación |
| `OccupancyExceedsMax` (warning) | Tolerado | tolerar / rechazar request |

🟢 / 🟡 / 🔴 por cada fila.

---

## K. Idiomas y contenido estático

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Idioma de nombres (room/rate/mealplan) | Se ignoran (P1: Inventory local) | varios idiomas / un solo idioma / no soportado |
| Códigos idioma soportados | ISO 639-1 (`es`, `en`, `fr`) | ISO / propios / no relevante |
| Hotel content static | NO se actualiza por Push (Masters lo posee) | no aplicable / channel intenta empujar (ignorar) / no soportado |
| Imágenes hotel/room | NO por Push | no aplicable / channel intenta empujar (ignorar) |
| Idiomas hablados en hotel | NO por Push (Masters Inventory) | no aplicable |

🟢 / 🟡 / 🔴 por cada fila.

> El channel **no debe** intentar empujar contenido estático (hotel description, fotos, idiomas hablados, amenities). Eso vive en Masters/Inventory y es responsabilidad del equipo de contenido. Si el channel insiste, **ignorar** o reunión.

---

## L. Reservations / cancellations / modifications entrantes

> Esto NO es Push de availability — es un canal aparte (`Reservations/` module en PerlaPush). Si el channel ALSO gestiona bookings, considerar:

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Channel envía booking creado en su sistema | Webhook a `Reservations/` | sí webhook / polling / no soportado |
| Formato locator del channel | String estable | propio / mixed con PNR / cambia |
| Cancellation desde channel side | Webhook explícito | sí webhook / inferido por allotment delta / no soportado |
| Modificación booking | Webhook modify | sí / solo cancel+rebook / no soportado |
| Reconciliación allotment ↔ bookings | PerlaPush calcula descuento | sí / channel descuenta antes (doble descuento risk) |

🟢 / 🟡 / 🔴 por cada fila.

---

## M. Auth y operativa

| Aspecto | Qué pide PerlaPush | Variantes del channel |
|---------|---------------------|--------------------------|
| Auth | HMAC-SHA256 con API key `pk_live_*` (Bearer) | sí ✓ / OAuth2 / Basic / SOAP+WS-Security (legacy) |
| Header `Authorization: Bearer pk_live_*` | Obligatorio | sí / posible / no soportado en su stack |
| IP whitelist | Aceptable como adicional | sí / no necesario |
| `X-Idempotency-Key` (UUID) | Opcional pero recomendado | usa con UUID estable / sin idempotencia (acepta duplicados) |
| Rate limit aceptado | 500 req/min per provider | sí / pide más / no declara |
| Tolera 202 + polling (`/messages/{id}/status`) | Recomendado para volumen alto | sí async / solo sync (hay que responder rápido) |
| Maneja 18 códigos de error reales | `UNKNOWN_ROOM_CODE`, `FORBIDDEN_HOTEL`, `CONCURRENT_UPDATE`, etc. | sí maneja / solo 200/500 (mapeo trivial) |
| Reintentos con backoff | Espera `Retry-After` en 503/429 | sí / hard retry inmediato / no reintenta |
| Channel maneja warnings (HTTP 200 partial) | Sí | sí / asume todo OK / asume todo error |
| Volumen mensajes estimado | < Dingus = 1×, > Dingus = más complejo | <Dingus / 1-3× / 3-10× / >10× (alarma) |

🟢 / 🟡 / 🔴 por cada fila.

---

## N. Decisiones no-negociables (D1-D6)

| ID | Decisión | El channel la respeta |
|----|----------|------------------------|
| **D1** | Idempotencia con body fingerprint SHA256 | si usa key + body estable: 🟢. Si no la usa: 🟢 (acepta duplicados). Si manda key pero body cambia: 🔴 |
| **D2** | Full-refresh sobrescribe **TODO** (incluye stopSales previos) | siempre ✓ (interno) — channel debe entender que tras `/full-refresh` su estado anterior se pierde |
| **D3** | `minStayBasedRate` nombre estable v1 | siempre ✓ (interno) |
| **D4** | `/verify` lee Postgres directo, slow path | siempre ✓ (interno) — channel no debe usar `/verify` en hot path |
| **D5** | HMAC server-secret rotation fuera de scope | siempre ✓ — channel rota su key si comprometida vía proceso ops |
| **D6** | Datos zombis: alerta nightly, NO auto-purge | siempre ✓ (interno) — channel debe asumir que al cambiar asociación quedan datos previos hasta job manual |

> Cualquier 🔴 fuera de los "siempre interno" → HITL bloqueante, reunión Pedro+Eva+Santi.

---

## O. Campo NUEVO no contemplado en `PurchaseContract`

Si el channel pide algo que no está en el contenedor (ejemplo real: release por duración de estancia en lugar de por día) → 🔴 → **reunión Eva+Pedro+Santi**.

**Regla por defecto**: NO extender por 1 solo channel. Solo si 3+ piden lo mismo.

Lista de cosas que **suelen** aparecer y deben quedar fuera por ahora:
- Release por estancia (no por día)
- Tarifas dinámicas con AI/ML rate suggestions
- Loyalty programs integrados
- Cross-sell (transfer + extras)
- Multi-property simultaneous booking
- Smart pricing yield management

---

## P. Veredicto

1. Cuenta tus marcas: 🟢, 🟡, 🔴.
2. Verifica que 🔴 NO esté en filas obligatorias (delta endpoint, hotelId, roomCode, modelo de precio, TZ cancel).

| Tu score | Tipo conexión | Estimación adapter |
|----------|----------------|----------------------|
| 0 🟡 obligatorios | Modo A directo (Push In Genérico). No se escribe adapter. | 2-3 días alta MastersPush + tests |
| 1-5 🟡 | Modo B ligero (nivel SiteMinder) | 1 semana adapter |
| 6-12 🟡 | Modo B medio (nivel Dingus inicial) | 2 semanas adapter |
| 13+ 🟡 o 🔴 obligatorio | Caso especial | Reunión antes de empezar |

### Eje de scoring rápido (0-3 cada uno)

- Formato entrada: JSON nuestro (0) / JSON propio (1) / XML estándar (2) / XML+SOAP propietario (3)
- Modos de precio: Unit (0) / +Person (1) / +Occupancy (2) / +custom (3)
- Auth: Bearer (0) / OAuth2 (1) / Bearer+IP (2) / SOAP+HMAC legacy (3)
- Validaciones business custom: 0 / 1-3 / 4-8 / 9+
- Full-refresh: separado (0) / flag (1) / condicional (2) / implícito/ausente (3)
- Volumen mensajes: <Dingus (0) / 1-3× (1) / 3-10× (2) / >10× (3)

---

## Q. Banderas rojas automáticas (zona de reunión obligatoria)

- 🔴 en `/api/v1/availability/delta` (operación obligatoria)
- 🔴 en `hotelId`/`roomCode`/`rateCode` estabilidad (mapping no posible)
- 🔴 en TZ de cancellation policy (P5)
- 🔴 en modelo de precio (Unit/Person/Occupancy/MinStayBased)
- Channel quiere empujar contenido estático (fotos, descripciones, idiomas hablados)
- Channel modifica cancellation policy retroactiva
- Channel mezcla mealplans con add-ons sin diferenciar
- Channel sin idempotencia + sin retry seguro (riesgo overbooking)
- Volumen > 10× Dingus (alarma capacidad)

---

## R. Avisos críticos PerlaPush (gaps vivos a 12-may)

Independientes del channel — aplican a cualquier conexión Push nueva:

1. 🚨 **Idempotencia y rate limit son in-memory** (`ConcurrentDictionary`), no Redis distribuido. Multi-instancia no garantiza dedupe. → Decidir con Pedro si migrar antes de SiteMinder/Avoris, o aceptar single-instance.
2. 🚨 **BUG-1 vivo**: `"EUR"` hardcoded en `AvailabilityService.cs:819` y `DiagnosticsController.cs:66,90`. Tu adapter NO debe replicar.
3. 🚨 **BUG-2 vivo**: `ReleaseDate=0` hardcoded en `AvailabilityService.cs:820` y `DiagnosticsController.cs:65,89`. Tu adapter NO debe replicar.
4. ⚠️ **D6 no implementado**: job nightly de datos zombis no existe. Tras cambiar asociaciones, registros viejos sin alerta.
5. ⚠️ **`BulkSetClosedAsync` NO existe** como operación pública en `IAvailabilityManagementGateway`. Close/Open posiblemente vía `UpdateAllotment` o método interno. Verificar con Pedro antes de implementar.

---

## S. Antes de empezar el código

- [ ] Tienes credenciales sandbox del channel
- [ ] Tienes ejemplos REALES de payload (XML / SOAP / JSON / batch / per-event)
- [ ] Tienes la doc API oficial del channel (URL, versión, lenguaje, esquemas XSD si aplica)
- [ ] Conoces el adapter más cercano ya conectado: Dingus / SiteMinder / Generic
- [ ] Has revisado [factory_push_validaciones.md §11](./factory_push_validaciones.md) (52 ítems Definition of Done técnico)
- [ ] SiteMinder confirmado como piloto Push → correcciones sobre SiteMinder → mejoras Skill v1
- [ ] Tienes claro si el channel ALSO gestiona bookings (Reservations) o solo availability
- [ ] Has decidido el flujo "quién crea el hotel primero" (caso H-Top vs caso rebelde)

---

## Apéndice — para el detalle técnico

→ [factory_push_validaciones.md](./factory_push_validaciones.md) — 7 capas + 18 error codes reales + bugs vivos + DoD 52 ítems
→ [factory_push_briefing_v0.md](./factory_push_briefing_v0.md) — proceso 12 pasos + 5 HITL gates
→ [push-skill-2026-05-11.md](./push-skill-2026-05-11.md) — Skill ejecutable Claude Code
