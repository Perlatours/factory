---
name: factory-surprise
description: |
  Registra una sorpresa (hallazgo no anticipado) en una conexión, o marca una como resuelta.
  Las sorpresas son input directo para el catálogo Anexo D al hacer factory-close.
  Invocar cuando Santi diga "sorpresa en X: ...", "resuelve sorpresa N de X".
version: "0"
allowed-tools: [Bash]
---

# Factory Surprise

## Sintaxis

```
/factory-surprise add <slug> --title "..." [--description "..."] [--anexo B|C|D] [--row <row_key>]
/factory-surprise resolve <slug> --id <surprise_id> --notes "Cómo se resolvió"
/factory-surprise list <slug>                    # sorpresas abiertas
```

## add

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO surprises (connection_id, title, description, catalog_anexo, related_row_key)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        '$TITLE', $DESC_SQL, $ANEXO_SQL, $ROW_KEY_SQL)
RETURNING id;
SQL
```

## resolve

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
UPDATE surprises
SET resolved=TRUE, resolved_at=NOW(), resolution_notes='$NOTES'
WHERE id=$ID;
SQL
```

## list

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT id, title, COALESCE(catalog_anexo,'—'), detected_at, resolved
FROM surprises
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
ORDER BY resolved, detected_at DESC;
SQL
```

Tras add/resolve: `bash scripts/dump-pilot.sh $SLUG && bash scripts/dump-registry.sh`.
