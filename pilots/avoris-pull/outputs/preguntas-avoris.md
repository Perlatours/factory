# Preguntas a Avoris (Polaris) — Fase 1

> Conexión: **avoris-pull** · Doc analizada: **PolarisAPI_Specs_v2.5** + cert + portfolio
> Origen: análisis de checklist (`factory-pull` / `factory-review`) · 2026-05-26
> Solo dudas que necesitan respuesta **del proveedor**. El mapeo/conversión interno (códigos→catálogo PH, GMT+1→UTC, etc.) se resuelve en codificación.

---

## 📨 Mensaje para Discord (versión completa, pegar tal cual)

**Avoris / Welcomebeds — Polaris API · dudas de integración (PerlaHub)**

Hola 👋 Hemos analizado la documentación de Polaris v2.5 (+ doc de certificación y portfolio) para integrarla en PerlaHub. La mayoría está clara; nos quedan estas dudas que necesitamos confirmar con vosotros:

### Acceso

**1. Swagger.** ✅ **Resuelto por nuestra parte** — encontramos los OpenAPI públicos: `polarisapi.avoristravel.com/{avail,book,staticdata}/v2/api-docs?group=Public` (UI en `swagger-ui-polaris.barceloviajes.com/polaris`). Con eso avanzamos; si hubiera un Swagger más completo/privado, bienvenido.

### Seguridad / credenciales

**2. Rate limits.** En §7 vemos que devolvéis `HTTP 429 "Rate Limiter Exceeded"` y que debemos avisaros ante aumentos de tráfico. Pero no encontramos los límites concretos. ¿Nos podéis indicar peticiones/seg (o /min) permitidas, tamaño de *burst*, y si devolvéis headers de rate-limit (tipo `X-RateLimit-*` o `Retry-After`)? Lo necesitamos para dimensionar nuestro control de tráfico.

**3. Credenciales TST para certificación.** Nuestras credenciales **PRO** (user `4144001`, sucursal B2B Perlatours) **funcionan correctamente** en `polarisapi.avoristravel.com` (HTTP Basic — avail, statics y prebook verificados). Sin embargo, las credenciales TST de la doc de certificación (`net/Test01Net`) devuelven **`401 "Invalid auth"`** en `tst-polarisapi.avoristravel.com` (y nuestras claves PRO tampoco funcionan allí). Para ejecutar los escenarios de certificación en TST sin generar reservas reales: **¿nos reemitís/activáis unas credenciales TST válidas?** Alternativamente, ¿confirmáis que podemos certificar contra PRO usando tarifas flexibles + cancelación inmediata sin gastos (como sugiere §2.2)?

**4. Rotación de credenciales.** Entendemos que las credenciales PRO se entregan tras la certificación (§2.2). ¿Existe política de **rotación o caducidad** de credenciales (TST y PRO)? ¿Cómo se renueva o revoca si hiciera falta?

### Catálogo / estáticos

**5. Estabilidad de códigos de hotel.** Trabajáis con códigos propios (`Codigo AVO`, ej. `96665`), sin GIATA, y nos disteis el portfolio para mapear contra nuestro inventario. ¿Estos códigos son **estables en el tiempo**, o pueden cambiar (p.ej. al re-dar de alta un hotel)? Si cambian, se nos rompería el mapeo.

**6. Identificación y estabilidad de la habitación.** La habitación viene como `id` compuesto (ej. `H|EXT`) + una cadena `configuration` (`1a2|30|30n0b0`) dentro de la respuesta de disponibilidad.
   (a) ¿Qué identifica de forma fiable el **tipo de habitación** para mapearlo a nuestro catálogo: el `id`, la `configuration`, o ambos? ¿La `configuration` codifica **características de la habitación** (servicios / room amenities), o solo la **ocupación** (habitaciones/adultos/niños)?
   (b) ¿Esos identificadores se **mantienen estables** si el hotel edita o renombra la habitación?

**7. Amenities.** En §6.1, `hotel_details` incluye amenities, pero la doc no detalla la **taxonomía ni los códigos**. ¿Qué conjunto de códigos usáis para amenities? ¿Hay un catálogo de referencia (como `/mealPlans` o `/categories`)?

**8. Imágenes.** `hotel_details` incluye imágenes (§6.1), pero no vemos el formato. ¿Vienen como **URLs (CDN) o como IDs** que hay que resolver? ¿Qué **resoluciones/tamaños** ofrecéis?

**9. Hora de check-in / check-out.** En el flujo (§5.1) `checkIn`/`checkOut` son fechas (`YYYY-MM-DD`), **sin hora**. ¿Entregáis la **hora** de entrada/salida del hotel en algún sitio (p.ej. `hotel_details`)? ¿Hay política de late check-in?

### Tarifas / disponibilidad

**10. Divisa.** En §5.1.2 indicáis que la currency (EUR/USD/GBP) "depende de la configuración elegida (single o multi-currency)". ¿Cómo está configurada **nuestra cuenta**? ¿Podemos forzar una divisa concreta por petición, o se fija a nivel de cuenta?

**11. Estancia mínima.** Vemos el máximo de 30 días de estancia (§5.1), pero no la estancia **mínima**. ¿Se expone el min-stay en algún campo de la respuesta, o la disponibilidad ya devuelve solo combinaciones válidas?

**12. Régimen — add-ons.** Cada distribución trae un único `meal` (§5.1.2). ¿Existe la posibilidad de **add-ons/suplementos** de régimen (p.ej. añadir almuerzo/cena), o el régimen es siempre único por tarifa?

### Reservas / cancelación

**13. Cancelación parcial.** La cancelación (§5.5) se hace por `bookingReferenceID` (reserva completa). En reservas de **varias habitaciones**, ¿se puede cancelar una habitación concreta, o solo la reserva entera?

**14. Impuestos (city tax / resort fees).** El impuesto de comisión viene estructurado (`comTaxPercent`/`comTaxAmount`), pero los impuestos de **ciudad / resort fees** aparecen solo como **texto libre** en `observations` (§5.1.2). ¿Está previsto estructurarlos en campos propios, o seguirán siempre como texto? (De momento nosotros los pasaremos como comentario tal cual.)

**15. `bookingDetails` por fecha.** En §5.4.2/5.4.3 indicáis que la búsqueda por `STAYDATE`/`CREATIONDATE` solo está disponible en **PRO, no en TST**. ¿Lo confirmáis? Lo necesitamos para planificar la validación de GetBookings por rango directamente en PRO.

¡Muchas gracias! 🙏

---

## 🔎 Trazabilidad (uso interno — no enviar a Avoris)

| # | Tema | `row_key` checklist | Por qué quedó pendiente (doc §) |
|---|---|---|---|
| 1 | Swagger (acceso) | — | §3.2 remite al Swagger para amenities, imágenes, transporte auth |
| 2 | Rate limits | `auth_rate_limits` | §7: existe `429`, sin RPS/RPM/burst ni headers |
| 3 | Auth transporte | `auth_method` | user+password dado, mecanismo no mostrado (§2.2/§3) |
| 4 | Rotación credenciales | `auth_rotation` | §2.2: PRO tras cert; sin política de rotación |
| 5 | Estabilidad códigos hotel | `id_hotel_codes` | Códigos propios `Codigo AVO`; estabilidad no documentada |
| 6 | Estabilidad códigos habitación | `id_room_codes` | `id`+`configuration` inline; estabilidad no documentada |
| 7 | Taxonomía amenities | `id_amenities` | §6.1: vía `hotel_details`, taxonomía no en PDF |
| 8 | Formato imágenes | `static_images` | §6.1: URL-vs-ID y resolución no en PDF |
| 9 | Hora check-in/out | `checkin_time`, `checkout_time` | §5.1: fecha sin hora; posible en `hotel_details` |
| 10 | Divisa cuenta | `search_currency` | §5.1.2: currency por config, no forzable por request |
| 11 | Estancia mínima | `rate_minstay` | §5.1: max 30 días; min-stay no expuesto |
| 12 | Add-ons régimen | `meal_addons` | §5.1.2: meal único por tarifa; sin add-ons |
| 13 | Cancelación parcial | `cancel_partial` | §5.5: cancel por `bookingReferenceID` (completa) |
| 14 | Estructurar impuestos | `search_taxes` | §5.1.2: city/resort tax solo en `observations`. Decisión PH: pasar texto tal cual |
| 15 | bookingDetails por fecha PRO-only | `op_getbookings` | §5.4.2/5.4.3: STAYDATE/CREATIONDATE solo en PRO |
