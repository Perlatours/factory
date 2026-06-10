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

### 2026-06-10 — Fix multi-room (post-validación PRO)
- **Bug detectado al probar multi-room** (search 2 ocupaciones): `SearchRsMapper.MapRooms` asignaba
  `rate.pricing` (TOTAL de la opción) a **cada** room → `option.Price ≠ Σ rooms` y la `cancelPolicy`
  (de opción) quedaba desincronizada respecto a las rooms infladas. **Causa de fondo**: cada room debe
  llevar su **propio** `rooms[i].pricing` (Avoris da option = Σ rooms; verificado en evidencia).
- **No se detectó antes** porque el `MockGateway` servía un `avail.json` fijo single-room → la rama
  multi-room nunca se ejercitaba.
- **Fix**: `MapRooms` usa `rooms[i].pricing` (fallback reparto a partes iguales); la opción mantiene
  `rate.pricing` como total. Verificado: NRF 930.14 = 2×465.07, refundable 1307.36 = 2×653.68, tramos OK.
- **Anti-regresión**: añadido fixture `Operations/MockData/avail-multiroom.json` (datos reales) +
  `MockGateway` lo sirve cuando la RQ trae >1 habitación. Trasladado al flujo factory:
  `factory_pull_validaciones.md` (Capa 4 + §11 + bug histórico), `factory-mocktests` y `factory-implement`.

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
