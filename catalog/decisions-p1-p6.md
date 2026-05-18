# Decisiones Pull P1-P6 (aprendidas, no se vuelven a discutir)

> Sincronizado desde `docs/factory_pull/factory_pull_validaciones.md`. Edición autoritativa allí; aquí copia operativa.

- **P1** — Estáticos siempre del Inventory local de PerlaHub, NUNCA passthrough del provider.
- **P2** — PVP ya incluye comisión hotel. `neto = pvp × (1 − %comisión)`. NO se aplica markup encima del PVP.
- **P3** — Re-mapping preserva matches PerlaHub↔nombre como oro; solo se cambia `target_id`.
- **P4** — NUNCA inventar RoomTypes ni RoomAmenities. Usar exclusivamente catálogo real PerlaHub.
- **P5** — Cancellation timezone: UTC + `Hotel.TimeZoneId` IANA.
- **P6** — NO escribir en PerlaHub PROD sin validación previa (lista → validación → ejecución).

## Decisiones P7+ (espacio para crecer)

_(vacío — se llena con cada `factory-close` Pull)_
