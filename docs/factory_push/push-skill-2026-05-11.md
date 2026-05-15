---
name: factory-push
description: "Proceso estándar para conectar un nuevo Channel Manager (Push In). Ejecutable por Claude Code con 5 gates HITL. Cubre clasificación de modo (A: channel se adapta / B: nosotros adaptamos como Dingus), análisis de documentación, sandbox validation, mock tests inversos, clasificación de mismatches, codificación de adapter, testing E2E desde PerlaHub DEV, go-live y cierre del ciclo de aprendizaje."
version: "0"
date: "2026-05-11"
owner: "Santi"
validator: "Pedro"
status: "borrador-v0"
parent_briefing: factory_push_briefing_v0.md
---

# Factory Push (Channels) — Skill v0

## Cómo usar esta Skill

1. Recibes documentación del channel.
2. Clasificas Modo (A o B) — **HITL #1**.
3. Ejecutas las fases en orden.
4. En cada **[HITL]**, paras, presentas el output al humano, esperas confirmación explícita antes de avanzar.
5. Al cerrar go-live ejecutas el **Protocolo de actualización** (final del documento).

---

## Inputs requeridos antes de Fase 1

- Nombre del channel.
- Documentación técnica (Swagger / Postman / PDF / ejemplos XML o JSON reales).
- Credenciales sandbox:
  - **Modo A**: nuestras credenciales PerlaPush sandbox (para que ellos prueben contra nosotros).
  - **Modo B**: las suyas (para que probemos contra ellos).
- Contacto técnico del channel.
- Volumen estimado: nº hoteles, frecuencia mensajes (avg + pico), modelo (delta vs full snapshot).
- Hoteles candidatos para el piloto (mínimo 1, idealmente 3 con distinta complejidad).

> Si falta alguno → **parar y pedir antes de empezar**.

---

## FASE 0 — Clasificación de Modo

- **Modo A** (channel se adapta): existe Push-In Genérico, el channel construye el cliente. Entregable: contrato actualizado + credenciales sandbox.
- **Modo B** (nosotros adaptamos): hace falta endpoint custom que reciba el formato del channel y traduzca al recipiente interno.

**Criterio de decisión** (calibrar con Pedro):
- Channel con equipo técnico + formato parecido al genérico → **Modo A**.
- Channel que solo ofrece "esto es lo que envío, conéctate" → **Modo B**.

**[HITL #1]** Decisión Modo A/B firmada por Santi + Pedro.

---

## FASE 1 — Análisis de documentación

Output: informe estructurado (Anexo A).

- Identificar endpoints (availability, rates, restrictions, close-out, content si aplica).
- Para cada endpoint, extraer estructura request/response.
- Construir **matriz de campos**: `campo_recipiente_interno` | `¿lo envían?` | `formato_channel` | `tipo_de_match`.
- Aplicar **checklist de puntos críticos** (Anexo B).
- Identificar **SLA exigido** (ack time, frecuencia máxima).
- Identificar **modelo de envío** (delta vs full, idempotencia, dedup).
- Calcular **score de compatibilidad** preliminar.
- Calcular **equivalencia de carga** vs Dingus (Anexo E).

**[HITL #2]** Aprobación del informe.

---

## FASE 2 — Sandbox Validation

Objetivo: corroborar que la documentación dice la verdad antes de programar / antes de entregar el contrato final.

- **Modo A**: el channel envía mensajes a nuestro sandbox PerlaPush. Validamos shape exacto. Si hay discrepancias → ellos corrigen, no nosotros.
- **Modo B**: lanzamos requests al sandbox del channel (si tiene API de consulta) o esperamos muestras reales. Comparamos vs doc.

Output: reporte de discrepancias **documentación ↔ realidad**.

---

## FASE 3 — Mock Tests inversos

Objetivo: validar comportamiento del adapter / recipiente con casos estándar Push (Anexo C).

Para cada caso: input simulado → expected behavior → actual behavior → resultado.

**Casos estándar v0:**
1. Full snapshot 1 hotel (availability + rates + restrictions).
2. Delta single update (1 fecha, 1 room).
3. Delta multi-fecha multi-room.
4. Close-out (cerrar venta de un room).
5. Cambio de tarifa retroactivo (fechas en el pasado próximo).
6. Mensaje duplicado (idempotencia).
7. Burst de mensajes (ej: 500 messages/min — stress).
8. Mensaje de hotel/credencial **NO registrado** (test del mecanismo de alarma).
9. Mensaje con campo extra desconocido (forward-compat).
10. Mensaje con shape inválido (rechazo controlado, sin matar la cola).

**[HITL #3]** Revisión de resultados de Mock Tests.

---

## FASE 4 — Clasificación de Match / Dismatch

Para cada mismatch:
- **Directo** → procesar automáticamente.
- **Conocido** → aplicar conversión del catálogo (Anexo D).
- **Nuevo** → presentar a Pedro.

**[HITL #4]** Validación de mismatches nuevos. Criterio de Pedro. Cada nuevo aprobado entra al catálogo al cierre del go-live.

---

## FASE 5 — Informe final de compatibilidad

- Score final.
- Lista completa de mismatches clasificados.
- Equivalencia de carga consolidada (en unidades Dingus).
- Riesgos.
- Plan de codificación (Modo B) o entregables para el channel (Modo A).

---

## FASE 6 — Codificación

**Reutilizar:**
- **Recipiente interno** (ÚNICO). No se reescribe.
- Mappers existentes para mismatches conocidos.
- Plantillas Push-In Genérico (Modo A → doc; Modo B → boilerplate del adapter).

**Lógica nueva** solo para mismatches nuevos aprobados en HITL #4.

---

## FASE 7 — Testing E2E desde PerlaHub DEV

- **Modo A**: el channel envía mensajes reales a nuestro sandbox; validamos que aterrizan en el recipiente y que PerlaHub DEV los lee bien.
- **Modo B**: generamos mensajes reales del channel hacia nuestro adapter; validamos pipeline completo hasta PerlaHub DEV.

**Tests obligatorios:**
- Tests desde PerlaHub DEV contra dispo cargada por el channel (search → prebook → book opcional).
- Tests de carga según equivalencia calculada en Fase 1.
- Tests de edge cases detectados en Mock Tests.
- Test específico del **mecanismo de alarma** (hoteles no mapeados).

---

## FASE 8 — Go-live

**[HITL #5]** Aprobación de go-live.

**Post go-live:**
- Monitorización durante el período de tráfico estable.
- Métricas vivas: % rejects por shape, lag de procesamiento, hoteles pendientes de mapeo.
- Registro de **sorpresas** (comportamientos no previstos en Mock Tests).
- Al cerrar el período → Definition of Done.

---

## Definition of Done

Una conexión Push está terminada cuando:
1. Pasa los Mock Tests.
2. Lleva **[N días]** de tráfico estable sin sorpresas no documentadas. *N pendiente.*
3. **% rejects por shape < 2%** durante el período de estabilidad.
4. **Mapeo cerrado** para todos los hoteles del piloto.
5. Se ejecuta Protocolo de actualización de Skill.

---

## Protocolo de actualización de Skill (al alcanzar DoD)

1. Listar **sorpresas** registradas durante el período de estabilidad.
2. Listar **mismatches nuevos** aprobados en HITL #4.
3. Incorporar al **Anexo D** (catálogo de mismatches conocidos) los resueltos.
4. Incorporar al **Anexo B** (puntos críticos) los nuevos detectados.
5. Incorporar al **Anexo C** (Mock Tests) los edge cases no cubiertos que aparecieron.
6. Santi promueve nueva versión → `push-skill-YYYY-MM-DD.md`.
7. Pedro valida.

---

## Anexo A — Plantilla del informe de Fase 1

*Pendiente de definir en v1.*

Estructura mínima:
- Modo decidido (A o B) + justificación.
- Endpoints encontrados.
- Matriz de campos.
- SLA exigido.
- Modelo (delta/full/idempotencia).
- Puntos críticos detectados.
- Score de compatibilidad.
- Equivalencia de carga.
- Riesgos.

---

## Anexo B — Checklist de puntos críticos

> **Contrato fijo**: ver `factory_push_validaciones.md` para las 7 capas que toda conexión hereda + 20 códigos de error + 10 endpoints + integración `IAvailabilityManagementGateway`. Este Anexo se centra en **qué difiere por conexión**.

- **Inventario**: allotment vs free-to-sell, granularidad (room-day vs ratecode-day).
- **Tarifas**: netas vs comisionables, currency, ocupaciones por tarifa, multi-tarifa por room, impuestos.
- **Modelos de precio**: Unit / Person / Occupancy / combinación (mapean a `OccupancyPriceCalculator`).
- **Restrictions**: MLOS, CTA, CTD, MaxLOS, close-out, channels separados.
- **Ocupaciones**: adultos, niños, bebés, edades, configurable por room/rate (fallback a hotel.AgeConfiguration).
- **Performance**: mensajes/seg sostenidos vs pico, batch size, response SLA exigido, retries, rate limiting (por defecto 500 req/min per-provider).
- **Identificación**: códigos hotel/room/rate, duplicados, namespace. Modo B: cómo se traducen sus IDs a InternalCode de Masters.
- **Idempotencia**: si el provider envía `X-Idempotency-Key` y respeta semántica body-fingerprint (D1).
- **Forward-compat**: cómo manejan campos nuevos no documentados.
- **Modo de envío**: delta vs full snapshot, frecuencia (real-time vs periódico), cola vs streaming, orden garantizado.
- **Decisiones D1-D6**: cualquier conflicto con estas decisiones es HITL #4 obligatorio (ver doc validaciones §8).

---

## Anexo C — Mock Tests estándar

10 casos base listados en Fase 3. Ampliable con cada ciclo.

---

## Anexo D — Catálogo de mismatches conocidos

*Vacío en v0.* Se rellena al cerrar **Dingus formalmente como caso 0** + primer piloto nuevo (SiteMinder o el que entre primero del funnel).

---

## Anexo E — Calculadora de carga

*Pendiente.*

Output esperado: equivalencia en Dingus (ej: "0.7 Dingus") en base a:
- nº hoteles
- frecuencia avg + pico de mensajes/hora
- tamaño promedio del mensaje
- modelo (full snapshot pesa más que delta)

---

## Pendientes para v1

1. Definir **N** en Definition of Done (días de tráfico estable).
2. Rellenar **Anexo A** (plantilla del informe).
3. Rellenar **Anexo D** con extracto de Dingus como caso 0.
4. Definir la **calculadora del Anexo E** con Dingus baseline.
5. Definir **mecanismo concreto de alarma** "quién empieza primero" (Capa 3 mapeo).
6. **Primera conexión real** (SiteMinder o siguiente del funnel) calibra todo lo anterior.
