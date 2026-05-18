# {{CLIENT}} · Espejo TGX · Overview

> Cliente ya conectado a TravelGate que se redirige a PerlaHub cambiando solo endpoint. Validación + simulador HTTP, no nuevo conector.

## Inputs Fase 0 Intake (Espejo)

- [ ] Logs reales del cliente conectado a TGX (escenarios A/B/C)
- [ ] Credenciales del cliente en PerlaHub supplier-side
- [ ] Contacto técnico cliente
- [ ] Volumen tráfico TGX estimado

## Fases (5 + 1 HITL)

| Fase | Acción |
|---|---|
| 0 | Intake (logs cliente) |
| 1 | Validar auth supplier-side estricta (sin fallback) |
| 2 | Validar shape request/response |
| 3 | Simulador HTTP comparativo TGX↔PerlaHub |
| 4 | Lista mismatches → corregir |
| 5 | Go-live (cambio endpoint cliente) |
