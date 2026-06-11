---
name: factory-implement
description: |
  Ejecuta la Fase 6 (codificación) de una conexión Pull con informe aprobado: implementa el
  conector en el repo PerlaHub sobre rama dedicada siguiendo el contrato canónico (P7
  cablear-no-traducir), el Definition of Done técnico (factory_pull_validaciones.md §11, INCLUYE
  audit Capa 8), MockGateway para dev y las 3 APIs (Search/Prebook · Book/Cancel/GetBookings ·
  Statics). Verifica TODAS las operaciones contra mocks y el registro de audit en local, y cierra
  con una auto-revisión de cumplimiento.
  Invocar SIEMPRE que se vaya a implementar/codificar un conector — "/factory-implement avoris",
  "implementa el conector X", "codifica la fase 6 de X", "empieza la implementación de X",
  "arranca la implementación de X". Si alguien pide implementar un conector AD-HOC (con un prompt
  manual), AVISA de que existe este comando estandarizado y redirige aquí con el contexto.
version: "1"
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
---

# Factory Implement — Fase 6 codificación (protocolo determinista)

Implementa el conector de una conexión Pull **cuyo informe (F5) está aprobado**. Trabaja en el
**repo PerlaHub** (`Connectors/Accommodation/<Conector>`), **no** en la planta factory.

## ⛔ Reglas de control (NO negociables)

1. **Comando estandarizado.** Esta es la vía oficial de F6. Si te piden "implementar el conector"
   con un prompt ad-hoc, **avisa de que existe `/factory-implement <slug>`** y úsalo (no improvises
   una estructura distinta). El prompt ad-hoc se guarda como contexto en `00-PROMPT-original.md`.
2. **El conector solo CABLEA (P7).** Nunca traduce identificadores de catálogo; copia el id del
   proveedor al campo canónico tal cual. El mapeo es tarea externa del Mapping de PerlaHub.
3. **Audit NO es opcional (Capa 8).** El `Gateway` del conector **debe emitir `AddAuditRq`**
   (pasar `auditRq`, **no `null`**, a `HttpRequestBuilder.SendAsync`), patrón
   `Hotelbeds/Operations/Common/Gateway.cs`. **Si no se cablea, falla en silencio** (la API levanta
   y responde 200 igual). Es un ítem del DoD que se **verifica en local**, no se asume.
4. **Nada toca PROD.** Provider mockeado en dev (MockGateway sirve los mocks de factory). La
   validación contra destino real es **condicional** (`--pro` + credenciales) y solo APIs 1 y 3.
5. **Dudas/bloqueos se documentan**, no se preguntan en mitad del flujo: `02-dudas-decisiones.md`
   (duda + opciones evaluadas + decisión). Si es bloqueante, elige la mejor opción y deja constancia.
6. **Cierre con auto-revisión.** Al terminar, revisa lo generado contra el DoD §11 + el prompt y
   escribe `04-revision-cumplimiento.md` con veredicto CUMPLE / NO CUMPLE por criterio.

## Sintaxis

```
/factory-implement <slug>            # implementa F6 contra mocks (dev), sin tocar PRO
/factory-implement <slug> --pro      # además valida APIs 1 y 3 contra destino real (requiere creds)
/factory-implement <slug> --resume   # retoma una F6 ya empezada (idempotente; relee bitácora)
```

## Paso 0 — Estado y precondiciones (STOP si falla)

```bash
docker exec -i factory-db psql -U factory -d factory -P pager=off <<SQL
SELECT id, slug, display_name, factory, current_phase, status FROM connections WHERE slug='$SLUG';
SQL
```
- `factory != 'pull'` → `STOP: "factory-implement solo opera conexiones Pull."`
- `current_phase < 5` → `STOP: "Informe no listo (fase <5). Completa /factory-pull <slug> hasta F5."`
- Informe F5 **no aprobado** por Pedro (HITL #1 de F5 sin sello) → `STOP: "Informe pendiente de revisión. /factory-review <slug>."`
- Sin rama dedicada en PerlaHub → créala (`feature/<Conector>Connector`) antes de codificar.

## Paso 1 — Leer insumos (obligatorio antes de codificar)

- `pilots/<slug>/outputs/informe.md` (veredicto, score, wrappers, P7).
- `pilots/<slug>/outputs/informe-ajustes-revision.md` — **§0 principio P7**, **§1 tabla de cableado**,
  **§5 acciones de implementación**.
- `docs/factory_pull/factory_pull_validaciones.md` — **§11 DoD (47 ítems)** + **§1 Capa 8 (audit)**.
- Mocks: `pilots/<slug>/evidence/**` (RQ + RS capturados; son la fuente del MockGateway).
- Conector de **referencia** más cercano en PerlaHub (Hotelbeds / Dome / Travelgate / Expedia).

## Paso 2 — Estructura del proyecto (igual que el resto de conectores)

```
<Conector>/
  Connectors.Accommodation.<Conector>.sln
  Dto/          (modelos provider: requests + responses)
  Operations/   (Search·Prebook·Book·Cancel·GetBookings + Common[Gateway,MockGateway,tokens,DI])
                + MockData/ (mocks de factory copiados)
  AvailabilityApi/ (API 1 · Search+Prebook)
  ReservationApi/  (API 2 · Book+Cancel+GetBookings)
  Test/            (al menos humo por operación)
```

> **🔴 Statics fuera del conector (P8).** Los estáticos/catálogos se gestionan por un **proceso de
> sincronización de contenidos independiente** del conector (flujo de reservas integrado en PerlaHub).
> El conector **NO implementa StaticsApi** ni operaciones `IGetHotels/RoomTypes/MealPlans/RoomAmenities`
> → solo **2 APIs** (Availability + Reservation). _Revisar al inicio: si por algún motivo este conector
> sí necesitara statics, es excepción a documentar, no el caso por defecto._ Conectores antiguos
> (Hotelbeds/Dome/…) conservan su StaticsApi por legado; los nuevos no la crean.

## Paso 3 — Implementación guiada por el DoD (cada ítem se cumple o se justifica)

Recorre el **DoD §11** capa a capa. Mínimos no-negociables:

- **Cableado (P7):** mappers RQ/RS copian id↔campo canónico (tabla §1 del informe-ajustes). Sin traducir.
- **Tokens opacos** vía `ITokenHandler` (envuelven el/los token(s) del provider + lo mínimo).
- **MockGateway (D1):** `IGateway` que sirve `MockData/*.json` cuando `Provider:UseMock=true`; `Gateway`
  real cuando `false`. DI en `ConnectorExtensions.AddConnectorsCore` (incluye `AddAuditGateway()`).
- **Gateway real:** rutas y auth del Swagger del provider; body en el casing que espere el provider.
- **🔴 Audit (Capa 8) — NO null:** el `Gateway` construye `AddAuditRq` (TraceId + AuditType por operación +
  AuditConfig + ProviderConnectionId) y lo pasa a `SendAsync(config, auditRq)`; añade header
  `AuditAuthorization` = `SystemUserToken`. Captura de `providerParameters`: `AuditConfigId`,
  `SystemUserToken`, `ProviderConnectionId`. **Patrón: `Hotelbeds/Operations/Common/Gateway.cs`.**
  Añade `AuditGatewayConfig:Url` al `appsettings.json` de **CADA API** (Availability y Reservation),
  no solo Availability — sin él el consumer hace `new Uri(null)` y el audit no se entrega.
- **Estados, cancel policy (UTC/P5), refundable flag general, locator siempre presente** — según informe.

## Paso 4 — Verificación (obligatoria; no vale "compila")

1. `dotnet build` de la solución → **0 errores** (si hay locks MSB3021/3027, para los procesos vivos).
2. **Las 2 APIs levantan** y **completan TODAS las operaciones contra mocks** (HTTP 200). Tabla op→resultado.
   - **Multi-room obligatorio** (el mock single-room no basta): el MockGateway debe servir un fixture
     con ≥2 rooms y precio por-room. Verificar el invariante **`option.Price == Σ rooms[].Price`** y que
     **cada room lleva su PROPIO precio** (no el total del rate), y la `cancelPolicy` con el total de opción
     y sus tramos (gratis omitido / penalización con deadline UTC). Regresión Avoris jun-2026:
     `MapRooms` asignaba `rate.pricing` (total) a cada room → opción ≠ Σ rooms y política "mal aplicada".
3. **Audit en local** (no solo compila):
   ```bash
   docker compose -f docker-compose.local.yml up -d postgres minio audit-api   # en el repo PerlaHub
   ```
   - Arranca API 1 live, añade a `providerParameters`: `AuditConfigId` + `SystemUserToken` (JWT Bearer).
   - `AuditConfigId=1` (OnlyMetadata → Postgres) primero; luego `AuditConfigId=0` (All → S3/MinIO + Postgres).
   - Confirma en el log del consumer `Successfully sent batch` y la fila en `bookingFlow.audit_*`.
4. **PRO (condicional, solo con `--pro` + creds):** API 1 (y API 2 si procede) con `Provider:UseMock=false`
   y `providerParameters` reales → llamadas correctas a destino real. Sin creds: documentar como bloqueado.
5. **Proyecto Test verde** (`dotnet test`): el conector **debe** tener `Test/` (molde del de referencia)
   con, como mínimo: invariante **multi-room `option == Σ rooms`**, refundable por rate, cancel (tramos/UTC),
   cableado P7, y `Gateway` (rutas reales + auth + **emisión de audit** con AuditType correcto). Sin tests,
   el job `run-tests` del deploy falla (exit 1).

## Paso 5 — Config de deploy TEST + PRO (réplica del patrón del resto · ref. Hotelbeds)

**No se considera F6 completa sin esto.** Se replica la huella del conector de referencia cambiando
solo nombre/puerto/paths. Como el conector es de **2 APIs** (avail+reser; statics fuera por **P8**),
reserva **un bloque de 2 puertos por proveedor** (TEST sigue la numeración secuencial systemd; PRO el
host→8080), coherente con el siguiente bloque libre tras el último proveedor. _(El "+10" es de los
listeners del ELB, no de estos workflows.)_

- **TEST — los dos `deploy-all-apis-to-test*.yaml`:** build + deploy jobs para availability y reservation
  (copia de los del conector de referencia; en v2 con `if: inputs.api == '<conn>-<api>-api'`, en v1 sin `if`),
  `deployment/systemd-services/<conn>-<api>-api.service` (puerto), `deployment/scripts/configure-<conn>-<api>-production.sh`,
  ampliar `verify-deployment.needs` y (v2) los `case` de puerto en verify/summary. **Sin StaticsApi (P8).**
  **`run-tests`: mapear `<conn>-*-api` → `Connectors/Accommodation/<Conn>/Test`** (v2: `case`; v1: paso
  secuencial). Sin mapeo, el job falla con exit 1 ("No test mapping for ...").
- **PRO — `pro-build-and-push-image.yaml` + `pro-deploy-from-registry.yaml`:** availability+reservation.
  Compose `_scripts/prod-deploy/docker/connector/<conn>/{avail,reser}/docker-compose.yml` (host→8080), y entradas en
  options/BUILD_PATHS/SLN_NAMES/IMAGE_NAMES/PORTS/COMPOSE_PATHS/CONFIG_KEYS/env (`PRO_CONFIG_<CONN>_*`).
- **Validar** cada workflow tocado con `npx js-yaml <file>` (0 errores) y sin claves de job duplicadas.
- **⚠️ Secrets (config en GitHub, NO en repo):** crear `CONFIG_TEST_<CONN>_{AVAILABILITY,RESERVATION,STATICS}`
  (TEST) y `PRO_CONFIG_<CONN>_{AVAILABILITY,RESERVATION}` (PRO) con el `appsettings.Production.json` de cada
  API. Sin ellos el deploy arranca pero la API queda sin config de producción → **dejarlo documentado como
  acción pendiente del owner**.

## Paso 6 — Documentación de F6 (en `pilots/<slug>/fase6-implementacion/`)

- `00-PROMPT-original.md` — el prompt/criterios (verbatim si vino ad-hoc).
- `01-bitacora.md` — log cronológico + checkboxes de objetivo.
- `02-dudas-decisiones.md` — dudas/bloqueos con opciones + decisión.
- `03-resultado-ejecucion.md` — estructura, build, tabla op→resultado mocks, audit verificado, PRO.
- `04-revision-cumplimiento.md` — **auto-revisión contra DoD §11 + prompt**, veredicto por criterio.

Registra la acción en DB (`/factory-update <slug> ... --env DEV`) con el commit del conector.

## Salida estándar (en TODA parada)

- **Conexión** y estado de F6.
- **Qué se implementó** (operaciones, APIs, audit, mocks).
- **Verificación**: build, ops contra mocks, audit local, PRO (o por qué bloqueado).
- **DoD §11**: ítems cumplidos / pendientes (audit Capa 8 y Deploy explícitos).
- **Deploy**: jobs TEST+PRO añadidos (puertos del bloque) + **secrets pendientes de crear** por el owner.
- **Siguiente**: F7 (E2E desde PerlaHub DEV) + Gate #3 (aprobar PR).
