---
title: Factory Push — Carpeta de la Factory de Channels
date: 2026-05-11
tags: [factory, push, channels, indice]
---

# Factory Push

Kit completo para industrializar conexiones nuevas de Channel Managers (Push In) a PerlaPush/PerlaHub.

## Archivos

| Archivo | Qué es | Cuándo usarlo |
|---------|--------|---------------|
| [`factory_push_checklist.md`](./factory_push_checklist.md) | **Checklist rápida** (5 min): lo que PerlaPush pide ↔ lo que da el channel → veredicto Modo A / Modo B / Gap | **Empezar aquí.** Cada vez que llega la pregunta "¿conectamos a este channel manager?" |
| [`factory_push_briefing_v0.md`](./factory_push_briefing_v0.md) | **Proceso** secuencial (12 pasos + 5 HITL gates) | Tras la checklist, si la conexión va |
| [`factory_push_validaciones.md`](./factory_push_validaciones.md) | **Referencia técnica**: 7 capas + 18 error codes + bugs + Definition of Done (52 ítems) | Engineering durante implementación |
| [`push-skill-2026-05-11.md`](./push-skill-2026-05-11.md) | **Skill ejecutable** Claude Code (8 fases + Anexos A-E) | Ejecutar el proceso con agente |

## Cómo navegar
1. Empieza por **`factory_push_briefing_v0.md`** — el proceso paso a paso.
2. En cada paso técnico, consulta **`factory_push_validaciones.md`** para el detalle (7 capas, 20 errores, 10 endpoints, decisiones D1-D6).
3. Ejecuta con **`push-skill-2026-05-11.md`** como prompt para Claude Code.

## Referencias externas
- `../factory_conexiones.md` — visión global de las 3 Factorys (Espejo / Pull / Push)
- `../../productos/perlapush/` — docs de PerlaPush (Push-In Genérico, decisiones)
- `../../../inputdata/pushin/` — fuentes Plan v9 + auditorías + feedback
- `../../../inputdata/dingus/push_payloads/` — payloads XML reales Dingus (caso 0)
