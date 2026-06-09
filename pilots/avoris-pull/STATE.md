# avoris-pull · STATE

_Auto-generado. Última actualización: 2026-06-09 10:28:10 UTC_

## Resumen

- **Factory**: pull
- **Modo**: —
- **Fase actual**: 5
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
| 4' | '5' | 'claude/factory-pull' | '2026-06-09 10:26:57.53635+00' | 'HITL #2 aprobado (Pedro). Avanza a Fase 5 informe final. |
| 3' | '4' | 'claude/factory-pull' | '2026-06-09 10:05:19.565863+00' | 'Mock Tests Fase 3: 7/7 PASS en PRO (coste 0). Hallazgos: pricing total no-nightly, single-currency EUR, cancel necesita retry. Avanza a Fase 4 Mismatches. |
| 2' | '3' | 'claude/factory-pull' | '2026-06-09 08:24:51.49231+00' | 'Sandbox Fase 2 PASS (flujo E2E 6/6 en PRO, reserva 802885266 creada+cancelada coste 0). Avanza a Fase 3 Mock Tests. |
| 1' | '2' | 'Pedro/factory-review' | '2026-05-26 14:17:25.752504+00' | 'HITL #1 (revision analisis) aprobado -> avanza a Fase 2 (sandbox) |
| 0' | '1' | 'claude/factory-new' | '2026-05-26 08:58:02.094829+00' | 'Intake OK · 4 criterios cumplen (ensayo) |

## Sorpresas abiertas

- **Cancel inmediato tras Book falla: "Booking does not exist" (latencia propagacion)** — Tras un Book CONFIRMED, cancelar de inmediato devuelve ERROR_BOOKCENTER_NOT_LODGING_EXCEPTION "Booking does not exist" - la reserva confirma pero tarda en propagarse al subsistema de cancelacion (eventual consistency). Reintentando ~3-6s despues, cancela OK (status CANCEL). Confirmado en vivo PRO 2026-06-09 con reserva 802886128. IMPLICACION conector: el wrapper de Cancel necesita retry con backoff (BackoffExpStrategy) ante NOT_LODGING tras un book reciente, y tratar ALREADY_BOOK_CANCEL/CANCEL como exito idempotente.
- **Cuenta Perlatours es single-currency EUR (divisa NO forzable por request)** — El campo currency en searchAvail NO fuerza la divisa: pedido USD devuelve igualmente EUR. La cuenta 4144001 esta configurada single-currency EUR. El doc decia "depende de config (single/multi-currency)" -> confirmado single. IMPLICACION: CurrencyForcer NO aplica para esta cuenta; PerlaHub recibe siempre EUR. Si se necesita multi-currency, pedir a Avoris reconfig de cuenta.
- **Voucher trae empresa facturadora (issuingBrand) variable** — BookRS devuelve voucher.payable + voucher.issuingBrand con la empresa del grupo Avoris que factura. Observado: "Alisios Tours, S.L." / 052035 (catalogo PDF: 052035=Alisios, 166030=Planet, 164020=Orbe, 047036=Travelsens). PerlaHub debe leer/conservar issuingBrand por reserva.
- **travellers[].index = indice de HABITACION, no de pasajero** — En BookRQ, index de cada traveller identifica la HABITACION (los N pax de una habitacion comparten index), NO es indice secuencial por pasajero. Para [30,30] ambos adultos van con index=1. Poner 1 y 2 da ERROR_GENERAL_ERROR_REQUEST "Traveller ages mismatch". Confirmado en vivo PRO 2026-06-09.
- **Estados de reserva mas amplios que el PDF (ON_REQUEST, PRICE_CHANGED, PROVIDER_CHANGED, WARNING)** — El Swagger public revela mas estados que los 4 del PDF (CONFIRMED/ALREADY_CONFIRMED/ERROR/CANCEL). PreBooking/Booking incluyen ON_REQUEST. BookingDetail/Cancellation incluyen ademas EMPTY, PRICE_CHANGED, PROVIDER_CHANGED, WARNING, ALREADY_BOOK_CANCEL. Implicacion: PH debe manejar (a) flujo on-request (no instant-confirm), (b) reconciliacion price-changed/provider-changed entre prebook/book/detail.
- **Swagger/OpenAPI de Polaris es PUBLICO (resuelve acceso a doc)** — Los specs OpenAPI estan accesibles sin auth en polarisapi.avoristravel.com/avail|book|staticdata/v2/api-docs?group=Public (y el UI en swagger-ui-polaris.barceloviajes.com/polaris). Resuelve Q#1 (no hace falta invitacion) y permite resolver varias G3 (amenities, imagenes, rate types) leyendo el spec staticdata/book.
- **Penalidad 100% en estancia NO viene via API** — Cualquier cancelacion entre check-in y check-out aplica 100% penalidad, pero NO aparece en cancellationPolicies; la doc lo dice en texto. Hay que asumirlo en el wrapper de politicas.
- **bookToken TTL = 58 min (Prebook->Book)** — El bookToken caduca a 58 min entre Prebook y Book (error Booktoken expired -> nueva search). Primer TTL medido en la planta Pull; muy por encima del umbral RateKeyBuffer (<10min). || CONFIRMADO EN VIVO (PRO 2026-06-04): la respuesta del prebook expone el campo ttl explicito = 3360s (56 min). RateKeyBuffer puede leer el TTL dinamicamente del RS en vez de hardcodear 58min.
- **Parity estricta Prebook->Book (sin tolerancia book-side)** — Cualquier diff de precio/politica entre Prebook y Book devuelve ERROR_GENERAL_PROVIDER. Cambios solo permitidos Avail->Prebook. No hay tolerancia en el paso Book.
- **Timezone deadlines: PerlaHub guarda UTC (no IANA); Avoris GMT+1 -> conector resta 1h** — VERIFICADO EN CODIGO: PerlaHub guarda deadlines en UTC (DB model //UTC; DateTimeKind.Utc) y NO usa IANA/TimeZoneInfo/CET. El conector entrega UTC (TGX hace SpecifyKind(Utc) porque su provider ya da UTC). Avoris opera en GMT+1 fijo -> el conector Avoris debe convertir GMT+1->UTC (-1h fijo). CORREGIDO en el canonico (P5 + plantilla + docs, 2026-05-26): el expected ya no dice UTC+IANA per-hotel.
- **City tax / resort fees solo en observations (texto libre)** — comTax (comision) estructurado, pero city tax y resort fees solo como texto libre en observations. Requiere parseo; riesgo de no capturarlos de forma fiable. [DECISION rev:Pedro: NO parsear city tax/resort fees a campos; pasar observations tal cual como comentario.]
- **bookingDetails por fecha es PRO-only (no testeable en TST)** — Busqueda por STAYDATE/CREATIONDATE solo en PRO, no en sandbox TST. En TST solo bookingDetail por bookingReferenceID. Validar GetBookings por fecha queda para PRO.

## Checklist (resumen por sección)

| Sección | 🟢 | 🟡 | 🔴 | n/a |
|---|---|---|---|---|
| A' | '6' | '0' | '0' | '0 |
| B' | '0' | '4' | '0' | '0 |
| C' | '3' | '2' | '0' | '0 |
| D' | '1' | '2' | '0' | '0 |
| E' | '0' | '2' | '0' | '0 |
| F' | '0' | '1' | '0' | '1 |
| G' | '3' | '0' | '0' | '0 |
| H' | '1' | '1' | '0' | '0 |
| I' | '0' | '0' | '0' | '2 |
| J' | '2' | '0' | '0' | '0 |
| K' | '2' | '2' | '0' | '0 |
| L' | '2' | '2' | '0' | '0 |
