# Wrappers Core PerlaHub · Manifiesto vivo

> Wrappers viven en `REPOS/perlahub/Core/Accommodation/Wrappers/`. Aquí el catálogo del factory.

## Existentes (a construir con primeras conexiones)

| Wrapper | Propósito | Usado en | Status |
|---|---|---|---|
| `RateKeyBuffer.cs` | Buffer 2min antes de book si TTL < 10min | — | pendiente |
| `TimezoneResolver.cs` | Convierte el offset fijo del provider → UTC (PerlaHub guarda UTC; sin IANA per-hotel) | Dome, TGX | pendiente catalogar |
| `CoreCancelNotFound.cs` | Normaliza 404 cancel | — | pendiente |
| `BackoffExpStrategy.cs` | 1-2-4-8s con retries configurables | — | pendiente |
| `CurrencyForcer.cs` | Fuerza currency request si provider es multi-currency | — | pendiente |
| `PriceChangedTolerance.cs` | Tolera <5% diff prebook→book | — | pendiente |

## Nuevos (crecimiento)

_(vacío — cada `factory-close` añade si el provider requirió wrapper nuevo)_
