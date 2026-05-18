---
name: factory-status
description: |
  Muestra el estado de la planta factory: tabla resumen de conexiones, o detalle de una conexión.
  Invocar cuando Santi diga "status factory", "cómo va X", "qué conexiones hay activas",
  "qué HITLs están pendientes", "/factory-status [slug]".
version: "0"
allowed-tools: [Bash, Read]
---

# Factory Status

Lee el estado de la planta desde Postgres y muestra al usuario.

## Sintaxis

```
/factory-status                          # tabla resumen REGISTRY-style
/factory-status <slug>                   # detalle conexión <slug>
/factory-status --filter factory=pull    # filtrar por factory
/factory-status --filter status=active   # filtrar por status
/factory-status --hitls                  # solo HITLs pendientes
```

## Sin argumentos — tabla resumen

```bash
docker exec -i factory-db psql -U factory -d factory -t -A -F '|' <<'SQL'
SELECT slug, factory, COALESCE(mode,'—'),
       current_phase, status, dev_status, prod_status,
       COALESCE((SELECT string_agg('#'||gate_number,',' ORDER BY gate_number)
                 FROM hitl_gates h WHERE h.connection_id=c.id AND h.status='pending'),'—')
FROM connections c
WHERE status IN ('active','awaiting_intake','dormant')
ORDER BY factory, current_phase DESC;
SQL
```

Formato salida: tabla markdown con columnas Slug · Factory · Modo · Fase · Status · DEV · PROD · HITLs.

## Con slug — detalle

```bash
SLUG="$1"
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT * FROM connections WHERE slug = '$SLUG';
SELECT gate_number, gate_title, status, approver, decided_at
FROM hitl_gates WHERE connection_id = (SELECT id FROM connections WHERE slug = '$SLUG')
ORDER BY gate_number;
SELECT phase, action_type, target_env, outcome, occurred_at
FROM actions WHERE connection_id = (SELECT id FROM connections WHERE slug = '$SLUG')
ORDER BY occurred_at DESC LIMIT 10;
SELECT title, description, resolved, detected_at
FROM surprises WHERE connection_id = (SELECT id FROM connections WHERE slug = '$SLUG');
SELECT section, classification, COUNT(*)
FROM checklist_responses WHERE connection_id = (SELECT id FROM connections WHERE slug = '$SLUG')
GROUP BY section, classification ORDER BY section;
SQL
```

También: `bash scripts/dump-pilot.sh <slug>` regenera `pilots/<slug>/STATE.md`.

## --hitls

```bash
docker exec -i factory-db psql -U factory -d factory <<'SQL'
SELECT c.slug, h.gate_number, h.gate_title, c.owner_hitl,
       NOW() - c.updated_at AS waiting_for
FROM hitl_gates h
JOIN connections c ON c.id = h.connection_id
WHERE h.status = 'pending'
ORDER BY c.updated_at;
SQL
```

## Edge cases

- Slug no existe → "No existe conexión `<slug>`. Conexiones activas: …" (listar)
- DB no responde → "Container factory-db down. Ejecuta `bash scripts/init-db.sh`"
