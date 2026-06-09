# Decisiones Pull P1-P6 (aprendidas, no se vuelven a discutir)

> Sincronizado desde `docs/factory_pull/factory_pull_validaciones.md`. Edición autoritativa allí; aquí copia operativa.

- **P1** — Estáticos siempre del Inventory local de PerlaHub, NUNCA passthrough del provider.
- **P2** — PVP ya incluye comisión hotel. `neto = pvp × (1 − %comisión)`. NO se aplica markup encima del PVP.
- **P3** — Re-mapping preserva matches PerlaHub↔nombre como oro; solo se cambia `target_id`.
- **P4** — NUNCA inventar RoomTypes ni RoomAmenities. Usar exclusivamente catálogo real PerlaHub.
- **P5** — Cancellation timezone: deadlines en **UTC**; el conector convierte el offset fijo del provider (p.ej. GMT+1) a UTC. PerlaHub NO resuelve timezone por hotel (sin IANA). [Verificado en código PerlaHub 2026-05-26: `Deadline //UTC` + `DateTimeKind.Utc`; cero `TimeZoneInfo`/IANA en el repo.]
- **P6** — NO escribir en PerlaHub PROD sin validación previa (lista → validación → ejecución).
- **P7** — El conector **NUNCA mapea identificadores de catálogo** (hotel/room/meal/amenity). El flujo solo **CABLEA**: copia el id del proveedor al campo canónico tal cual (`hotelCode→HotelId`, `rooms[].id→RoomTypeId`, `meal.id→MealPlanId`). El mapeo `id_provider→id_PH` es tarea **EXTERNA** del servicio de Mapping de PerlaHub, alimentado por el Inventory local + los estáticos consultables del proveedor (`IGetHotels/RoomTypes/MealPlans/RoomAmenities`). Extiende P1 y P4. [avoris-pull 2026-06-09]

## Decisiones P7+ (espacio para crecer)

_(vacío — se llena con cada `factory-close` Pull)_
