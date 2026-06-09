# avoris-pull · STATE

_Auto-generado. Última actualización: 2026-06-09 18:05:37 UTC_

## Resumen

- **Factory**: pull
- **Modo**: —
- **Fase actual**: 6
- **Status**: active
- **DEV**: not_deployed  |  **PROD**: not_deployed
- **Owner HITL**: Pedro
- **Contacto**: Vanesa <vanesa@avoris.example>
- **Volumen**: 150 hoteles · 2 clientes · 50 htls/request · frecuencia diaria

## HITL Gates

| # | Título | Status | Aprobador | Fecha |
|---|---|---|---|---|
| 1' | 'Revisión análisis (Fase 1)' | 'approved' | 'Pedro' | '2026-05-26 14:17:25.752504+00 |
| 2' | 'Aprobar mismatches y wrappers (Fase 4)' | 'approved' | 'Pedro' | '2026-06-09 10:26:57.532492+00 |
| 3' | 'Aprobar PR código (Fase 6)' | 'pending' | '—' | '— |
| 4' | 'Go-live PROD (Fase 8)' | 'pending' | '—' | '— |

## Phase log (últimas 10)

| De | A | Actor | Cuándo | Notas |
|---|---|---|---|---|
| 5' | '6' | 'Pedro' | '2026-06-09 18:05:27.290506+00' | 'Informe final Fase 5 REVISADO y APROBADO por Pedro (revisión HITL mediante seguimiento detallado). 8 ajustes registrados en sorpresas/checklist: #16 index, #10 paridad, #9 penalidad in-stay (corregida), #18 cancel (rebajada), #20 colapso variantes (a negocio), id_room_codes/id_amenities cableado, meal_codes_mapping resuelto. Informe regenerado limpio (commits 1373845 + f82bf42). Conexión pasa a Fase 6 (codificación, en PerlaHub, fuera de la planta). NOTA: el gate HITL #3 (Aprobar PR código) SIGUE PENDIENTE — se aprobará cuando exista el PR. |
| 4' | '5' | 'claude/factory-pull' | '2026-06-09 10:26:57.53635+00' | 'HITL #2 aprobado (Pedro). Avanza a Fase 5 informe final. |
| 3' | '4' | 'claude/factory-pull' | '2026-06-09 10:05:19.565863+00' | 'Mock Tests Fase 3: 7/7 PASS en PRO (coste 0). Hallazgos: pricing total no-nightly, single-currency EUR, cancel necesita retry. Avanza a Fase 4 Mismatches. |
| 2' | '3' | 'claude/factory-pull' | '2026-06-09 08:24:51.49231+00' | 'Sandbox Fase 2 PASS (flujo E2E 6/6 en PRO, reserva 802885266 creada+cancelada coste 0). Avanza a Fase 3 Mock Tests. |
| 1' | '2' | 'Pedro/factory-review' | '2026-05-26 14:17:25.752504+00' | 'HITL #1 (revision analisis) aprobado -> avanza a Fase 2 (sandbox) |
| 0' | '1' | 'claude/factory-new' | '2026-05-26 08:58:02.094829+00' | 'Intake OK · 4 criterios cumplen (ensayo) |

## Sorpresas abiertas

- **Avoris sin room-amenities → variantes de room colapsan en 1 sola Room de inventario (INFO A NEGOCIO)** — Avoris no expone características de habitación estructuradas EN EL FLUJO DE SEARCH (search rooms = solo id/configuration/name/pricing; el hotelInformation revisado solo trae amenities hotel-level type=SERVICES; 0 arrays de room-amenities en la evidencia disponible). En el inventario PerlaHub, Room = RoomTypeId + RoomAmenityIds; sin fuente para RoomAmenityIds queda VACÍO, y todas las variantes físicas bajo un mismo rooms[].id (p.ej. D|2C "2 camas" vs "2 camas + sofá-cama"; ROH = Run-Of-House con 3+ tipologías) COLAPSAN en una única Room de inventario. La única diferencia vive en name (texto libre) y el search canónico (CoreOptionRoom) no tiene slot para RoomName.


- **Cuenta Perlatours es single-currency EUR (divisa NO forzable por request)** — El campo currency en searchAvail NO fuerza la divisa: pedido USD devuelve igualmente EUR. La cuenta 4144001 esta configurada single-currency EUR. El doc decia "depende de config (single/multi-currency)" -> confirmado single. IMPLICACION: CurrencyForcer NO aplica para esta cuenta; PerlaHub recibe siempre EUR. Si se necesita multi-currency, pedir a Avoris reconfig de cuenta.
- **Cancel inmediato tras Book: fallo NOT_LODGING observado solo en MOCK (no reproducido en E2E real)** — ESTATUS DE EVIDENCIA (revisado 2026-06-09, Pedro):

- El error ERROR_BOOKCENTER_NOT_LODGING_EXCEPTION "Booking does not exist" tras un Book reciente aparece ÚNICAMENTE en un MOCK: mocktests-20260609/7-cancel.json, con token "perla-mock" (fixture fabricado, NO respuesta real del provider; una respuesta real llevaría token api-…).
- El E2E REAL (reserva 802885266: book CONFIRMED → detail CONFIRMED → cancel CANCEL → detail CANCEL) canceló LIMPIO a la primera, sin error y sin retry (notes: null).
- La "ventana de propagación ~3-6s" NO tiene respaldo: no hay ni un timestamp en los ficheros de cancel (solo creationDate sin hora). Cifra sin medir.
- "Confirmado en vivo PRO con 802886128": el cancel de 802886128 no está en el E2E; su único artefacto es el mock.


- **Voucher trae empresa facturadora (issuingBrand) variable** — BookRS devuelve voucher.payable + voucher.issuingBrand con la empresa del grupo Avoris que factura. Observado: "Alisios Tours, S.L." / 052035 (catalogo PDF: 052035=Alisios, 166030=Planet, 164020=Orbe, 047036=Travelsens). PerlaHub debe leer/conservar issuingBrand por reserva.
- **travellers[].index en BookRQ = rooms[].index devuelto por Prebook RS** — Regla de codificacion: travellers[].index en BookRQ debe REFLEJAR el rooms[].index que devuelve la respuesta de Prebook. El conector construye la info de pax por habitacion leyendo el index de cada room del Prebook RS (no un contador secuencial por pasajero); todos los pax de una misma habitacion comparten el index de esa room. Evidencia: Prebook single-room emite index=1; Prebook multi-room emite index=1 e index=2 (mock 3-multiroom-prebook.json). Confirmado E2E solo single-room (book con ambos pax index=1, PRO 2026-06-09); poner 1 y 2 a los 2 pax de UNA habitacion da GENERAL_ERROR_REQUEST "Traveller ages mismatch". PENDIENTE: book+cancel multi-room real para confirmar que travellers con index=2 (2a habitacion) produce CONFIRMED -- inferido de la estructura prebook->book, no probado E2E.
- **Estados de reserva mas amplios que el PDF (ON_REQUEST, PRICE_CHANGED, PROVIDER_CHANGED, WARNING)** — El Swagger public revela mas estados que los 4 del PDF (CONFIRMED/ALREADY_CONFIRMED/ERROR/CANCEL). PreBooking/Booking incluyen ON_REQUEST. BookingDetail/Cancellation incluyen ademas EMPTY, PRICE_CHANGED, PROVIDER_CHANGED, WARNING, ALREADY_BOOK_CANCEL. Implicacion: PH debe manejar (a) flujo on-request (no instant-confirm), (b) reconciliacion price-changed/provider-changed entre prebook/book/detail.
- **Swagger/OpenAPI de Polaris es PUBLICO (resuelve acceso a doc)** — Los specs OpenAPI estan accesibles sin auth en polarisapi.avoristravel.com/avail|book|staticdata/v2/api-docs?group=Public (y el UI en swagger-ui-polaris.barceloviajes.com/polaris). Resuelve Q#1 (no hace falta invitacion) y permite resolver varias G3 (amenities, imagenes, rate types) leyendo el spec staticdata/book.
- **bookToken TTL = 58 min (Prebook->Book)** — El bookToken caduca a 58 min entre Prebook y Book (error Booktoken expired -> nueva search). Primer TTL medido en la planta Pull; muy por encima del umbral RateKeyBuffer (<10min). || CONFIRMADO EN VIVO (PRO 2026-06-04): la respuesta del prebook expone el campo ttl explicito = 3360s (56 min). RateKeyBuffer puede leer el TTL dinamicamente del RS en vez de hardcodear 58min.
- **City tax / resort fees solo en observations (texto libre)** — comTax (comision) estructurado, pero city tax y resort fees solo como texto libre en observations. Requiere parseo; riesgo de no capturarlos de forma fiable. [DECISION rev:Pedro: NO parsear city tax/resort fees a campos; pasar observations tal cual como comentario.]
- **Timezone deadlines: PerlaHub guarda UTC (no IANA); Avoris GMT+1 -> conector resta 1h** — VERIFICADO EN CODIGO: PerlaHub guarda deadlines en UTC (DB model //UTC; DateTimeKind.Utc) y NO usa IANA/TimeZoneInfo/CET. El conector entrega UTC (TGX hace SpecifyKind(Utc) porque su provider ya da UTC). Avoris opera en GMT+1 fijo -> el conector Avoris debe convertir GMT+1->UTC (-1h fijo). CORREGIDO en el canonico (P5 + plantilla + docs, 2026-05-26): el expected ya no dice UTC+IANA per-hotel.
- **bookingDetails por fecha es PRO-only (no testeable en TST)** — Busqueda por STAYDATE/CREATIONDATE solo en PRO, no en sandbox TST. En TST solo bookingDetail por bookingReferenceID. Validar GetBookings por fecha queda para PRO.
- **Penalidad 100% in-stay SÍ viene por API (en cancellationPolicies) — corrige afirmación previa** — CORRECCIÓN (revisado 2026-06-09, Pedro): la versión previa afirmaba que la penalidad 100% in-stay NO aparece en cancellationPolicies y había que asumirla en el wrapper. FALSO.


- **Paridad estricta Prebook→Book: token literal con precio congelado + pax coherente con el token** — La "paridad" Prebook→Book NO es que Book compare campos contra Prebook; tiene dos caras, ambas verificadas E2E (PRO 2026-06-09):




## Checklist (resumen por sección)

| Sección | 🟢 | 🟡 | 🔴 | n/a |
|---|---|---|---|---|
| A' | '6' | '0' | '0' | '0 |
| B' | '0' | '4' | '0' | '0 |
| C' | '3' | '2' | '0' | '0 |
| D' | '1' | '2' | '0' | '0 |
| E' | '0' | '2' | '0' | '0 |
| F' | '1' | '0' | '0' | '1 |
| G' | '3' | '0' | '0' | '0 |
| H' | '1' | '1' | '0' | '0 |
| I' | '0' | '0' | '0' | '2 |
| J' | '2' | '0' | '0' | '0 |
| K' | '2' | '2' | '0' | '0 |
| L' | '2' | '2' | '0' | '0 |
