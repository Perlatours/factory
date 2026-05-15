---
title: Factory Pull — Carpeta de la Factory de Rebuyers
date: 2026-05-11
tags: [factory, pull, rebuyers, indice]
---

# Factory Pull

Kit completo para industrializar conexiones nuevas de **rebuyers/proveedores Pull** (Hotelbeds, Expedia, Avoris, TGX) a PerlaHub.

> Objetivo: alguien al que conectarnos y recibir su disponibilidad.

## Archivos

| Archivo | Qué es | Cuándo usarlo |
|---------|--------|---------------|
| [`factory_pull_checklist.md`](./factory_pull_checklist.md) | **Checklist rápida** (5 min): lo que PerlaHub pide ↔ lo que da el proveedor → veredicto Directo / Interpretación / Gap | **Empezar aquí.** Cada vez que llega la pregunta "¿conectamos a X?" |
| [`factory_pull_briefing_v0.md`](./factory_pull_briefing_v0.md) | **Proceso** secuencial (11 pasos + 4 HITL gates) | Tras la checklist, si la conexión va |
| [`factory_pull_validaciones.md`](./factory_pull_validaciones.md) | **Referencia técnica**: 9 capas + 18 AuditTypes + bugs + Definition of Done (47 ítems) | Engineering durante implementación |
| [`pull-skill-2026-05-11.md`](./pull-skill-2026-05-11.md) | **Skill ejecutable** Claude Code (8 fases + Anexos A-E) | Ejecutar el proceso con agente |

## Cómo navegar
1. Empieza por **`factory_pull_briefing_v0.md`** — el proceso paso a paso.
2. En cada paso técnico, consulta **`factory_pull_validaciones.md`** para la caja de herramientas histórica (Hotelbeds, Expedia, Avoris, TGX) y trampas conocidas.
3. Ejecuta con **`pull-skill-2026-05-11.md`** como prompt para Claude Code.

## Pilotos / referencias
- **Avoris (Polaris)** — piloto Skill v0
- **Hotelbeds** — referencia mental
- **Expedia** — bundle deploy en curso

## Referencias externas
- `../factory_conexiones.md` — visión global de las 3 Factorys
- `../factory_push/` — Factory simétrica para Channels (Push In)
- `../../integraciones/` — docs por provider (Hotelbeds, Expedia, Avoris, TGX)
