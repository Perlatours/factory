# avoris-pull · STATE

_Auto-generado. Última actualización: 2026-05-26 14:17:25 UTC_

## Resumen

- **Factory**: pull
- **Modo**: —
- **Fase actual**: 2
- **Status**: active
- **DEV**: not_deployed  |  **PROD**: not_deployed
- **Owner HITL**: Pedro
- **Contacto**: Vanesa <vanesa@avoris.example>
- **Volumen**: 150 hoteles · 2 clientes · 50 htls/request · frecuencia diaria

## HITL Gates

| # | Título | Status | Aprobador | Fecha |
|---|---|---|---|---|
| 1' | 'Revisión análisis (Fase 1)' | 'approved' | 'Pedro' | '2026-05-26 14:17:25.752504+00 |
| 2' | 'Aprobar mismatches y wrappers (Fase 4)' | 'pending' | '—' | '— |
| 3' | 'Aprobar PR código (Fase 6)' | 'pending' | '—' | '— |
| 4' | 'Go-live PROD (Fase 8)' | 'pending' | '—' | '— |

## Phase log (últimas 10)

| De | A | Actor | Cuándo | Notas |
|---|---|---|---|---|
| 1' | '2' | 'Pedro/factory-review' | '2026-05-26 14:17:25.752504+00' | 'HITL #1 (revision analisis) aprobado -> avanza a Fase 2 (sandbox) |
| 0' | '1' | 'claude/factory-new' | '2026-05-26 08:58:02.094829+00' | 'Intake OK · 4 criterios cumplen (ensayo) |

## Sorpresas abiertas

- **Timezone deadlines: PerlaHub guarda UTC (no IANA); Avoris GMT+1 -> conector resta 1h** — VERIFICADO EN CODIGO: PerlaHub guarda deadlines en UTC (DB model //UTC; DateTimeKind.Utc) y NO usa IANA/TimeZoneInfo/CET. El conector entrega UTC (TGX hace SpecifyKind(Utc) porque su provider ya da UTC). Avoris opera en GMT+1 fijo -> el conector Avoris debe convertir GMT+1->UTC (-1h fijo). CORREGIDO en el canonico (P5 + plantilla + docs, 2026-05-26): el expected ya no dice UTC+IANA per-hotel.
- **bookToken TTL = 58 min (Prebook->Book)** — El bookToken caduca a 58 min entre Prebook y Book (error Booktoken expired -> nueva search). Primer TTL medido en la planta Pull; muy por encima del umbral RateKeyBuffer (<10min).
- **Penalidad 100% en estancia NO viene via API** — Cualquier cancelacion entre check-in y check-out aplica 100% penalidad, pero NO aparece en cancellationPolicies; la doc lo dice en texto. Hay que asumirlo en el wrapper de politicas.
- **Parity estricta Prebook->Book (sin tolerancia book-side)** — Cualquier diff de precio/politica entre Prebook y Book devuelve ERROR_GENERAL_PROVIDER. Cambios solo permitidos Avail->Prebook. No hay tolerancia en el paso Book.
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
| F' | '0' | '2' | '0' | '0 |
| G' | '3' | '0' | '0' | '0 |
| H' | '1' | '1' | '0' | '0 |
| I' | '0' | '0' | '0' | '2 |
| J' | '1' | '1' | '0' | '0 |
| K' | '2' | '2' | '0' | '0 |
| L' | '1' | '3' | '0' | '0 |
