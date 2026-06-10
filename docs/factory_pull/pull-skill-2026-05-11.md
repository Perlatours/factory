---
name: factory-pull
description: "Proceso estándar para conectar un nuevo rebuyer Pull. Ejecutable por Claude Code con 4 gates HITL. Cubre análisis de documentación, sandbox validation, mock tests, clasificación de mismatches, codificación, testing, go-live y cierre del ciclo de aprendizaje."
version: "0"
date: "2026-05-11"
owner: "Santi"
validator: "Pedro"
status: "borrador-v0"
parent_briefing: factory_pull_briefing_v0.md
---

# Factory Pull (Rebuyers) — Skill v0

## Cómo usar esta Skill

1. Recibes documentación del provider.
2. Ejecutas las fases en orden.
3. En cada **[HITL]**, paras, presentas el output al humano, esperas confirmación explícita antes de avanzar.
4. Al cerrar go-live ejecutas el **Protocolo de actualización** (final del documento).

---

## Inputs requeridos antes de Fase 1

- Nombre del provider.
- Documentación técnica (Swagger / Postman / PDF / ejemplos).
- Credenciales sandbox del provider.
- Contacto técnico.
- Volumen estimado: nº hoteles · nº clientes · hoteles/request · frecuencia.
- Hoteles candidatos al piloto.

> Si falta alguno → **parar y pedir** antes de empezar.

---

## FASE 1 — Análisis de documentación
Output: informe estructurado (Anexo A).

- Identificar endpoints (search · prebook · book · cancel · content · availability).
- Para cada endpoint, extraer estructura request/response.
- Construir **matriz de campos**: `campo_perlahub` | `¿lo tenemos?` | `formato_provider` | `tipo_de_match`.
- Aplicar **checklist de puntos críticos** (Anexo B).
- Calcular **score de compatibilidad** preliminar.
- Calcular **equivalencia de carga** (Anexo E — unidades Hotelbeds).

**[HITL #1]** Aprobación del informe.

---

## FASE 2 — Sandbox Validation

Objetivo: corroborar que la documentación dice la verdad antes de programar.

- Configurar credenciales sandbox.
- Lanzar requests mínimos contra cada endpoint identificado.
- Comparar response real vs response documentado.
- Documentar discrepancias.

Output: reporte de discrepancias **documentación ↔ realidad**.

---

## FASE 3 — Mock Tests

Objetivo: validar comportamiento con casos estándar (Anexo C).

Para cada caso: input → expected output → actual output → resultado.

**Casos estándar v0:**
1. 2 adultos, 1 habitación.
2. 2 adultos + 1 bebé.
3. 2 habitaciones, ocupaciones distintas.
4. Cancelación con política compleja (múltiples tramos).
5. Hotel con varias tarifas / regímenes.
6. Hotel con disponibilidad limitada.
7. Volumen alto / rate limiting.

**[HITL #2]** Revisión de resultados de Mock Tests.

---

## FASE 4 — Clasificación de Match / Dismatch

Para cada mismatch:
- **Directo** → procesar automáticamente.
- **Conocido** → aplicar conversión del catálogo (Anexo D).
- **Nuevo** → presentar a Pedro.

**[HITL #3]** Validación de mismatches nuevos. Criterio de Pedro. Cada nuevo aprobado entra al catálogo al cierre del go-live.

---

## FASE 5 — Informe final de compatibilidad

- Score final.
- Lista completa de mismatches clasificados.
- Equivalencia de carga consolidada (Hotelbeds).
- Riesgos.
- Plan de codificación.

---

## FASE 6 — Codificación

> **Comando estandarizado: `/factory-implement <slug>`.** No implementar ad-hoc; si llega una petición
> manual de implementación, redirigir a este comando (arranca desde el informe + DoD §11, aplica P7,
> incluye **audit Capa 8** y exige verificación en local — mocks + Audit API).

**Reutilizar:**
- Plantilla de conexión Pull (boilerplate connector).
- Mappers existentes para mismatches conocidos.
- Modelo PerlaHub destino (search results, prebook, booking).

**Lógica nueva** solo para mismatches nuevos aprobados en HITL #3.

---

## FASE 7 — Testing E2E desde PerlaHub DEV

- Search → prebook → book → cancel contra sandbox del provider.
- Tests de carga según equivalencia calculada en Fase 1.
- Tests de edge cases detectados en Mock Tests.

---

## FASE 8 — Go-live

**[HITL #4]** Aprobación de go-live.

**Post go-live:**
- Monitorización durante el período de tráfico estable.
- Registro de **sorpresas** (comportamientos no previstos en Mock Tests).
- Métricas: booking error rate, price changed rate, rateKey expired rate.
- Al cerrar el período → Definition of Done.

---

## Definition of Done

Una conexión Pull está terminada cuando:
1. Pasa los Mock Tests.
2. Lleva **[N días]** de tráfico estable sin sorpresas no documentadas. *N pendiente.*
3. **Booking error rate < 4%** sostenido (baseline historial 96.24% success).
4. Mapeo cerrado del piloto.
5. Se ejecuta Protocolo de actualización de Skill.

---

## Protocolo de actualización de Skill (al alcanzar DoD)

1. Listar **sorpresas** registradas durante el período de estabilidad.
2. Listar **mismatches nuevos** aprobados en HITL #3.
3. Incorporar al **Anexo D** (catálogo de mismatches conocidos) los resueltos.
4. Incorporar al **Anexo B** (puntos críticos) los nuevos detectados.
5. Incorporar al **Anexo C** (Mock Tests) los edge cases no cubiertos que aparecieron.
6. Santi promueve nueva versión → `pull-skill-YYYY-MM-DD.md`.
7. Pedro valida.

---

## Anexo A — Plantilla del informe de Fase 1

*Pendiente de definir en v1.*

Estructura mínima:
- Endpoints encontrados.
- Matriz de campos.
- Puntos críticos detectados.
- Score de compatibilidad.
- Equivalencia de carga (Hotelbeds).
- Riesgos.

---

## Anexo B — Checklist de puntos críticos

> Detalle completo en `factory_pull_validaciones.md`.

- **Inventario**: cómo devuelve habitaciones, combinaciones, allotment.
- **Tarifas**: netas vs comisionables, currency, impuestos.
- **Cancelaciones**: formato, granularidad, fechas vs horas, timezone.
- **Ocupaciones**: adultos, niños, bebés, edades.
- **Performance**: límite hoteles/request, response time, rate limiting.
- **Identificación**: IDs hotel/room/rate, duplicados, mapping a Masters.
- **rateKey TTL**: cuánto vive entre search y book.
- **Idempotencia book**: cómo se evita doble reserva.
- **Price changed**: threshold + manejo entre prebook y book.

---

## Anexo C — Mock Tests estándar

7 casos base listados en Fase 3. Ampliable con cada ciclo.

---

## Anexo D — Catálogo de mismatches conocidos

*Vacío en v0.* Se rellena con el primer ciclo de actualización (Hotelbeds + Expedia + Avoris consolidados).

---

## Anexo E — Calculadora de carga

*Pendiente.*

Output esperado: equivalencia en Hotelbeds (ej: "0.25 Hotelbeds") en base a:
- nº hoteles
- nº clientes
- hoteles/request
- frecuencia

---

## Pendientes para v1

1. Definir **N** en Definition of Done.
2. Rellenar **Anexo A** (plantilla del informe).
3. Rellenar **Anexo D** (catálogo inicial extraído de Hotelbeds + Expedia + Avoris).
4. Definir la **calculadora del Anexo E**.
5. **Primera conexión real** (Avoris) calibra todo lo anterior.
