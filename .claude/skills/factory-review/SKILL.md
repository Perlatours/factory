---
name: factory-review
description: |
  Conduce la revisión de una puerta HITL como una DISCUSIÓN estructurada (no un approve a ciegas).
  Claude ya tiene toda la info: presenta CADA fila 🟡/🔴 y cada sorpresa como una PROPUESTA
  (clasificación + solución concreta) y el developer valida / ajusta / rechaza cada una. Solo tras
  recorrerlas todas se aprueba la puerta, con una nota que resume lo decidido.
  Invocar cuando Santi diga "revisa el HITL #1 de X", "discutamos las amarillas de X",
  "/factory-review avoris-pull".
version: "1"
allowed-tools: [Bash, Read]
---

# Factory Review — Revisión de puerta HITL (discusión estructurada)

## Filosofía (POR QUÉ existe esta skill)

La puerta HITL **NO es un sello automático**. `--hitl-approve` a secas aprueba todo de golpe y vacía
de sentido la puerta. Aquí es donde el humano y Claude **discuten las decisiones ambiguas**:

- Claude ya leyó la doc y clasificó → **propone** (clasificación + la **solución**: wrapper / mapeo / decisión).
- El developer dice, **por cada ítem**: ✅ tiene sentido · ✏️ ajústalo · 🚩 escala a reunión.
- Solo tras recorrer **todas** las 🔴 y ofrecer todas las 🟡 + sorpresas → se aprueba.

> **Contraste con `factory-pull`:** la ejecución (clasificar, sandbox, mocks) es autónoma y **no pregunta nada**.
> `factory-review` es el **único** sitio donde Claude SÍ dialoga con el humano — pero de forma **estructurada
> por ítem con propuestas concretas**, nunca un menú vago tipo "¿cómo procedo?".

## Sintaxis

```
/factory-review <slug>            # revisa la puerta HITL pendiente más temprana
/factory-review <slug> --gate <N> # revisa una puerta concreta
```

## Paso 0 — Cargar estado + los ítems a discutir (queries EXACTAS)

```bash
# estado + puerta objetivo
docker exec -i factory-db psql -U factory -d factory -P pager=off <<SQL
SELECT id, slug, display_name, current_phase, status FROM connections WHERE slug='$SLUG';
SELECT gate_number, gate_title, status, notes FROM hitl_gates
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG') ORDER BY gate_number;
SQL
```

Guardas: slug no existe / puerta ya `approved` (avisar, no re-aprobar) → STOP con mensaje claro.

**Ítems a discutir según la puerta:**
- **Gate 1 (revisión análisis Fase 1):** filas 🔴 y 🟡 + sorpresas abiertas.
  ```bash
  docker exec -i factory-db psql -U factory -d factory -P pager=off <<SQL
  SELECT section, row_key, row_label, classification, justification, provider_value, evidence_ref
  FROM checklist_responses
  WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
    AND classification IN ('red','yellow')
  ORDER BY (classification='red') DESC, section, row_key;

  SELECT id, title, description, catalog_anexo FROM surprises
  WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG') AND resolved=false ORDER BY id;
  SQL
  ```
- **Gate 2 (mismatches F4):** salida de `/factory-mismatches classify`.
- **Gate 3 (PR F6):** diff/PR del conector. **Gate 4 (go-live F8):** métricas de estabilidad.

## Protocolo de discusión (determinista en el FORMATO, dialogado en las DECISIONES)

1. **Resumen.** Tally (🟢🟡🔴⚪) + "voy a revisar contigo N 🔴, M 🟡 y K sorpresas. Las 🟢/⚪ no se discuten (directo / no aplica), aquí las tienes para referencia."

2. **🔴 — una por una** (gaps reales; cada una es una decisión):
   ```
   🔴 <row_key> · <row_label>
      Provider : <qué hace según doc + §evidencia>
      Canónico : <qué exige PerlaHub>
      Propuesta: <wrapper / decisión / o "escalar a reunión Pedro+Eva+Santi">
      Confianza: <H|M|L>
      → ¿Tiene sentido? (✅ / ✏️ ajustar / 🚩 escalar)
   ```
   **Espera la respuesta del developer antes de seguir a la siguiente 🔴.**

3. **🟡 — agrupadas por tipo**, cada una con su propuesta de solución:
   - *Mapeo/wrapper conocido* (se resuelve en codificación): lista con la solución de cada una.
   - *A confirmar en sandbox/Swagger* (doc silente): lista con qué se confirmará en Fase 2.
   Pide: **"¿confirmas el bloque, o hay alguna que quieras cambiar (dame el row_key)?"**
   Solo paras por las que el developer señale.

4. **Sorpresas — una por una:** título + mitigación propuesta → "¿la mitigación tiene sentido?"

5. **Aplicar ajustes** (solo lo que el developer cambió):
   - Re-clasificar: `/factory-checklist mark <slug> --row <k> --class <c> --notes "[rev:Pedro] <razón>"`
   - Sorpresa: actualizar `description` / resolver si procede.
   Deja constancia de **quién** cambió qué y **por qué**.

6. **Aprobar la puerta** (solo tras recorrer todo):
   ```
   /factory-update <slug> --hitl-approve <N> --approver <quien> \
     --notes "<RESUMEN REAL de lo discutido y decidido — nunca '...'>"
   ```
   La nota debe capturar: nº de ítems revisados, qué se ajustó, qué se escaló, veredicto.

7. **NO avances de fase aquí.** Eso es `/factory-update <slug> --phase <N+1>` o `/factory-pull <slug> --resume`.

## Reglas de control

- **Siempre** presenta la **propuesta + la solución**, no solo el color. El developer valida la solución.
- **No apruebes** hasta haber recorrido todas las 🔴 y ofrecido las 🟡 + sorpresas.
- Si el developer **cambia** una clasificación → re-marca con `factory-checklist` y registra `[rev:<quien>]`.
- La nota de aprobación **resume la discusión** (no `"..."`).
- Idempotente: si la puerta ya está `approved`, no la toques; informa y para.
