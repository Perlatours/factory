# Fase 6 — Resultado de ejecución (conector Avoris)

_Generado al terminar el trabajo autónomo 2026-06-09. Repo: PerlaHub, rama `feature/AvorisConnector`, dir `Connectors/Accommodation/Avoris`._

## Objetivo mínimo: ✅ CUMPLIDO

Las **3 APIs separadas** levantan y **completan todas las operaciones contra los mocks** de factory.

### Estructura creada (igual que el resto de conectores)
```
Avoris/
  Connectors.Accommodation.Avoris.sln
  Dto/          (modelos provider Avoris)
  Operations/   (Search·Prebook·Book·Cancel·GetBookings·Static + Common[Gateway,MockGateway,tokens,DI])
                + MockData/ (mocks de factory copiados + statics sintéticos)
  AvailabilityApi/ (API 1 · Search+Prebook · puertos 8050/8051)
  ReservationApi/  (API 2 · Book+Cancel+GetBookings · puertos 8052/8053)
  StaticsApi/      (API 3 · 7 catálogos · puertos 8054/8055)
```

### Build
`dotnet build Connectors.Accommodation.Avoris.sln` → **0 errores**. Baseline Hotelbeds también compila (toolchain OK).

### Operaciones verificadas contra mocks (todas HTTP 200)
| API | Endpoint | Resultado |
|---|---|---|
| 1 | `POST /search` | 16 opciones · opt0: hotelId 66646, mealPlanId SA, roomTypeId H\|E, rateCodes [NOREEMBOLSABLE], occ [30,30], 195.25 EUR, refundable=false (NRF), 1 penalty, token 220c |
| 1 | `POST /prebook` | success · net 234.98 EUR · refundable=true (PUBLICA) · prebookToken 200c |
| 2 | `POST /book` | success · providerRef **802885266** · status BOOKED · bookToken 208c |
| 2 | `POST /cancel` | success · status CANCELLED |
| 2 | `POST /getbookings` | success · 1 booking · ref 802885266 · hotelId 66646 · checkIn/out · 1 room |
| 3 | `POST /getmealplans` | 5 (SA/AD/MP/PC/TI) |
| 3 | `POST /getroomtypes` | 6 |
| 3 | `POST /getroomamenities` | **0** (refleja gap #20: Avoris no expone room-amenities) |
| 3 | `POST /gethotels` | 2 hoteles, mapeados (id, nombre, lat/long, chain, categoría, país) |
| 3 | `POST /gethotelchains` | 0 (Avoris no expone catálogo de cadenas) |
| 3 | `POST /gethotelcategories` | 5 |
| 3 | `POST /getlanguages` | 2 |

### Principio P7 respetado
El conector **solo cablea**: `hotelCode→HotelId`, `meal.id→MealPlanId`, `rooms[].id→RoomTypeId`, `configuration→Occupancy.PaxAges`, `rateID→RateCodes`, tokens opacos envueltos con `ITokenHandler`. **Ninguna traducción de catálogo** (eso es del servicio de Mapping del Core). Reglas del informe aplicadas: #16 (travellers[].index = índice de habitación), #10 (bookToken literal con precio congelado), penalidad in-stay volcada desde `cancellationPolicies` (no inyectada), NRF→refundable por rateID sin alimentación cruzada.

## Validación PRO (APIs 1 y 3 contra destino real): ⛔ BLOQUEADA (condicional no cumplida)
**No hay credenciales avoris-PRO** (solo `inputs/03-credentials.local.env.example` con valores vacíos; TST no funciona). El prompt lo condicionaba a "si se dispone de credenciales".
- **Path live verificado estructuralmente:** con `Provider:UseMock=false` el Gateway real forma y envía `POST {EndpointUrl}/availability` (visto en log antes de activar el mock). Solo falta `EndpointUrl`+`ApiKey` reales para golpear PRO.
- Para validar PRO cuando haya creds: arrancar API 1 y 3 con `Provider__UseMock=false` y `providerParameters` reales (EndpointUrl, ApiKey). **Pendiente:** rutas/auth exactas del provider requieren el Swagger de Avoris (no incorporado al repo — el `Gateway` real usa rutas best-effort `/availability`, `/prebook`, `/portfolio/*`).

## Cómo arrancar (mock)
Desde cada `*/bin/Debug/net8.0`:
```
ASPNETCORE_ENVIRONMENT=Development Provider__UseMock=true ASPNETCORE_URLS=http://localhost:8050 dotnet Connectors.Accommodation.Avoris.AvailabilityApi.dll
```
(8052 ReservationApi, 8054 StaticsApi). **Nota operativa:** ejecutar el DLL fuera de su carpeta bin deja el content root mal y no carga appsettings → usar el override `Provider__UseMock=true` (decisión registrada).

## Limitaciones / pendientes (no bloqueantes del objetivo mock)
1. **Swagger Avoris ausente** → Gateway real best-effort (rutas/auth a confirmar). Mealplans/roomtypes/roomamenities/hotels statics usan mocks **sintéticos** (factory no capturó los catálogos Portfolio — gap #20).
2. **PRO sin creds** → validación real pendiente.
3. **Tests unitarios**: no se creó proyecto Test (los conectores de referencia sí lo tienen). Pendiente para endurecer.
4. Pricing por-room: se asigna el precio de opción a cada room (Avoris no da per-room en search); no se hace split (1 room por caso probado).
