---
title: Factory Push — Proceso
date: 2026-05-11
source: Call Santi + Francesc 14:21–14:45 Europe/Madrid
author: Santiago Patino Serna
tags: [factory, push, channels, proceso, v0]
status: v0
---

# Factory Push IN — Proceso

> **Objetivo**: conectar nuevos channel managers que nos envían disponibilidad. **[Escalable]**
>
> **Dos sub-modos de conexión**:
> - **A — Se conectan con nosotros (Push In Genérico)**: les damos nuestro contrato, ellos construyen el cliente. Casos: CNBooking, GNA.
> - **B — Ellos nos dan la documentación**: construimos el adapter custom. Casos: Dingus, SiteMinder.
>
> Cada conexión nueva ejecuta este proceso secuencial. En cada **[HITL]** se para, se presenta output al humano, se espera confirmación explícita.
> El **recipiente interno es único** — el adapter de entrada es lo único que varía.

---

## Paso 0 — Inputs (antes de empezar)
- [ ] Nombre del provider
- [ ] Documentación técnica (Swagger / Postman / PDF / ejemplos)
- [ ] Credenciales sandbox
- [ ] Contacto técnico
- [ ] Volumen estimado (nº hoteles · frecuencia avg+pico · delta vs full)
- [ ] Hoteles candidatos al piloto (mínimo 1, idealmente 3)

> Si falta alguno → **parar y pedir** antes de empezar.

---

## Paso 1 — Clasificar Modo de conexión
- [ ] Decidir **Modo A** (provider se adapta a nosotros, Push-In Genérico) o **Modo B** (nosotros adaptamos su formato, custom adapter)
- Criterio: equipo técnico + formato parecido al genérico → A · solo "esto envío, conéctate" → B

**→ [HITL #1]** decisión firmada por Santi + Pedro

---

## Paso 2 — Analizar documentación del provider
- [ ] Identificar endpoints (availability · rates · restrictions · close · content)
- [ ] Extraer estructura request/response por endpoint
- [ ] Auth: Bearer / OAuth2 / mTLS / HMAC custom / IP whitelist
- [ ] Formato: JSON / XML / SOAP / propietario
- [ ] Modelo envío: delta vs full snapshot, orden garantizado o no
- [ ] Idempotencia (message_id, dedup, replay)
- [ ] Rate limiting (sus límites + tolerancia a nuestros 500 req/min)
- [ ] SLA de ack (ej 200ms vs 500ms tolerado)
- [ ] Forward-compat (cómo manejan campos nuevos)
- [ ] **Construir matriz de campos** → `campo_recipiente` | `¿lo envían?` | `formato_provider` | `tipo_de_match`
- [ ] Aplicar checklist puntos críticos → `factory_push_validaciones.md`
- [ ] Calcular **score de compatibilidad preliminar**
- [ ] Calcular **equivalencia de carga** en unidades Dingus
- [ ] **Generar informe Fase 1**

**→ [HITL #2]** aprobación del informe

---

## Paso 3 — Validar contra sandbox del provider
- [ ] Configurar credenciales sandbox
- [ ] Lanzar requests reales contra cada endpoint identificado
- [ ] Comparar response real vs documentación
- [ ] **Reportar discrepancias doc ↔ realidad**

---

## Paso 4 — Mock Tests inversos (nosotros = endpoint receptor)
Para cada caso: input simulado → expected → actual → resultado.

- [ ] Caso 1: Full snapshot 1 hotel (availability + rates + restrictions)
- [ ] Caso 2: Delta single update (1 fecha, 1 room)
- [ ] Caso 3: Delta multi-fecha multi-room
- [ ] Caso 4: Close-out
- [ ] Caso 5: Cambio de tarifa retroactivo
- [ ] Caso 6: Mensaje duplicado (idempotencia)
- [ ] Caso 7: Burst 500 msg/min (stress + rate limit)
- [ ] Caso 8: Hotel/credencial NO registrado (test mecanismo alarma)
- [ ] Caso 9: Campo extra desconocido (forward-compat)
- [ ] Caso 10: Shape inválido (rechazo controlado)

**→ [HITL #3]** revisión de resultados

---

## Paso 5 — Clasificar Match / Dismatch
Para cada mismatch detectado en Pasos 2-4:
- [ ] **Directo** → procesar automáticamente
- [ ] **Conocido** → aplicar conversión del catálogo (Anexo D Skill)
- [ ] **Nuevo** → presentar a Pedro

**→ [HITL #4]** validación de mismatches nuevos. Cada nuevo aprobado entra al catálogo al cierre del go-live.

---

## Paso 6 — Informe final de compatibilidad
- [ ] Score final
- [ ] Lista completa mismatches clasificados
- [ ] Equivalencia de carga consolidada (Dingus)
- [ ] Riesgos
- [ ] Plan de codificación

---

## Paso 7 — Codificar
- [ ] **Modo A**: actualizar contrato JSON + entregar credenciales sandbox al provider
- [ ] **Modo B**: implementar `XxxAdapter : IProviderAdapter`
- [ ] **Reutilizar (no reescribir)**:
  - [ ] `IAvailabilityManagementGateway` (escritura PerlaHub)
  - [ ] `OccupancyPriceCalculator` (cálculo precios compartido)
  - [ ] `NormalizedAvailability` + `AvailabilityPrice` (modelo destino)
  - [ ] Las 7 capas de validación
  - [ ] Catálogo de 20 errores
  - [ ] 10 endpoints `/api/v1/`
- [ ] Lógica nueva **SOLO** para mismatches aprobados en HITL #4

---

## Paso 8 — Tests E2E desde PerlaHub DEV
- [ ] Search → ver dispo cargada por el channel
- [ ] Prebook → validar precio + disponibilidad
- [ ] Book (opcional según fase)
- [ ] Tests de carga según equivalencia Dingus
- [ ] Tests de edge cases detectados en Mock Tests
- [ ] Test específico del **mecanismo de alarma** (hoteles no mapeados)

---

## Paso 9 — Validar Mapeo (rama paralela)
> NO bloquea la API, pero debe cerrarse antes del go-live.

- [ ] Hoteles del piloto registrados en Masters PerlaHub
- [ ] Códigos del channel ↔ Masters `InternalCode`
- [ ] Room / rate / mealPlan mappings cerrados
- [ ] Decidir mecanismo concreto **alarma "quién empieza primero"**
  - Cola pending-mapping cuando llega data de hotel/credencial no registrado
  - Alerta a operaciones (Eva)
  - Frontend dedicado: reevaluar al llegar al 3er channel

---

## Paso 10 — Go-live

**→ [HITL #5]** aprobación de go-live

---

## Paso 11 — Monitorización post go-live
- [ ] Monitorización durante período de tráfico estable
- [ ] Métricas vivas:
  - [ ] **% rejects por shape** (objetivo < 2%)
  - [ ] Lag de procesamiento
  - [ ] Hoteles pendientes de mapeo
- [ ] Registro de **sorpresas** (comportamientos no previstos en Mock Tests)

---

## Paso 12 — Cerrar ciclo (Definition of Done)
- [ ] Mock Tests pasados
- [ ] **N días** tráfico estable sin sorpresas no documentadas (N pendiente)
- [ ] **% rejects por shape < 2%** sostenido
- [ ] Mapeo cerrado del piloto
- [ ] **Protocolo de actualización Skill** ejecutado:
  - [ ] Sorpresas listadas
  - [ ] Mismatches nuevos al Anexo D
  - [ ] Puntos críticos nuevos al Anexo B
  - [ ] Edge cases nuevos al Anexo C
  - [ ] Santi promueve nueva versión `push-skill-YYYY-MM-DD.md`
  - [ ] Pedro valida

---

## Decisiones de modo (referencia)
- **Modo A** — provider se adapta a nosotros (Push-In Genérico). Casos: CNBooking, GNA. Entregable: contrato JSON + credenciales sandbox.
- **Modo B** — nosotros adaptamos su formato (adapter custom). Casos: Dingus, SiteMinder. Entregable: nuevo `XxxAdapter : IProviderAdapter`.

---

## Complejidad de la conexión (6 ejes, score 0-3 cada uno)
- **Formato entrada**: JSON estándar (0) / JSON propio (1) / XML estándar (2) / SOAP propietario (3)
- **Modos de precio**: Unit (0) / + Person (1) / + Occupancy (2) / + custom (3)
- **Auth**: Bearer (0) / OAuth2 (1) / + IP whitelist (2) / SOAP+HMAC legacy (3)
- **Validaciones business custom**: 0 (0) / 1-3 (1) / 4-8 (2) / 9+ (3)
- **Full-refresh**: endpoint separado (0) / flag (1) / condicional (2) / implícito-ausente (3)
- **Volumen**: < 1 Dingus (0) / 1-3 (1) / 3-10 (2) / > 10 (3)

**Score total**: 0-5 = Bajo (2-3d) · 6-11 = Medio (1sem) · 12-18 = Alto (2+sem)

---

## Métricas (¿Factory funciona?)

**Pre-conexión:** Score compatibilidad · Complejidad adapter
**Post-conexión:** Horas codificación · Tiempo calendario · Sorpresas en PROD
**Push-específico:** % rejects por shape primeros 7 días

> Si tras N conexiones las horas no bajan → la Factory no funciona, revisamos.

---

## Infra (tema aparte)
PerlaHub debe tener capacidad de escritura. NO se decide en esta Factory.
- Throughput writes/seg sostenidos vs pico
- Particionado / retención / compactación
- **Calculadora de carga** en unidades Dingus (nº hoteles · frecuencia · tamaño msg · modelo)

---

## Qué NO es la Factory hoy
- Certificación / onboarding comercial del channel
- Onboarding de nuevos hoteles en un channel ya conectado (negocio)
- Soporte L1 post-go-live
- Mapeo hotelero (rama paralela, Paso 9)
- Infraestructura general (rama paralela)

---

## Pilotos
- **SiteMinder** — primer caso real, modo a decidir en Paso 1
- **Avoris** Push In si aplica (kickoff 13-abr)
- **Dingus** = referencia mental, ya conectado (caso 0 catálogo)

---

## Cross-ref
- **`factory_push_validaciones.md`** — adjunto técnico: garantías matching PerlaHub ↔ API provider (7 capas · 20 errores · 10 endpoints · `IAvailabilityManagementGateway` · decisiones D1-D6)
- `push-skill-2026-05-11.md` — Skill ejecutable Claude Code (8 fases + Anexos A-E)
- `../factory_conexiones.md` — visión global 3 Factorys

---

## Pendientes v1
- [ ] Definir **N días** del DoD (Paso 12)
- [ ] Calibrar threshold **% rejects por shape** (placeholder 2%)
- [ ] Anexo A plantilla informe Fase 1
- [ ] Anexo D con Dingus como caso 0
- [ ] Calculadora Anexo E (unidades Dingus)
- [ ] Mecanismo concreto alarma "quién empieza primero" (Paso 9)
- [ ] Validar este proceso con Pedro (call 17:00–17:15)
