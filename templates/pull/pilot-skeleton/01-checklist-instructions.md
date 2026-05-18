# Checklist · {{PROVIDER}}

Usa `/factory-checklist mark {{slug}} --row <row_key> --class <green|yellow|red|na>` para marcar cada fila.

- 🟢 **green** — Directo. Provider lo entrega tal cual.
- 🟡 **yellow** — Interpretación. Mapear/parsear pero hay forma.
- 🔴 **red** — Gap. Reunión Pedro+Eva+Santi.
- ⚪ **na** — No aplica a este provider.

Estado actual: `/factory-checklist diff {{slug}}` o `psql ... SELECT section, classification, COUNT(*) ...`.

Finalizar (todas las filas marcadas o `na`): `/factory-checklist finalize {{slug}}` → HITL #1.
