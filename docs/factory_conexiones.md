---
title: Factory de Conexiones - Estrategia industrialización (v2)
date: 2026-05-12
source: Santiago + reunión Santi+Pedro 11-may + auditoría código PerlaHub/PerlaPush
author: Santiago Patino Serna
tags: [factory, conexiones, espejo, pull-rebuyers, channels, pushin, pushout, skill, claude-code, perlahub, perlapush, purchasecontract]
status: definicion-v2-anclada-codigo
history: v1 5-may (visión); v2 12-may (anclada a conectores reales y reunión Pedro)
---

# Factory de Conexiones — v2

## TL;DR

Pasar de "conectar como podemos" a **máquina industrial** con 3 Factorys (Espejo / Pull / Push) + Pushout en espera. Skill+Claude Code generan informes pre-conexión; humano valida en gates HITL. Lo que **ya está en código** marca el punto de partida real, no el ideal.

Este documento es el **padre/visión global**. Los kits operativos viven en carpetas dedicadas:
- [`factory_pull/`](./factory_pull/) — proceso 11 pasos + 4 HITL, caja herramientas HB/Expedia/Avoris/TGX, piloto Avoris
- [`factory_push/`](./factory_push/) — proceso 12 pasos + 5 HITL (extra: clasificar Modo A/B), 7 capas validación entrante, pilotos SiteMinder + Avoris

---

## Lo que YA existe (punto de partida verificado en código)

### PerlaHub Connectors (lado Pull / providers de hotel)

**Repo**: `Operations/Projects_githubs/Mapping/perlahub/` (.NET, `PerlaHub.sln`)

**Conectores implementados hoy**:
- `Connectors/Accommodation/Dome/`
- `Connectors/Accommodation/Travelgate/`

Los demás providers conocidos en PROD (HB, Avoris, Roibos, Jumbo, Expedia, ID 1-9 del enum integration systems) **no son conectores propios todavía** — pasan por TGX como agregador o están en pipeline sin código (Avoris kickoff 13-abr, HB en certificación, Expedia en proceso).

**Interfaz canónica** (`Connectors/Core/Accommodation/Domain/`) — interfaces segregadas por operación:
- `IConnectorSearch`
- `IConnectorPrebook`
- `IConnectorBook`
- `IConnectorCancel`
- `IConnectorGetBookings`
- `IConnector*Static` (Hotels, Rooms, Amenities, MealPlans, Languages, HotelChains)

**Modelo Core compartido** (`Core/Accommodation/Domain/Reservation/`):
- `CoreOptionPrice`, `CoreOptionRoom`, `CoreCancellationPolicy`, `CoreRoomOccupancy`, `CoreCurrency`

**Anatomía de un conector** (ej. Dome):
```
Connectors/Accommodation/Dome/
├── Connectors.Accommodation.Dome.sln
├── AvailabilityApi/        # API REST específica de búsquedas
├── ReservationApi/         # API REST de reservas/cancel
├── StaticsApi/             # datos estáticos
├── Operations/
│   ├── Common/             # Gateway HTTP + Constants (credenciales)
│   ├── Search/
│   ├── Prebook/
│   ├── Book/
│   ├── Cancel/
│   ├── GetBookings/
│   └── Static/
└── Test/
```

**Gaps técnicos observados**:
- No existe `IConnectorFactory` ni jerarquía consolidada (cada conector se registra en DI por separado)
- Credenciales en `Constants.cs` (sin KeyVault/config externa)
- Sin Polly / circuit breaker visible
- 11+ interfaces estáticas en lugar de un `IConnectorStatic<T>` genérico

> Estos gaps son **infraestructura transversal**, no Factory. Pero limitan el "industrializar" si no se resuelven en paralelo.

---

### PerlaPush — Contenedor canónico

**Frontend**: `REPOS/perla_contract_frontend/` (Vite + React + TypeScript, **14 páginas** reales en `src/pages/`: Dashboard, GeneralContracts(+Detail), PurchaseContracts(+Detail), Rates(+Detail), SalesContracts(+Detail), Availability, Reservations, Masters, Hotels, SystemArchitecture).

**Backend**: microservicios .NET, no en el filesystem local — corren en máquinas remotas vía `push.perlatours.com`.

**El "contenedor canónico" del que habló Pedro 11-may YA EXISTE**: es el modelo `PurchaseContract` definido en `src/types/contracts.ts` (mirror exacto de PerlaPush Contracts.Domain).

**Estructura del contenedor**:
```
GeneralContract  (marco legal, periodo, firma, rappel, cláusulas)
└── GeneralContractConnection  (cómo se conecta: PerlahubExtranet | OtrosProveedores)
└── PurchaseContract  (← el contenedor canónico operativo)
    ├── Rate[]                            (tarifas, RateMode: Neta|Pvp)
    ├── PurchaseContractAllotment[]       (disponibilidad: open/close/release)
    ├── PurchaseContractMinimumStay[]
    ├── PurchaseContractStopSale[]
    ├── PurchaseContractSupplement[]      (con AppliesToLevel + AmountType)
    ├── PurchaseContractDiscount[]
    ├── PurchaseContractObservation[]     (multi-idioma)
    ├── PurchaseContractDistributionConfig
    ├── PurchaseContractDocument[]
    ├── PurchaseContractAgeRange
    └── SalesContract[]                   (márgenes por cliente/canal)
```

**Modo A vs Modo B YA está modelado en código** — enum `ConnectionType` (línea 98-101 de `contracts.ts`):
- `PerlahubExtranet = 1` → el partner usa nuestra UI/API genérica (**Modo A**: damos doc, ellos se adaptan)
- `OtrosProveedores = 2` → conector específico nuestro (**Modo B**: adaptamos su API)

**Conectores Channels conocidos**:
- **Dingus** (Modo B, webhook XML)
- **SiteMinder** (Modo B, SOAP/OTA) — pendiente análisis API
- **Push In Genérico JSON** (Modo A, PDES-98 cerrado)

---

## Las tres Factorys (refinadas con realidad)

### Factory Espejo

**Qué hace**: cliente ya en TravelGate se conecta directamente a nosotros cambiando solo el endpoint (no cambia su lógica).

**Estado**: 0 en PROD. Welcomebeds entregó logs 28-abr (escenario B), Destinia evaluando.

**Particularidad**: no hay nuevo conector que escribir — usa el lado TGX-supplier de PerlaHub (validación estricta auth, sin fallback). El trabajo es **validación + simulación HTTP**.

**Skill v0** — primer entregable pre-go-live:
- Validar auth en supplier-side
- Validar formato request/response vs el del cliente en TGX
- Simulador HTTP comparativo TGX↔PerlaHub
- Dismaches → lista de issues a resolver antes de tráfico real

**Riesgo**: zero clientes en PROD → cada uno de los 2 primeros (esta semana) genera más aprendizaje que el resto del año. Documentar en caliente.

---

### Factory Pull

**Kit operativo**: [`factory_pull/`](./factory_pull/) (briefing + validaciones + skill ejecutable Claude Code, todos del 11-may).

**Qué hace**: estandariza la integración de un rebuyer nuevo como conector PerlaHub.

**Estado real**:
- Conectores en código: 2 (Dome, TGX)
- En pipeline sin código: Avoris (kickoff 13-abr), HB (certificación caso #54977952)
- Expedia: handoff a Eva 28-abr (operativa); técnicamente en proceso

**Skill v0 — primer entregable** (sugerido Santi, validar):
**Informe estructurado del rebuyer ANTES de tocar código**:

| Bloque | Qué contiene |
|---|---|
| Endpoints | Inventario operación a operación vs canónica (Search, Prebook, Book, Cancel, GetBookings, Statics) |
| Match interfaces | Para cada `IConnector*`: ¿el rebuyer lo soporta?, ¿con qué llamada?, ¿qué falta? |
| Identificación de hoteles | Cómo identifica (códigos propios, GIATA, etc.) |
| Política cancelación | Modelo cancelación + match con `CoreCancellationPolicy` |
| Modelo precios | Ocupancia, currency, breakdown vs `CoreOptionPrice` |
| Estados sesión | Stateful (open/close session) vs stateless |
| Comparativa | vs Dome + vs TGX (los 2 ya implementados) |
| Trampas declaradas | Lo que dicen sus docs |
| Trampas esperadas | Lo que sabemos por HB, TGX, Dome de patrones similares |

> Un solo documento, técnico, sin diluir, sin esconder problemas.

**Pasos concretos para añadir conector** (siguiendo patrón Dome):
1. Crear `Connectors/Accommodation/{Provider}/` con sub-proyectos AvailabilityApi/ + ReservationApi/ + StaticsApi/ + Operations/
2. Operations/Common/Gateway.cs (cliente HTTP) + Constants (credenciales — **mover a config externa, gap actual**)
3. Operations/{Search,Prebook,Book,Cancel,GetBookings,Static} cada una implementa la interfaz `IConnector*`
4. Mappers DTO provider → Core (CoreOptionPrice, CoreOptionRoom, CoreCancellationPolicy, CoreRoomOccupancy)
5. `ConnectorExtensions.cs` con métodos `Add{Provider}Search()`, etc. para DI
6. Registrar en `Core/Accommodation/Application/ApplicationExtensions.cs`
7. Test/ con casos canónicos

**Caso piloto**: **Avoris (Polaris)** (kickoff 13-abr, sin código aún, Vanesa contacto). Hotelbeds = referencia mental (cert en curso, caso #54977952). Expedia = bundle deploy en curso.

**Proceso**: 11 pasos + 4 HITL gates → ver [`factory_pull/factory_pull_briefing_v0.md`](./factory_pull/factory_pull_briefing_v0.md).

**6 capas de validación saliente** → ver [`factory_pull/factory_pull_validaciones.md`](./factory_pull/factory_pull_validaciones.md). Misma carpeta contiene caja de herramientas histórica (HB/Expedia/Avoris/TGX/WHL/TravelCode) y **decisiones aprendidas P1-P6** que no se vuelven a discutir:
- P1: estáticos siempre del Inventory local, no passthrough
- P2: PVP ya incluye comisión hotel (neto = pvp × (1−%comisión))
- P3: re-mapping preserva PH↔nombre como oro
- P4: NUNCA inventar RoomTypes/RoomAmenities
- P5: cancellation timezone — deadlines en UTC; el conector convierte el offset fijo del provider a UTC (sin IANA per-hotel)
- P6: NO escribir PerlaHub PROD sin validación previa

**Métrica específica Pull**: booking error rate < 4%.

**Plan inmediato**: Pedro+Santi construyen Skill v0 conceptual; correcciones a Avoris → mejoras Skill v1.

---

### Factory Push

**Kit operativo**: [`factory_push/`](./factory_push/) (briefing + validaciones + skill ejecutable Claude Code, todos del 11-may).

**Qué hace**: estandariza cómo un Channel Manager nuevo empuja disponibilidad/precio al `PurchaseContract` canónico. **No** incluye dar de alta hoteles dentro de un CM existente (eso es otro proceso).

**Estado**:
- Dingus en PROD (Modo B, webhook XML)
- Push In Genérico JSON cerrado (Modo A, PDES-98)
- SiteMinder en análisis
- Pipeline 4-5 channels

**Hallazgos reunión Santi+Pedro 11-may**:

1. **El contenedor canónico ya existe** (`PurchaseContract`). El channel rellena ese contenedor, no creamos uno nuevo por channel.

2. **Eva define en el frontend** qué admite el contenedor (release, precio, estancia mínima, tarifa, etc.). Esto es la "API que ofrecemos al channel".

3. **Modo A vs Modo B** (ya modelado en enum `ConnectionType`):
   - **Modo A** (`PerlahubExtranet`): damos doc, ellos se adaptan a nuestra API JSON. Nosotros validamos que lo hacen bien.
   - **Modo B** (`OtrosProveedores`): nosotros adaptamos su API (parser/translator → contenedor).

4. **Después de 5 conexiones la elección Modo A/B es irrelevante**: la estructura ya soportará todo. Solo cuando el patrón se desvía hay trabajo nuevo.

5. **Si un channel pide algo NO contemplado** (ej: release por duración de estancia en lugar de por día) → reunión específica (Eva + Pedro + Santi) para decidir si vale la pena extender el contenedor por ese proveedor. **Default: no extender.**

**Skill v0** — primer entregable (mismo principio que Pull, decide el equipo):

| Bloque | Qué contiene |
|---|---|
| Endpoints del channel | Webhook (Dingus-like), SOAP/OTA (SiteMinder), REST, polling |
| Match vs `PurchaseContract` | Para cada campo canónico (rate / allotment / release / minimumStay / stopSale / supplement / discount): ¿el channel lo manda?, ¿cómo lo nombra?, ¿en qué payload? |
| Mismatches | Lista explícita de campos que el channel pide y el contenedor NO tiene (input para decisión Eva/Pedro/Santi) |
| Mapeo de hoteles | **PUNTO ABIERTO** (ver más abajo) |
| Frecuencia y SLA | Cuánto pushea, qué respuesta espera, qué queda en cola |
| Trampas | Declaradas + esperadas |

**PUNTO ABIERTO documentado en reunión 11-may** — *quién crea el hotel primero*:
- Caso H-Top: Perla creó hotel → envió código a Dingus → ellos mapearon. **OK.**
- Caso "rebelde": llegó disponibilidad por Dingus sin que Perla hubiera creado hotel previamente. Pedro confundido — Santi explica que es plausible que el CM tenga "conectarme con Perlatours" en su frontend y el hotel haya iniciado por su lado.
- **Acción**: Pedro investiga con el hotel/Dingus cómo entró ese hotel concreto.
- **Implicación para la Factory**: necesitamos un frontend de notificación tipo *"este channel quiere conectarse contigo: aquí tienes los datos brutos, decide si lo mapeas o aceptas"*. Hoy ese hotel "quedó fichado en los brutos".

**Casos piloto** (acordado 11-may): **SiteMinder** (primer caso real, modo a definir en Fase 0) y **Avoris** (kickoff 13-abr ya activo). **Dingus** = referencia mental / caso 0 catálogo.

**Proceso**: 12 pasos + 5 HITL gates (HITL #1 extra vs Pull = clasificar Modo A/B al inicio) → ver [`factory_push/factory_push_briefing_v0.md`](./factory_push/factory_push_briefing_v0.md).

**7 capas de validación entrante** + 20 errores estándar + 10 endpoints + `IAvailabilityManagementGateway` + decisiones D1-D6 → ver [`factory_push/factory_push_validaciones.md`](./factory_push/factory_push_validaciones.md). Incluye **Mock Tests inversos** (nosotros somos el endpoint, no consumidor) y 10 casos estándar (burst, dedup, hotel no registrado, forward-compat).

**Métricas específicas Push**: score compatibilidad + complejidad adapter (pre) | **% rejects por shape < 2%** durante 7 días (post).

**Pendientes v1** (anotados en project_factory_push_v0):
1. Definir N días Definition of Done
2. Calibrar 2% threshold rejects
3. Anexo A (plantilla informe Fase 1)
4. Anexo D con Dingus como caso 0
5. Calculadora Anexo E (unidades Dingus)
6. Mecanismo concreto alarma Capa 3 ("quién empieza primero")

---

### Factory Pushout (sin funnel formal, en espera)

- Top Dog UK propuesta enviada (Push Out directo, Graeme contacto)
- Conexiones directas se incluyen en Factory Espejo (soporte/preparación)
- Sin código formal hasta que haya 2-3 candidatos

---

## Decisión: cuándo extender el contenedor canónico

> **Regla**: si llega un campo nuevo (ej. release por duración de estancia), no se añade por un solo proveedor. Reunión Eva+Pedro+Santi decide si vale la pena.

- 1 proveedor lo pide, 10 no → **NO** se extiende.
- 3+ proveedores lo piden → entra al backlog del contenedor.
- El contenedor `PurchaseContract` ya tiene rates, allotments, releases, supplements, discounts, stopSales, minimumStays, observations multi-idioma, ageRange, salesContracts. Cobertura amplia.

---

## Cómo medimos (3 métricas, validar con equipo)

1. **Horas de codificación efectiva** por conexión nueva
2. **Tiempo de calendario** desde "vamos a conectarlo" hasta "tráfico estable"
3. **Sorpresas en producción** — cada una es input para mejorar Skill o proceso

> Si tras N conexiones de cada tipo no bajan horas ni calendario, la Factory no funciona y revisamos.

---

## Lo que NO es la Factory hoy

- **No** resuelve infra transversal (rate limits, caches, observabilidad, `IConnectorFactory`, KeyVault) — eso es paralelo
- **No** decide a qué provider/channel conectar — eso es comercial
- **No** sustituye la reunión humana cuando un channel pide algo fuera del contenedor

---

## Plan inmediato (desde reunión 11-may)

- [x] Documento Factory v2 (este archivo) — capturado realidad código + decisiones reunión
- [ ] Pedro+Santi: análisis API SiteMinder + Avoris (campos vs `PurchaseContract`) — hoy
- [ ] Reunión 17:00-17:15 (12-may) con Pedro validar análisis
- [ ] Skill v0 Factory Pull — Avoris piloto (kit en `factory_pull/`)
- [ ] Skill v0 Factory Push — SiteMinder piloto (kit en `factory_push/`)
- [ ] Resolver punto abierto Dingus "rebelde" (quién crea el hotel primero)
- [ ] Frontend de notificación "channel quiere conectarse contigo"
- [ ] Baseline métricas con HB + Expedia + Dingus retroactivo

---

## Pipeline conocido

- **Channels**: Dingus en PROD + 4-5 en pipeline (SiteMinder en análisis)
- **Rebuyers**: Avoris kickoff, HB certificación, Expedia en curso (no todos del tamaño de Expedia)
- **Espejo**: Welcomebeds + Destinia + Avoris + 1 TBD (los 4 clientes)

---

## Cross-ref brain

| Pieza | Memoria asociada |
|---|---|
| Espejo TGX (4 clientes) | project_espejo_tgx_4clientes, project_welcomebeds_espejo_tgx, project_mirror_perlahub_validation, project_destinia_espejo_tgx |
| Avoris Nativa | project_avoris_nativa |
| Hotelbeds cert directa | project_hotelbeds_certificacion |
| Expedia handoff Eva | project_expedia_handoff_eva, project_expedia_prod_branch_20abr, project_expedia_eps_id_mismatch |
| Push In Genérico (Modo A) | project_pushin_generico (PDES-98) |
| Dingus en PROD | project_perlapush_local_e2e_16abr, project_eva_tarifas_dingus_hotel3 |
| Push Out PerlaPush | project_pushout_status (PDES-2) |
| TopDog UK Push Out | project_topdog |
| Frontend Contratos v2 | project_perla_contract_frontend_v2, project_contracts_dashboard_dev_deploy |
| Contratos UCs Eva | project_contratos_eva_clarifications_4may, project_contratos_plan_v2 |
| Masters API gateway | reference_perlapush_masters_api, reference_perlapush_masters_api_gotchas |
| In-Travel (verticales destino del conocimiento) | project_intravel_services, project_daytrips_audit |

---

## Histórico de versiones

- **v1 (5-may)**: visión estratégica inicial (Santiago a Francesc+Pedro). Sin anclar a código.
- **v0 push + v0 pull (11-may)**: kits operativos detallados producidos en call Santi+Francesc y reunión Santi+Pedro. Carpetas `factory_push/` y `factory_pull/` con briefing + validaciones + skill ejecutable Claude Code cada una.
- **v2 (12-may)**: este documento. Sintetiza v1 + v0_push + v0_pull. Anclado a realidad de conectores (PerlaHub: Dome+TGX en código; PerlaPush: `PurchaseContract` + enum `ConnectionType` Modo A/B ya modelado). Punto abierto del hotel "rebelde" Dingus documentado. Pilotos: Avoris (Pull) + SiteMinder (Push). Apunta a las carpetas operativas como fuente de verdad.
