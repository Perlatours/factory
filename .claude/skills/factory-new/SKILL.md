---
name: factory-new
description: |
  Crea una nueva conexión en la planta factory. **Ejecuta Fase 0 Intake con 4 criterios obligatorios**
  (doc accesible, sandbox válida, contacto identificado, volumen declarado). Si falta alguno,
  la conexión queda en status='rejected_intake' con notas explícitas y NO entra a la línea.
  Invocar cuando Santi diga "nueva conexión X", "crear pilot Y", "alta proveedor Z".
version: "0"
allowed-tools: [Bash, Write, Read]
---

# Factory New — Fase 0 Intake

## Sintaxis

```
/factory-new <slug> --type <pull|push|espejo|pushout> \
  --display "<Nombre legible>" \
  --contact "<Nombre> <email>" \
  --doc-url <url|local-path> \
  --sandbox-ok <yes|no|untested> \
  --volume "<descripción volumen>" \
  [--mode A|B]                # Push only
  [--pilot]                   # marca is_pilot
```

## Flujo

### 1. Validar 4 criterios Intake (Fase 0)

```python
criteria = {
  "doc_accessible":  bool(doc_url),            # criterio 1
  "sandbox_ok":      sandbox_ok == "yes",      # criterio 2
  "contact":         bool(contact),            # criterio 3
  "volume":          bool(volume),             # criterio 4
}
missing = [k for k,v in criteria.items() if not v]
```

### 2a. Si TODOS los criterios cumplen — INSERT activo

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO connections (
  slug, display_name, factory, mode, is_pilot,
  current_phase, status,
  intake_doc_url, intake_sandbox_ok, intake_contact_name, intake_contact_email,
  intake_volume_notes, contact_name, contact_email
) VALUES (
  '$SLUG','$DISPLAY','$FACTORY',$MODE_SQL,$PILOT_SQL,
  1,'active',
  '$DOC_URL', TRUE, '$CONTACT_NAME','$CONTACT_EMAIL',
  '$VOLUME','$CONTACT_NAME','$CONTACT_EMAIL'
);

-- HITL gates según factory
INSERT INTO hitl_gates (connection_id, gate_number, gate_title, status)
SELECT (SELECT id FROM connections WHERE slug='$SLUG'),
       gate_number, gate_title, 'pending'
FROM (VALUES
  (1, 'Informe final (Fase 5)'),
  (2, 'Aprobar mismatches y wrappers (Fase 4)'),
  (3, 'Aprobar PR código (Fase 6)'),
  (4, 'Go-live PROD (Fase 8)')
) g(gate_number, gate_title)
WHERE '$FACTORY' = 'pull'
UNION ALL
SELECT (SELECT id FROM connections WHERE slug='$SLUG'),
       gate_number, gate_title, 'pending'
FROM (VALUES
  (1, 'Clasificar Modo A/B'),
  (2, 'Informe final'),
  (3, 'Aprobar mismatches'),
  (4, 'Aprobar PR'),
  (5, 'Go-live PROD')
) g(gate_number, gate_title)
WHERE '$FACTORY' = 'push';

INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        0, 1, 'claude/factory-new', 'Intake OK · 4 criterios cumplen');

-- Clonar filas checklist desde template
INSERT INTO checklist_responses (connection_id, section, row_key, row_label, expected, marked_by)
SELECT (SELECT id FROM connections WHERE slug='$SLUG'),
       section, row_key, row_label, expected, NULL
FROM checklist_template_pull
WHERE '$FACTORY' = 'pull';
SQL
```

Luego:
```bash
# Crear estructura pilots/<slug>/
mkdir -p pilots/$SLUG/{inputs,evidence,outputs}
cp -r templates/$FACTORY/pilot-skeleton/* pilots/$SLUG/ 2>/dev/null || true
# Sustituir {{PROVIDER}} / {{slug}}
find pilots/$SLUG -type f -name "*.md" -exec sed -i.bak "s/{{PROVIDER}}/$DISPLAY/g; s/{{slug}}/$SLUG/g; s/{{CLIENT}}/$DISPLAY/g" {} \;
find pilots/$SLUG -name "*.bak" -delete

bash scripts/dump-pilot.sh $SLUG
bash scripts/dump-registry.sh
git add pilots/$SLUG REGISTRY.md
git commit -m "feat($SLUG): nueva conexión $FACTORY · Intake aprobado"
```

Output esperado:
```
✓ Conexión avoris-pull creada
✓ Fase 0 Intake aprobado (4/4 criterios)
✓ Fase actual: 1 (Análisis doc)
✓ HITL gates pendientes: #1, #2, #3, #4
✓ pilots/avoris-pull/ inicializado con plantilla pull/
✓ Checklist Pull cargado (39 filas template)
```

### 2b. Si falta algún criterio — INSERT rechazado

```bash
MISSING_STR=$(echo "${MISSING[@]}" | tr ' ' ',')
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO connections (slug, display_name, factory, current_phase, status, notes)
VALUES ('$SLUG','$DISPLAY','$FACTORY', 0, 'rejected_intake',
        'Faltan criterios Intake: $MISSING_STR');
INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        NULL, 0, 'claude/factory-new', 'Rechazado Intake: $MISSING_STR');
SQL
```

Output:
```
✗ Conexión <slug> rechazada en Intake.
Faltan criterios: <lista>
La conexión queda registrada con status='rejected_intake' para métrica
"tiempo entre solicitud y arranque real". Cuando el solicitante aporte
los inputs faltantes, usa /factory-update <slug> --intake-retry.
```

## Edge cases

- Slug ya existe → "Ya existe `<slug>`. Usa `/factory-update` o renombra."
- Factory no válida → "Tipos válidos: pull/push/espejo/pushout"
- Push v0 → recordar que está fuera del v0 operativo (decisión #11 PLAN)
