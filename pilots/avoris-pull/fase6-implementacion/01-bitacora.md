# Bitácora Fase 6 — Implementación conector Avoris

_Trabajo autónomo iniciado 2026-06-09. Registro cronológico de decisiones, hallazgos y bloqueos._
_Referencia de criterios: `00-PROMPT-original.md`. Dudas/bloqueos formales en `02-dudas-bloqueos.md`._

## Estado del objetivo
- [x] API 1 (Search/Prebook) levanta y completa operaciones contra mocks ✅
- [x] API 2 (Book/Cancel/GetBooking) levanta y completa operaciones contra mocks ✅
- [x] API 3 (Statics, 7 catálogos) levanta y completa operaciones contra mocks ✅
- [⛔] Validación PRO API 1 y 3 — BLOQUEADA: no hay credenciales avoris-PRO (condicional no cumplida)
- [x] Documentación (03-resultado-ejecucion.md) + revisión final contra el prompt

> Detalle de resultados y limitaciones en `03-resultado-ejecucion.md`. Build solución = 0 errores.

## Log

### 2026-06-09 — Setup y reconocimiento
- Repo PerlaHub ya en rama **`feature/AvorisConnector`** (requisito rama dedicada ✅).
- `Connectors/Accommodation/` contiene conectores de referencia: **Hotelbeds** (referencia mental), Expedia, Travelgate, Dome, PerlaPush. **No existe `Avoris/`** todavía.
- Patrón de proyecto por conector (a replicar para Avoris):
  - `AvailabilityApi/` → **API 1** (Search/Prebook)
  - `ReservationApi/` → **API 2** (Book/Cancel/GetBooking)
  - `StaticsApi/`     → **API 3** (Statics)
  - `Operations/`     → lógica que implementa los contratos del Core
  - `Dto/`            → modelos del provider
  - `Test/`           → pruebas
  - `Connectors.Accommodation.<Conector>.sln`
