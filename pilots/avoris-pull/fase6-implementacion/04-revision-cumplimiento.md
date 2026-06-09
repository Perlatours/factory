# Fase 6 — Revisión de cumplimiento (revisor independiente)

_Revisión 2026-06-09 · revisor: Claude (no autor de la implementación) · sin modificar código._
_Fuentes: `00-PROMPT-original.md` (criterios), `02-dudas-decisiones.md`, `03-resultado-ejecucion.md`, código en `C:\Workspace\Perlatours\PerlaHub\Connectors\Accommodation\Avoris` (rama `feature/AvorisConnector`, commit `9c55f1c`), evidencia factory en `pilots/avoris-pull/evidence/`._

## Tabla resumen

| # | Criterio | Veredicto | Evidencia |
|---|----------|-----------|-----------|
| 1 | Ubicación en `PerlaHub/Connectors/Accommodation/Avoris` | **CUMPLE** | Directorio existe con `.sln`, Dto/, Operations/, 3 APIs |
| 2 | Rama dedicada en repo PerlaHub | **CUMPLE** | `git branch --show-current` → `feature/AvorisConnector`; `git log -1` → `9c55f1c feat(avoris): conector ... 3 APIs sobre mocks` |
| 3 | 3 APIs separadas (1 Search/Prebook · 2 Book/Cancel/GetBooking · 3 Statics), estilo Hotelbeds/Expedia | **CUMPLE** | `AvailabilityApi/Program.cs` (Search+Prebook), `ReservationApi/Program.cs` (Book+Cancel+GetBookings), `StaticsApi/Program.cs` (7 statics). Misma estructura que Hotelbeds/Expedia |
| 4 | Provider mockeado en dev con mocks de factory | **CUMPLE** | `MockGateway.cs` sirve `MockData/*.json`; DI condicional `Provider:UseMock` en `ConnectorExtensions.cs:25-33`; `appsettings.Development.json` → `UseMock:true`. Mocks derivan de evidence (ver hallazgo H1) |
| 5 | 3 APIs levantadas + todas las operaciones contra mocks | **CUMPLE (con matiz)** | Las 3 APIs están vivas (puertos 8050/8052/8054 LISTENING; DLLs bloqueadas por los hosts). Verificación E2E HTTP-200 se apoya en el doc del autor; no la re-ejecuté caso a caso (ver H2) |
| 6 | Validación PRO (API 1 y 3 contra real) si hay credenciales | **CUMPLE (condicional no aplicable)** | Sin credenciales reales: solo `03-credentials.local.env.example` con USER/TOKEN vacíos. Bloqueo correctamente declarado, NO inventado |
| 7 | Fuera de alcance: levantar todo PerlaHub | **CUMPLE** | Solo se arrancan las 3 APIs del conector; nada del resto del sistema |
| 8 | Autonomía + documentar dudas/decisiones | **CUMPLE** | `02-dudas-decisiones.md` (D1–D4 con formato Contexto·Duda·Opciones·Decisión) + `03-resultado-ejecucion.md` |
| 9 | Lanzar revisión al cerrar | **CUMPLE** | Este documento |
| P7 | Conector solo cablea, no traduce catálogo | **CUMPLE** | `Search.cs:108-114,142-143` y `Static.cs:78` cablean hotelCode→HotelId, meal.id→MealPlanId, rooms[].id→RoomTypeId, configuration→Occupancy. Sin traducción de catálogo |
| R#16 | travellers[].index = índice de habitación (Book) | **CUMPLE** | `Book.cs:25-37`: `Index = roomIdx + 1`, todos los pax de la habitación comparten índice |
| R#10 | bookToken literal (precio congelado) | **CUMPLE** | `Book.cs:41` `BookToken = token.BookToken` reenvío literal; `Prebook.cs:23` reenvía bookToken del rate |
| R | Penalidad in-stay desde cancellationPolicies (no inyectada) | **CUMPLE** | `AvMap.cs:21-40` / `Search.cs:152-172`: penalidades solo desde `rate.CancellationPolicies`; nada inyectado |
| R | NRF→refundable por rateID | **CUMPLE** | `AvMap.cs:23` / `Search.cs:155`: `refundable = !rateID.Contains("NOREEMBOLSABLE")`, sin alimentación cruzada |
| B | Compila (0 errores) | **CUMPLE (con matiz)** | `Operations` (núcleo del conector) compila **0 err / 0 warn** en limpio. La `.sln` completa da 78 errores **solo de bloqueo de fichero** (MSB3021/3027 "being used by another process / .NET Host") porque los 3 hosts están corriendo — NO son errores de compilación (ver H3) |

## Veredicto global

**CUMPLE.** La implementación satisface todos los criterios del prompt. El objetivo mínimo (3 APIs separadas levantando y operando contra los mocks de factory) está cumplido y verificable; los principios de diseño (P7) y las reglas del informe (#16, #10, in-stay, NRF) están correctamente implementados en el código, no solo declarados. La validación PRO está honestamente marcada como bloqueada por ausencia de credenciales reales (no fabricada). Las desviaciones son menores y están documentadas por el autor.

## Hallazgos / riesgos

- **H1 (procedencia de mocks — CONFIRMADA, no idéntica 1:1).** Los mocks NO son copias byte-a-byte de un único fichero de evidence, sino una **curación derivada** para el flujo book coherente:
  - `MockData/prebook.json` es **IDÉNTICO** a `evidence/sandbox-pro-20260609-e2e/2-prebook-rs.json`.
  - `providerRef 802885266` (book/bookingdetail/cancel) procede de `evidence/sandbox-pro-20260609-e2e/3c-book-rs-CONFIRMED.json` y siguientes.
  - `avail.json` usa hotel 66646 (presente en mocktests y e2e) pero con check-in/out 2026-09-15/17 y token `perla-book-flow` (ajustado para encadenar el flujo). Es legítimo y trazable a evidence, aunque no es un volcado literal — conviene saberlo.

- **H2 (verificación E2E HTTP-200 no re-ejecutada caso a caso).** Confirmé de forma independiente que las 3 APIs están **vivas** (puertos 8050/8052/8054 escuchando; DLLs bloqueadas por sus hosts). Los endpoints exigen un esquema de request concreto (mis sondas ad-hoc a `/getmealplans` y `/gethotels` dieron HTTP 400 por body incompleto; `/getroomtypes` respondió). La tabla de HTTP-200 con valores concretos del `03-resultado-ejecucion.md` no la re-ejecuté caso por caso, así que ese detalle se apoya en el doc del autor. Riesgo bajo (código y mocks lo respaldan), pero no es verificación 100% independiente del runtime.

- **H3 (build de la .sln falla por locks, NO por compilación).** `dotnet build` de la solución completa devuelve 78 errores, **todos** MSB3021/MSB3027 de copia de DLL bloqueada por ".NET Host (PID…)": son las 3 APIs en ejecución reteniendo sus binarios. Al compilar el proyecto `Operations` aislado (no host-lockeado): **0 errores, 0 advertencias**. Para reproducir el "0 errores" del doc hay que detener los 3 procesos host antes de buildear la .sln. No es un defecto del código.

- **H4 (statics sintéticos).** `hotels.json` (cabecera `_comment: SINTÉTICO`), `mealplans.json`, `roomtypes.json` y los catálogos chains/categories/languages NO provienen de captura real de Avoris (gap #20: factory no capturó endpoints Portfolio). Están **claramente marcados como sintéticos** y la decisión está documentada (D3). Coherente con el prompt, pero la StaticsApi en mock NO refleja datos reales del provider; la validación real queda pendiente de PRO. `gethotelchains` y `getroomamenities` devuelven 0 a propósito (`Static.cs:93-100`, gap #20).

- **H5 (`_t/` sin trackear).** El directorio `Avoris/_t/` (cuerpos de prueba sueltos) aparece como `?? untracked` en git status; no está en el commit. Ruido inocuo, conviene `.gitignore` o limpiarlo.

- **H6 (Gateway real best-effort).** El `Gateway` live usa rutas inventadas (`/availability`, `/prebook`, `/portfolio/*`) y header `Api-Key` a falta del Swagger de Avoris (`Gateway.cs:43-65`). Documentado. La validación PRO real **no podrá darse por buena solo arrancando**: requiere confirmar rutas/auth con el Swagger del provider. Riesgo real para la futura fase PRO, ya señalado por el autor.

- **H7 (sin proyecto Test).** Hotelbeds y Expedia incluyen `Test/`; Avoris no. Declarado como pendiente (limitación #3). No es criterio del prompt, pero es deuda frente al patrón de referencia.
