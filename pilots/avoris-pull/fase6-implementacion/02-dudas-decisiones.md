# Fase 6 — Dudas, bloqueos y decisiones (trabajo autónomo)

_Formato por entrada: **Contexto · Duda/Bloqueo · Opciones evaluadas · Decisión**. Objetivo: máxima completitud sin interacción._

---

## D1 · Estrategia de mock del provider

**Contexto.** El prompt exige que en dev las llamadas al provider NO sean reales y devuelvan los mocks de factory. El patrón de Hotelbeds stubea endpoints inline en `Program.cs` (no-Producción) y apunta `EndpointUrl` al stub local.

**Duda.** ¿Replicar el stub self-HTTP de Hotelbeds, o inyectar un `IGateway` mock?

**Opciones.**
- (A) Stub self-HTTP en cada `Program.cs` (fiel a Hotelbeds) — pero frágil para book/cancel y mezcla mock en el host.
- (B) `MockGateway : IGateway` que devuelve el JSON de los mocks de factory deserializado, inyectado por DI según config `Provider:UseMock`. Las operaciones usan el constructor `IGateway` (que ya existe como seam de test en Hotelbeds).

**Decisión: (B).** Más fiable para "completar todas las operaciones contra los mocks", testeable, y deja intacto el `Gateway` real para la validación PRO (basta `Provider:UseMock=false` + creds reales en `providerParameters`). Los mocks de factory se copian a `Avoris/Operations/MockData/` (CopyToOutputDirectory).

## D2 · Puertos de las 3 APIs

**Contexto.** Hotelbeds usa 8040-8045. Hay que evitar colisión.
**Decisión.** Avoris: **AvailabilityApi 8050/8051, ReservationApi 8052/8053, StaticsApi 8054/8055**.

## D3 · Mocks de statics (mealplans/roomtypes/roomamenities/hotels)

**Contexto.** El proceso factory **no capturó** los endpoints de catálogo Portfolio de Avoris (`/mealPlans`, `/roomTypes`, `/roomAmenities`) — es justo el gap documentado en sorpresa #20 / `id_amenities`. Solo hay `statics-hotelInformation-*.json` (hotel-level) y los meal/room ids embebidos en avail.

**Duda.** ¿De dónde saco los mocks de statics si no se capturaron?

**Opciones.**
- (A) Bloquear statics — incumple "levantar las 3 APIs".
- (B) Sintetizar mocks de statics **representativos** a partir de lo observado en avail (meal SA/MP/AD; roomTypes H|E, D|2C…; el hotel de `statics-hotelInformation`), marcándolos claramente como sintéticos.

**Decisión: (B).** Permite levantar y ejercitar la StaticsApi contra mocks; se documenta que son sintéticos por el gap de captura (no bloqueante para validar las APIs). Para la validación PRO de la StaticsApi se usará el endpoint real.

## D4 · Diseño de tokens del conector (P7: solo cablear)

**Contexto.** El conector crea tokens opacos (`ConnectorSearchToken/PrebookToken/BookToken`) vía `ITokenHandler`. Avoris ya da tokens opacos (`token`, `bookToken`).

**Decisión.** Cada token del conector envuelve el token de Avoris + lo mínimo:
- `AvorisSearchToken { Token, HotelCode, RoomId, RateId, BookToken }` (de avail RS).
- `AvorisPrebookToken { BookToken }` (de prebook RS).
- `AvorisBookToken { BookingReferenceId }` (de book RS, para cancel/getbooking).
Sin traducción de catálogo (P7): los ids de hotel/room/meal se cablean tal cual a los campos canónicos.
