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

### 2026-06-11 — Decisión P8: estáticos por sync externo (StaticsApi fuera del conector)
- Decidido gestionar estáticos por un **proceso de sincronización de contenidos independiente** del conector
  (no por el conector). Registrado como **P8** (refina P7) en `catalog/decisions-p1-p6.md`. Conector nuevo = **2 APIs**.
- Flujo actualizado para futuros conectores: `factory-implement` (estructura 2 APIs + nota P8; deploy/tests sin statics),
  `factory_pull_validaciones.md` §11 (deploy y audit a 2 APIs) y `factory_pull_checklist.md` (fila Static = N/A en conector).
- **Avoris (decisión Pedro 2026-06-11): NO tocar ahora.** Su `StaticsApi` + `Operations/Static.cs` + mocks de statics
  + systemd/configure/jobs de statics + mapeo statics en run-tests quedan como **pendiente de limpieza** (cuando se
  retire, conector pasa a 2 APIs). No bloquea el flujo de reservas (statics ya no depende del conector).

### 2026-06-10 — Proyecto Test + mapeo run-tests
- El job `run-tests` del deploy fallaba (exit 1, "No test mapping for avoris-availability-api") y el
  conector **no tenía tests** (limitación anotada en F6). Resuelto: proyecto `Test/` (xunit+FluentAssertions+Moq,
  molde Hotelbeds) + mapeo `avoris-*-api → Connectors/Accommodation/Avoris/Test` en ambos `deploy-all-*`.
- **12 tests verdes**: SearchRsMapper (multi-room `option==Σrooms`/precio por-room, single, refundable por
  rateID, cancel tramos+UTC, P7) y Gateway (rutas Swagger, Basic, AuditAuthorization, body camelCase, emisión
  AddAuditRq con AuditType correcto, statics live lanza). Trasladado al flujo: `factory-implement` (Paso 4/5) y
  `factory_pull_validaciones.md` §11.

### 2026-06-10 — Config de deploy TEST + PRO
- Completada la config de deploy del conector (último punto de F6), replicando el patrón de Hotelbeds.
  **Puertos por bloque (salto de 3)**: TEST avail/reser/statics = 5022/5023/5024; PRO avail/reser = 5015/5016
  (statics no se despliega a PRO). El "+10" era de los listeners del ELB, no de estos workflows.
- TEST (ambos `deploy-all-apis-to-test*.yaml`): build+deploy jobs avoris avail/reser/statics + systemd units
  + scripts `configure-avoris-*` + `verify-deployment.needs` (+ case de puerto en v2). PRO (`pro-*`): avail+reser
  con compose `connector/avoris/{avail,reser}` + entradas en build/deploy-from-registry. YAML validado con js-yaml.
- **Pendiente del owner (no en repo):** crear secrets `CONFIG_TEST_AVORIS_*` y `PRO_CONFIG_AVORIS_*`.
- Trasladado al flujo factory para no olvidarlo en nuevos conectores: `factory-implement` (Paso 5) y
  `factory_pull_validaciones.md` §11 (sección 🚀 Deploy).

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
