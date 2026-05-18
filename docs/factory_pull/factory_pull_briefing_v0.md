---
title: Factory Pull — Proceso
date: 2026-05-11
source: Apuntes Santi + modelo Pull v0 (Hotelbeds referencia, Avoris piloto)
author: Santiago Patino Serna
tags: [factory, pull, rebuyers, proceso, v0]
status: v0
audience: Pedro (revisa diariamente) · Santi · dev nuevo onboarding
parent: ../../PLAN.md
sibling: factory_pull_checklist.md · factory_pull_validaciones.md
---

# Factory Pull — Proceso

> **Objetivo**: alguien al que conectarnos y recibir su disponibilidad. **[Escalable]**
> Cada conexión nueva ejecuta este proceso secuencial. En cada **[HITL]** se para, se presenta output al humano, se espera confirmación explícita.
> **Hotelbeds = referencia mental** · **Avoris = piloto Skill v0**.

---

## Impacta en

- **Conectores** (siempre)

---

## Paso 0 — Inputs (antes de empezar)

- Nombre del provider (Hotelbeds, Expedia, Avoris, …)
- Documentación técnica (Swagger / Postman / PDF / ejemplos)
- Credenciales sandbox del provider
- Contacto técnico
- Volumen estimado (nº hoteles · nº clientes · hoteles/request · frecuencia)
- Hoteles candidatos al piloto

> Si falta alguno → **parar y pedir** antes de empezar.

---

## Paso 1 — Analizar documentación del provider

- Endpoints expuestos (search · prebook · book · cancel · content · availability)
- Estructura request/response por endpoint
- Auth: API key / OAuth2 / Basic / IP whitelist / mTLS
- Formato: JSON / XML / SOAP
- Modelo precio: net / commissionable / multi-rate / taxes
- **rateKey TTL** (cuánto vive entre search y book)
- Idempotencia de `book` (cómo evitar doble reserva)
- Política de errores (códigos, retry-safe vs no)
- Rate limiting (sus límites)
- **Construir matriz de campos** → `campo_perlahub` | `¿lo envían?` | `formato_provider` | `tipo_de_match`
- Aplicar checklist de puntos críticos → `factory_pull_validaciones.md`
- Calcular **score de compatibilidad** preliminar
- Calcular **equivalencia de carga** en unidades Hotelbeds
- **Generar informe Fase 1**

**→ [HITL #1]** aprobación del informe

---

## Paso 2 — Validar contra sandbox del provider

- Configurar credenciales sandbox
- Lanzar requests reales contra cada endpoint (search + prebook + book + cancel)
- Comparar response real vs documentación
- **Reportar discrepancias doc ↔ realidad**

---

## Paso 3 — Mock Tests (casos estándar)

Para cada caso: input → expected → actual → resultado.

- Caso 1: 2 adultos, 1 habitación
- Caso 2: 2 adultos + 1 bebé
- Caso 3: 2 habitaciones, ocupaciones distintas
- Caso 4: Cancelación con política compleja (múltiples tramos)
- Caso 5: Hotel con varias tarifas / regímenes
- Caso 6: Hotel con disponibilidad limitada
- Caso 7: Volumen alto / rate limiting

---

## Paso 4 — Validar Matching

### 4.1 Matching directo

- Campos 1:1 entre response del provider y modelo PerlaHub
- Auto-procesable, sin intervención

### 4.2 Matcher puntos críticos (NO es lineal)

- **rateKey expiration** entre search y book
- **price changed** entre prebook y book
- **Multi-room** en una sola reserva
- **Cancellation policies** (% / fixed / tiered / refund window)
- **Occupancy expansion** (adults/children/babies + ages)
- **Currency + taxes** (net vs commissionable)
- **Identificación**: hotel IDs / room codes / rate codes ↔ Masters

### 4.3 Caja de herramientas histórica

- Catálogo de mismatches conocidos (Anexo D Skill)
- Hotelbeds + Expedia + Avoris ya generaron experiencia → ver `factory_pull_validaciones.md`
- Para cada mismatch: directo (auto) · conocido (catálogo) · nuevo (**HITL #3**)

---

## Paso 5 — Informe final de compatibilidad

- Score final
- Lista completa mismatches clasificados
- Equivalencia de carga consolidada (Hotelbeds)
- Riesgos
- Plan de codificación

---

## Paso 6 — Codificar

- **Prompt** del agente Claude Code
- **Skill** `pull-skill-2026-05-11.md` (8 fases + Anexos A-E)
- **Reutilizar (no reescribir)**:
  - Plantilla de conexión Pull (boilerplate connector)
  - Mappers existentes para mismatches conocidos
  - Modelo PerlaHub destino (search results, prebook, booking)
- Lógica nueva **SOLO** para mismatches aprobados en HITL #3

---

## Paso 7 — Tests E2E desde PerlaHub DEV

- Search desde PerlaHub DEV usando el nuevo conector
- Prebook (validar rateKey + precio + cancelpolicies)
- Book (reserva real en sandbox)
- Cancel
- Tests de carga según equivalencia Hotelbeds
- Tests de edge cases detectados en Mock Tests
- **Sobre su sandbox real** (no mocks)

---

## Paso 8 — Validar Mapeo (rama paralela)

> NO bloquea la API, pero debe cerrarse antes del go-live.

- Hoteles del piloto mapeados (Mapeador Perla → ChromaDB)
- Códigos del provider ↔ Masters `InternalCode` (hoteles · rooms · rates · mealPlans)
- Validar matches HIGH automáticos
- Resolver ambiguos manualmente

---

## Paso 9 — Go-live

**→** aprobación de go-live

---

## Paso 10 — Monitorización post go-live

- Monitorización durante período de tráfico estable
- Métricas vivas:
  - **Booking error rate** (objetivo < 4%, baseline historial 96.24%)
  - Price changed rate
  - rateKey expired rate
- Registro de **sorpresas** (comportamientos no previstos en Mock Tests)

---

## Paso 11 — Cerrar ciclo (Definition of Done)

- Mock Tests pasados
- **N días** tráfico estable sin sorpresas no documentadas (N pendiente)
- **Booking error rate < 4%** sostenido
- Mapeo cerrado del piloto
- **Protocolo de actualización Skill** ejecutado:
  - Sorpresas listadas
  - Mismatches nuevos al Anexo D
  - Puntos críticos nuevos al Anexo B
  - Edge cases nuevos al Anexo C
  - Santi promueve nueva versión `pull-skill-YYYY-MM-DD.md`
  - Pedro valida

---

## Complejidad de la conexión (6 ejes, score 0-3 cada uno)

- **Formato entrada**: JSON estándar (0) / JSON propio (1) / XML estándar (2) / SOAP propietario (3)
- **Modelos precio**: Simple net (0) / + Commissionable (1) / + Multi-rate (2) / + Tiered taxes (3)
- **Auth**: API key (0) / OAuth2 (1) / + IP whitelist (2) / + mTLS (3)
- **rateKey TTL**: > 30min (0) / 15-30min (1) / 5-15min (2) / < 5min (3)
- **Cancellation policies**: Simple % (0) / Tiered (1) / Multi-tramo (2) / Custom rules (3)
- **Volumen / hoteles per request**: < 1 Hotelbeds (0) / 1-3 (1) / 3-10 (2) / > 10 Hotelbeds (3)

**Score total**: 0-5 = Bajo (2-3d) · 6-11 = Medio (1sem) · 12-18 = Alto (2+sem)

---

## Métricas (¿Factory funciona?)

**Pre-conexión:** Score compatibilidad · Equivalencia Hotelbeds
**Post-conexión:** Horas codificación · Tiempo calendario · Sorpresas en PROD
**Pull-específico:** Booking error rate primeros 7 días (objetivo < 4%, baseline 96.24% success)

> Si tras N conexiones las horas no bajan → la Factory no funciona, revisamos.

---

## Infra (tema aparte)

PerlaHub debe tener capacidad. NO se decide en esta Factory.

- Latencia de search consolidado (multi-provider parallel)
- Cache de rateKey hasta book
- **Calculadora de carga** en unidades Hotelbeds

---

## Qué NO es la Factory hoy

- Certificación / onboarding comercial con el partner
- Onboarding GTM
- Soporte L1 post-go-live
- Mapeo hotelero (rama paralela, Paso 8)
- Infraestructura general (rama paralela)

---

## Pilotos / Casos de referencia

- **Avoris (Polaris)** — piloto Skill v0 (kickoff 13-abr)
- **Hotelbeds** — referencia mental (caso 0 catálogo, certificación caso #54977952)
- **Expedia** — bundle deploy en curso, mapping en progreso

---

## Gates HITL (4)

- **HITL #1**: Aprobar informe de análisis (Paso 1)
- **HITL #2**: Revisar resultados Mock Tests (Paso 3)
- **HITL #3**: Validar mismatches nuevos al catálogo (Paso 4)
- **HITL #4**: Aprobar go-live (Paso 9)

> Todo lo demás corre sin parar al humano.

---

## Cross-ref

- `**factory_pull_validaciones.md`** — adjunto técnico: caja de herramientas histórica + puntos críticos Pull + bugs conocidos
- `pull-skill-2026-05-11.md` — Skill ejecutable Claude Code (8 fases + Anexos A-E)
- `../factory_conexiones.md` — visión global 3 Factorys
- `../factory_push/` — Factory simétrica para channels (Push In)

---

## Pendientes v1

- Definir **N días** del DoD (Paso 11)
- Calibrar threshold **booking error rate** (placeholder 4%)
- Anexo A plantilla informe Fase 1
- Anexo D con Hotelbeds + Expedia + Avoris como casos consolidados
- Calculadora Anexo E (unidades Hotelbeds)
- Validar este proceso con Pedro

