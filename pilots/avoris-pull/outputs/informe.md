# Informe final — Avoris (Polaris) · Pull nativo

_Fase 5 · Generado 2026-06-09 · Piloto Pull v0 (primera conexión de la planta)_

## Veredicto: ✅ **PROCEDER a Fase 6 (codificación)** · Score **11/15**

Conexión **viable sin bloqueantes**. Flujo completo validado end-to-end contra el sistema real
(reserva creada y cancelada, coste 0). 0 gaps rojos. Toda la complejidad se cubre con wrappers
Core ya existentes — ninguno nuevo.

---

## Score por ejes (0–3)

| Eje | Score | Base |
|---|---|---|
| **1. Cobertura funcional** | **3** | Flujo completo avail→prebook→book→cancel→bookingDetail + Portfolio API, todo probado E2E en PRO |
| **2. Calidad de datos / mapeo** | **2** | Pricing claro (sell/net/comisión/binding), geo+imágenes OK; pero room/meal/amenity requieren mapeo, pricing es total no-nightly, city tax en texto libre |
| **3. Complejidad de integración** | **2** | 5 wrappers Core, **todos existentes**; matices: index=habitación, parity estricta Prebook→Book |
| **4. Estabilidad / fiabilidad** | **2** | Latencias buenas (0.2–1.7s); pero cancel necesita retry (propagación), race avail→prebook, 429 sin cifras |
| **5. Documentación / soporte** | **2** | PDF + Swagger público sólidos; gaps: auth no documentado en PDF, TST muerto, check-in/out times ausentes |
| **TOTAL** | **11/15** | Viabilidad alta |

---

## Validación realizada (evidencia)

| Fase | Resultado | Evidencia |
|---|---|---|
| 2 · Sandbox | E2E **6/6 PASS** (PRO) · reserva 802885266 creada+cancelada coste 0 | `evidence/sandbox-pro-20260609-e2e/` |
| 3 · Mock tests | **7/7 PASS** (PRO, coste 0) | `evidence/mocktests-20260609/` |
| 4 · Mismatches | 16 clasificados, **0 rojos** | `outputs/mismatches-classified.md` |

> Nota: TST de Avoris no certificable aún (creds muertas) — toda la validación se hizo contra PRO
> con tarifas reembolsables + cancelación inmediata (coste 0), avalado por §2.2 de la doc.

---

## Wrappers Core necesarios (todos ya en catálogo)

| Wrapper | Para | Disparador |
|---|---|---|
| `RateKeyBuffer` | bookToken | TTL ~56min (campo `ttl` explícito en RS) |
| `TimezoneResolver` | deadlines cancelación | GMT+1 → UTC (−1h fijo) |
| `BackoffExpStrategy` | cancel, rate-limit | retry cancel + HTTP 429 |
| `CoreCancelNotFound` | cancel | "Booking does not exist" post-book + idempotencia ALREADY_BOOK_CANCEL |
| `PriceChangedTolerance` | prebook | tolerancia Avail→Prebook (NO Prebook→Book) |

`CurrencyForcer` **descartado** — cuenta single-currency EUR.

---

## Gaps rojos: ninguno

## Sorpresas (13 · siembran Anexo D)

Críticas para el conector:
1. **travellers[].index = habitación** (no pasajero) — error "ages mismatch" si se confunde.
2. **Cancel inmediato falla** ("Booking does not exist") → retry+backoff obligatorio.
3. **Parity estricta Prebook→Book** — cualquier diff = ERROR; sin tolerancia book-side.
4. **Estados ampliados** (ON_REQUEST, PRICE_CHANGED…) — manejar on-request + reconciliación.
5. **Penalidad 100% in-stay NO viene por API** — asumir en wrapper de políticas.
6. **Single-currency EUR**, **city tax en observations**, **bookToken TTL dinámico**, **bookingDetails por fecha PRO-only**, **timezone GMT+1**, **Swagger público**.

---

## Pendiente de Avoris (no bloqueante · `outputs/preguntas-avoris.md`)

- Credenciales TST válidas (o certificar contra PRO).
- Cifras de rate limits (429), política de rotación de credenciales.
- check-in/check-out time del hotel; estabilidad de Codigo AVO.

---

## Métricas del proceso (planta)

- **Tiempo total del proceso:** 14.06 días de calendario (26-may → 9-jun).
- **Tiempo efectivo de trabajo:** 8.63 h en 4 días.
- Fases 1–5 completas; HITL #1 y #2 aprobados (Pedro).

## Siguiente
**Fase 6 (codificación)** en el repo PerlaHub — fuera de la planta. Gate #3 (aprobar PR) y #4 (go-live)
quedan para esa etapa.
