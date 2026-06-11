---
title: Factory Pull — Checklist rápida para evaluar un proveedor nuevo
date: 2026-05-12
status: v3
audience: Santiago / lead técnico decidiendo si y cómo conectar un rebuyer
parent: factory_pull_briefing_v0.md
sibling: factory_pull_validaciones.md (referencia técnica detallada)
history: v1 12-may (alto nivel); v2 12-may (granular: unidades, formatos, variantes); v3 18-may (correcciones Pedro — modelo canónico PerlaHub: global, no por hotel; amount no percent; refundable flag general; sin flag modificable; dispo/restricciones son PUSH)
---

# Factory Pull — Checklist rápida

> **Objetivo**: en 10-15 minutos saber, leyendo la doc del proveedor, si encaja con PerlaHub y dónde habrá interpretación.
>
> **Marca por fila**:
> - 🟢 **Directo** — el proveedor lo entrega exactamente como lo pedimos
> - 🟡 **Interpretación** — hay forma de mapear, pero el adapter necesita parsear/convertir
> - 🔴 **Gap** — el proveedor no lo da o lo da en forma incompatible → reunión Pedro+Eva+Santi

> **Cómo se lee**: la columna izquierda es lo que PerlaHub espera. La derecha es lo que tiene que responder el proveedor. Al final hay un veredicto que cuenta tus marcas.

---

## A. Operaciones

PerlaHub define 6 interfaces canónicas (`ICoreConnector*`). El proveedor debe cubrirlas:

| Operación | Qué hace en PerlaHub | Obligatoria | Cómo lo da el proveedor |
|-----------|----------------------|-------------|--------------------------|
| `Search` | Disponibilidad multi-hotel multi-fecha | ✅ | endpoint? batch / per-hotel / per-room? |
| `Prebook` / CheckRate | Revalida precio con rateKey antes de book | ✅ | endpoint separado? mismo Search? skip? |
| `Book` | Confirma reserva + devuelve locator | ✅ | sync / async + polling? |
| `Cancel` | Anula reserva | ✅ | con locator? con rateKey? |
| `GetBookings` | Consulta histórico/estado de reservas | Recomendada | per locator / por rango fechas / batch? |
| `Static`: hotels / rooms / mealPlans / amenities / chains / languages | Carga catálogos (P1) — **vía proceso de sync de contenidos externo, NO en el conector (P8)** | N/A en el conector | dump completo / incremental / per id? (lo consume el sync, no el conector) |

🟢 / 🟡 / 🔴 por cada fila.

---

## B. Identificación y catálogos

Cómo identifica el proveedor sus entidades — esto define el trabajo de mapping:

| Entidad | Lo que pide PerlaHub | Variantes posibles del proveedor |
|---------|------------------------|------------------------------------|
| Hotel ID | Código estable y único | Propio (string) / GIATA / IATA / múltiples IDs (EPS vs Content como Expedia) / changes over time |
| Room code | Estable + identificable — **cómo se definen** las rooms para poder mapearlas (PerlaHub es global; NO requiere unicidad por hotel) | Propio / en detalle de hotel / endpoint dedicado / mapping interno cambia / regenerado por sync |
| Rate code | Estable | Propio / por canal / por mercado / por fecha |
| Meal plan code | Estandarizable a `BB/HB/FB/AI/RO/UAI/Soft-AI` | Códigos OTA (BB/HB…) / descripciones free-text / multilingual / add-ons mezclados como meals (caso Expedia bug) |
| Currency | ISO 4217 (PerlaHub **NO fija moneda por hotel**) | Por hotel / por rate / por reserva / multi-currency mismo rate |
| Country code | ISO 3166-1 alpha-2 | Propio / ISO-2 / ISO-3 / inferido por lat-lng |
| Language code | ISO 639-1 (`es`, `en`, `fr`) para textos | Lista propia / ISO / sin lista (un solo idioma) |

🟢 / 🟡 / 🔴 por cada fila.

> **Decisión P1**: los **nombres** hotel/room/meal/amenity se IGNORAN del provider — PerlaHub usa siempre el Inventory local. Solo los **códigos** importan para mapping.
>
> **Corrección Pedro (rev. 18-may)**: PerlaHub es un sistema **global**. (1) No le concierne que las rooms sean únicas por hotel — lo que necesita es saber **cómo las define el proveedor** (en el detalle del hotel o en endpoint dedicado) para poder traducirlas y completar mapeos. (2) No espera una **moneda concreta por hotel**; la tabla original lo sugería y es incorrecto.

---

## C. Search response: disponibilidad y precio

| Campo | Qué pide PerlaHub | Variantes del proveedor |
|-------|---------------------|---------------------------|
| `rateKey` (= identificador de disponibilidad reservable) | Dato que **identifica una disponibilidad concreta** para Prebook/Book — un "ID" por room o por opción reservable. El nombre "rateKey" es heredado y puede confundir | string / UUID / firmado / con TTL embebido |
| Precio: **modelo declarado** | Net / Commissionable / PVP | declarado / hay que inferir / mezclados |
| Precio: granularidad | `total` + precio **por room** (PerlaHub **NO pide precio por noche**) | total solo / per-night solo / per-room / per-pax |
| Taxes | Separadas vs incluidas + tipo (VAT, city tax) | incluidas / separadas / array / solo total |
| Comisión hotel (commissionable) | `%comisión` explícito | % / importe / no declarada |
| `pvpRequired` flag | Indica si vendido obligatoriamente a PVP | sí flag / no flag (asumir false) |
| Multi-ocupación (totalPax + ages) | Lista de ocupaciones soportadas con precio cada una | array completo / solo principal / hay que pedir search por ocupación |
| `ageRanges` por opción | `[{minAge,maxAge}]` aplicado a precio | rangos explícitos / age categories (Adult/Child/Baby) / age absolute |
| `rooms[]` dentro de opción | Lista de habitaciones de la opción | una por opción / varias / sumadas |
| Disponibilidad (allotment hint) | ⚠️ **NO forma parte del flujo Pull/HUB actual** — no asumir que llega; además no todos los providers lo informan | número / "available" / no se da |
| Restricciones embedded | ⚠️ **Propio de gestión PUSH**, no del flujo Pull/HUB actual | sí en search / solo en prebook / solo error si infringe |

🟢 / 🟡 / 🔴 por cada fila.

> **Corrección Pedro (rev. 18-may)**: (1) "rateKey" es un nombre que confunde — el concepto real es el dato que identifica una disponibilidad reservable (por room o por opción). (2) HUB no pide precio por noche: lo último añadido es **precio por room**. (3) **Disponibilidad** no se ha añadido al flujo HUB; si se añade, ojo porque no todos la informan. (4) **Restricciones** (MinStay, CTA/CTD, stopSale) parecen más de la gestión PUSH que del flujo Pull actual.

---

## D. Cancellation policy

**Lo más variable entre proveedores.** Detallar:

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| **Unidad** de deadline | Fecha absoluta UTC `2026-05-19T22:00:00Z` | fecha absoluta / días antes check-in / horas antes / meses antes / mixta |
| **Granularidad** tramos | Array `[{from,to,percent,refundable}]` con N tramos | un solo tramo / múltiples tramos / por ocupación / per noche |
| **Penalty type** | `amount` (importe) — PerlaHub pide **importe**; el adapter convierte % y noches a importe | % / nights (X noches) / importe fijo / mixto |
| **Timezone** del deadline | Deadlines en UTC; el conector convierte el offset fijo del provider → UTC (sin IANA per-hotel) | UTC explícito / offset fijo (convertir) / sin TZ (revisar) |
| **Refundable** | Flag **general** — `true` si en algún momento se puede cancelar sin coste (NO por tramo) | flag / inferido por % / non-refundable como rate type separado |
| Non-refundable rates | Tipo de rate o flag al inicio | rate type separado (NRF) / flag / siempre 100% penalty desde booking |
| Cancellation con cargo en card | Tipo de penalización aplicada | charge no-show / pre-auth / sin info |

🟢 / 🟡 / 🔴 por cada fila.

> **Trampa clásica**: provider da "deadline = 14 días antes" sin TZ explícito. Hay que averiguar el offset del provider (p.ej. Avoris = GMT+1 fijo) y convertir a UTC. PerlaHub guarda UTC, NO resuelve IANA per-hotel (Decisión P5, verificada en código).
>
> **Corrección Pedro (rev. 18-may)**: (1) PerlaHub pide la penalización como **importe (`amount`)** — el adapter transforma todo (%, noches) a importe. (2) **Refundable** es un flag **general** (true si en algún momento se puede cancelar sin coste), no un flag por tramo. (3) PerlaHub **NO pide** un flag "modificable" separado → fila eliminada.

---

## E. Check-in / check-out

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Horario check-in declarado | `HH:mm` + TZ hotel | hora fija / rango / no declarado |
| Horario check-out declarado | `HH:mm` + TZ hotel | hora fija / rango / no declarado |
| Early check-in soportado | Boolean + posible coste | sí/no flag / coste / no soportado |
| Late check-out soportado | Boolean + posible coste | sí/no flag / coste / no soportado |
| Check-in online | Boolean info | sí/no / link / no info |
| **Día de llegada incluido** en estancia | Sí (convención) | confirma / asume / no declara |
| Día de salida cuenta como noche | No (convención) | confirma / contradice |

🟢 / 🟡 / 🔴 por cada fila.

---

## F. Meal plan en detalle

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Códigos OTA estándar | `RO, BB, HB, FB, AI` | usa OTA / códigos propios / mezcla |
| All-Inclusive variantes | Tratadas como `AI` (variantes en metadata) | `AI` único / múltiples (`AI`, `UAI`, `Soft-AI`, `Premium AI`) |
| Mealplan separado de add-ons | Sí — mealplan = régimen, add-ons aparte | claramente separados / mezclados (bug Expedia mealPlanId mezcla 5 régimenes con 13 add-ons) |
| Mealplan name multilingual | Se ignora (P1: Inventory) | varios idiomas / solo EN / solo idioma local |
| Mealplan a nivel hotel vs por rate | Por rate | solo por rate / por hotel + override / per-room |

🟢 / 🟡 / 🔴 por cada fila.

---

## G. Ocupación, edades y huéspedes

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Modelo ocupación | `adults + children[ages] + babies[ages]` | mismo / `totalPax + ageList` / `adults + child1Age + child2Age` (slots fijos) |
| `ageRanges` | `[{minAge,maxAge}]` configurable por hotel/room | rangos explícitos / categorías (Adult/Child/Baby) con cutoff configurable / hardcoded |
| Edad mínima adulto | Configurable (`adultMinAge`, default 18 o por hotel) | per hotel / global / no soportado |
| Edad máxima baby | Configurable (`babyMaxAge`, default 2) | per hotel / global / hardcoded |
| Bebé cuenta en `maxOccupancy` | Configurable per hotel (`BabyCountsAsOccupancy`) | per hotel / global / no soportado |
| Niños comparten cama | Flag | sí flag / siempre cobra cama extra / depende del rate |
| Free up to age N | Soportado como descuento | edad libre declarada / siempre cobra / rate especial |
| Múltiples rooms en una booking | Sí | sí / solo single-room / multi-room como bookings separadas |
| Datos del titular | Nombre, email, phone | mínimos / amplios (dirección, doc) / opcional |
| Datos de cada huésped | Nombre + edad por huésped | sí lista / solo titular / nombre + ningún age |
| Special requests | Texto libre | sí campo / no soportado / lista de códigos |

🟢 / 🟡 / 🔴 por cada fila.

---

## H. Rate types y promociones

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Rate tipo (NRF / Flex / Advance Purchase / Corporate / Promo) | Identificable por código o flag | rate type taxonomy / flags / inferir por cancellation policy |
| Promociones aplicadas a precio | Visibles en breakdown | descuento separado / precio final / ambos |
| Early Booking | Reconocible (anticipación X días) | rate type / flag / inferir |
| Long Stay | Reconocible (mínimo N noches con descuento) | rate type / minStayBasedRate / no soportado |
| Promo codes (cupones) | Soportable | sí en request / no soportado |
| Honeymoon / Senior / Family | Como rate type o promo | rate / promo / no soportado |
| Loyalty rate (member) | Soportable | sí con member id / no soportado |
| Negotiated rate (corporate) | Soportable con código | sí con corporate code / no soportado |

🟢 / 🟡 / 🔴 por cada fila.

---

## I. Restricciones y allotment

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Allotment | Cantidad disponible por (hotel,room,fecha) | número / "available"/"limited" / no devuelto |
| Allotment pool vs per-room | Por room type (default) | pool compartido / per room / per rate |
| Free sell flag | Boolean | sí flag / siempre asumido / no soportado |
| Stop sale | Devuelve sin opciones o flag | sin opciones / flag explícito / error |
| Release | Días antes check-in | días / fecha absoluta / mixto |
| Min stay | Aplicado | rechaza si infringe / flag / no aplicado |
| Max stay | Aplicado | rechaza si infringe / flag / no aplicado |
| CTA (Closed To Arrival) | Soportable | flag / no soportado |
| CTD (Closed To Departure) | Soportable | flag / no soportado |
| Minimum advance purchase | Soportable | flag / rate type / no soportado |
| On-request rates | Soportable | flag / rate type / no soportado |

🟢 / 🟡 / 🔴 por cada fila.

---

## J. Geolocalización y contenido estático

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Coordenadas lat/lng | Decimal grado | sí / coordenadas inexactas / no soportado |
| Address estructurada | `street, city, postalCode, country, region` | estructurada / single line / parcial |
| Zona/región código | Mapping a zonas PerlaHub | propios / city/state / no devuelto |
| Country | ISO 3166-1 alpha-2 | ISO-2 / ISO-3 / nombre / inferido |
| Phone / fax / email hotel | Strings | sí / parcial / no |
| URLs (booking, hotel site) | Strings | sí / no |
| Imágenes hotel/room | URLs absolutas con tamaños | URLs + tamaños / URLs sin metadata / binarios base64 / no soportado |
| Categorías de imágenes | Lobby/Room/Pool/etc. taxonomía | propios / OTA-like / sin categorizar |
| Stars / categoría | Número 1-5 + tipo | sí / texto / no |
| Amenities hotel/room | Lista códigos PerlaHub catalog | códigos propios / OTA codes / free text |
| Idiomas hablados en hotel | Lista códigos ISO 639-1 | sí ISO / sí nombres / no devuelto |
| Cadena hotelera (chain) | Código + nombre | sí / solo nombre / no |
| Política de mascotas | Boolean + condiciones | flag / texto / no |
| Política wifi/parking/desayuno | Incluido vs no | flag / coste explícito / sin info |

🟢 / 🟡 / 🔴 por cada fila.

---

## K. Book response: locator, estados, errores

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| `confirmationNumber` / locator | String estable y único | string corto (6-8) / largo / con prefijo / múltiples (PNR + locator) |
| Formato locator | Cualquier consistente | numérico / alfanumérico / con sufijos por modificación |
| `200 OK siempre lleva locator` | Obligatorio (incidente TGX 17-mar) | siempre / a veces vacío (BUG TGX) |
| Estados PerlaHub `BookingFlowStatus` (6) | Mapeo a `BOOKED/CANCELLED/ERROR/SIMULATED/CLOSED/BILLED` | provider devuelve `CONFIRMED/PENDING/REJECTED` que hay que mapear / mismos estados / estados propios desconocidos |
| `CONFIRMED` literal del provider → `BOOKED` | Sí | confirmable / `CONFIRMED` también en cancelaciones (ambiguo) |
| Pending/Wait list | Pasarlo a `ERROR` o no aceptar | no soportado / pasar como ERROR / pasar como BOOKED y reconciliar |
| Modificaciones (modify booking) | Soportable | sí (con locator) / solo cancel+rebook |
| Cancellation con cargo | Propaga `cancellationPenalty.amount` | sí campo / no devuelto |
| Refund automático | Indicado en response | sí / manual / partial |
| Códigos error claros | Diferencia dispoless / error provider / error técnico | distingue / todo HTTP 200 + flag / todo HTTP 500 |
| TraceId continuidad search→prebook→book→cancel | Mismo identificador propagable | sí / cada op su id / no soportado |

🟢 / 🟡 / 🔴 por cada fila.

---

## L. Auth y operativa

| Aspecto | Qué pide PerlaHub | Variantes del proveedor |
|---------|---------------------|---------------------------|
| Mecanismo auth | Bearer / OAuth2 / HMAC / IP whitelist / Basic | Bearer simple / OAuth2 token endpoint / HMAC body fingerprint / Basic legacy / SOAP+WS-Security |
| Permanent token | Sí (sin renovación por sesión) | sí / OAuth2 con refresh / sesión corta (renovar c/N min) |
| IP whitelist | Aceptable si previsible | sí (con lista pública) / sí dinámico / no requerido |
| Multi-tenancy | Per credencial cliente | per credencial / per IP / per API key global (compartida) |
| Rate limit | Declarado por provider | declarado / no declarado (probar) / por endpoint / por hotel |
| TTL rateKey | Declarado explícito | sí en response / fijo doc / variable / sin info |
| Idempotencia book (`clientReference`) | Reintento NO duplica reserva | sí (clientReference) / sí (header) / no soportado |
| Mercados/nationalities permitidos | Compatibilidad con clientes PerlaHub | lista permitidos / blacklist (caso BY rejected) / sin restricción |
| Currencies operadas | Match con `Hotel.CurrencyCode` | múltiples / per hotel / global |
| Async / sync book | Sync preferido | sync / async (con polling de estado) |
| Stateful sessions | Stateless preferido | stateless / open/close session obligatorio |

🟢 / 🟡 / 🔴 por cada fila.

---

## M. Decisiones no-negociables (P1-P6)

| ID | Decisión | El proveedor lo respeta |
|----|----------|--------------------------|
| **P1** | Nombres (hotel/room/meal/amenity) vienen del Inventory PerlaHub — proveedor solo aporta **códigos** | siempre ✓ (interno) |
| **P2** | PVP no recibe markup. Si el provider declara PVP, debe ser consistente y `pvpRequired:true` honrado | 🟢 / 🟡 / 🔴 |
| **P3** | Re-mapping preserva matches PH↔nombre como oro | siempre ✓ (interno) |
| **P4** | RoomTypes/Amenities solo del catálogo PerlaHub. Provider manda código, nosotros mapeamos | provider tiene catálogo razonable: 🟢 / 🟡 / 🔴 |
| **P5** | Cancellation timezone = deadlines en UTC; conector convierte el offset fijo del provider → UTC (sin IANA per-hotel) | provider da offset claro: 🟢 convierte / 🟡 ambiguo / 🔴 sin offset |
| **P6** | Validación previa a cualquier escritura PROD | siempre ✓ (interno) |

> Cualquier 🔴 en P1-P6 fuera de los "siempre interno" → **HITL bloqueante**, reunión Pedro+Eva+Santi.

---

## N. Veredicto

1. Cuenta tus marcas: total 🟢, 🟡, 🔴.
2. Verifica que los 🔴 NO sean en filas obligatorias (operaciones, IDs, modelo precio, locator).

| Tu score | Tipo conexión | Estimación adapter |
|----------|----------------|----------------------|
| 0 🟡, 0 🔴 en obligatorios | Modo A directo — patrón Dome/TGX puro | 2-3 días config + tests |
| 1-5 🟡 | Modo B ligero (tipo Hotelbeds) | 1 semana |
| 6-12 🟡 | Modo B medio (tipo Expedia / Travelgate) | 2 semanas |
| 13+ 🟡 o cualquier 🔴 obligatorio | Caso especial | Reunión antes de empezar |

### Banderas rojas automáticas (zona de reunión obligatoria)

Si cualquiera de estas → para y escala:

- 🔴 en `Search`, `Prebook`, `Book` o `Cancel` (operaciones obligatorias)
- 🔴 en formato locator o "200 OK siempre lleva locator"
- 🔴 en modelo de precio declarado (Net / Commissionable / PVP)
- 🔴 en TZ de cancellation policy (P5)
- 🔴 en mercados permitidos (caso Travel Code BY)
- 🔴 en `clientReference` idempotencia book
- Provider con sessions stateful + load balancer (sticky session requerido)
- Provider con OAuth2 corto (renew cada < 5 min)
- Provider sin `rateKey` o con `rateKey` no-opaque (lo construyen los clientes)
- Provider que mezcla mealplans con add-ons sin diferenciar (caso Expedia 5+13)

---

## O. Antes de empezar el código

- [ ] Tienes credenciales en **sandbox/test** del proveedor (no PROD del cliente)
- [ ] Tienes ejemplos REALES de Search, Prebook, Book, Cancel (XML o JSON)
- [ ] Tienes la doc API oficial del proveedor (URL, versión, lenguaje)
- [ ] Conoces el equivalente más cercano ya conectado: Dome / Travelgate / Hotelbeds / Expedia / PerlaPush / PushInternal
- [ ] Has revisado [factory_pull_validaciones.md §11](./factory_pull_validaciones.md) (47 ítems Definition of Done técnico)
- [ ] **Audit es parte del DoD, no opcional**: el `Gateway` del conector debe emitir `AddAuditRq` (pasar `auditRq`, no `null`, a `SendAsync`) igual que `Hotelbeds/Operations/Common/Gateway.cs`, y verificarse contra la Audit API local (§ Capa 8). El audit del provider lo emite el **conector**, no el Core — si no se cablea, falla en silencio (API levanta y da 200 igual)
- [ ] Avoris confirmado como piloto Pull → correcciones sobre Avoris → mejoras Skill v1
- [ ] Has marcado bugs históricos a no repetir: TGX empty locator, Dome price-changed, WHL pvpRequired, Travel Code BY, Expedia mealPlan add-ons, audit gap TraceId

---

## Apéndice — para el detalle técnico

→ [factory_pull_validaciones.md](./factory_pull_validaciones.md) — 9 capas + 18 AuditTypes + bugs históricos + DoD 47 ítems
→ [factory_pull_briefing_v0.md](./factory_pull_briefing_v0.md) — proceso 11 pasos + 4 HITL gates
→ [pull-skill-2026-05-11.md](./pull-skill-2026-05-11.md) — Skill ejecutable Claude Code
