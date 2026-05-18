---
name: factory-sandbox
description: |
  Valida el sandbox del provider de una conexión Pull: lanza ~6 endpoints clave en paralelo
  (auth, search, statics hotels, statics rooms, prebook, book), captura responses y compara
  contra la doc declarada. Es la Fase 2 de Pull. Registra todo en `actions(action_type='sandbox_validate')`.
  Invocar cuando Santi diga "valida sandbox de X", "Fase 2 de X", "/factory-sandbox validate X".
version: "0"
allowed-tools: [Bash, Read, Write]
---

# Factory Sandbox

## Sintaxis

```
/factory-sandbox validate <slug>            # corre los 6 endpoints en paralelo
/factory-sandbox replay <slug> --case <n>   # repite un caso concreto
```

## Pre-requisitos

- Conexión existe con `current_phase >= 1`
- `pilots/<slug>/inputs/03-credentials.local.env` con las variables del provider
- `pilots/<slug>/inputs/endpoints.yml` con los URLs base del sandbox

## validate

### 1. Cargar credenciales

```bash
SLUG="$1"
PILOT="pilots/$SLUG"
[[ ! -f "$PILOT/inputs/03-credentials.local.env" ]] && {
  echo "✗ Falta $PILOT/inputs/03-credentials.local.env"
  exit 1
}
set -a; source "$PILOT/inputs/03-credentials.local.env"; set +a
```

### 2. Lanzar 6 endpoints en paralelo

Estructura sugerida (cada conexión adapta los endpoints concretos):

```bash
mkdir -p "$PILOT/evidence/sandbox-$(date +%Y%m%d-%H%M)"
EVID="$PILOT/evidence/sandbox-$(date +%Y%m%d-%H%M)"

curl_capture() {
  local name="$1"; shift
  echo "▶ $name"
  curl -sS -o "$EVID/$name.body" -D "$EVID/$name.headers" -w "%{http_code}|%{time_total}\n" "$@" > "$EVID/$name.meta" || echo "FAIL|0" > "$EVID/$name.meta"
}

# 6 endpoints en paralelo
curl_capture auth         -X POST -H "X-Api-Key: $PROVIDER_API_KEY" "$PROVIDER_AUTH_URL" &
curl_capture search       -X POST -H "Authorization: Bearer $PROVIDER_TOKEN" -d @"$PILOT/inputs/case-search.json" "$PROVIDER_SEARCH_URL" &
curl_capture statics_htl  -H "Authorization: Bearer $PROVIDER_TOKEN" "$PROVIDER_STATICS_HOTELS_URL" &
curl_capture statics_room -H "Authorization: Bearer $PROVIDER_TOKEN" "$PROVIDER_STATICS_ROOMS_URL" &
curl_capture prebook      -X POST -H "Authorization: Bearer $PROVIDER_TOKEN" -d @"$PILOT/inputs/case-prebook.json" "$PROVIDER_PREBOOK_URL" &
curl_capture book_dry     -X POST -H "Authorization: Bearer $PROVIDER_TOKEN" -d @"$PILOT/inputs/case-book-dry.json" "$PROVIDER_BOOK_URL" &
wait

# Tabla resumen
for f in "$EVID"/*.meta; do
  name=$(basename "$f" .meta)
  IFS='|' read code time < "$f"
  printf "  %-15s  HTTP %s  (%.2fs)\n" "$name" "$code" "$time"
done
```

### 3. Registrar action

```bash
PASS_COUNT=$(grep -l '^2[0-9][0-9]|' "$EVID"/*.meta 2>/dev/null | wc -l)
TOTAL=$(ls "$EVID"/*.meta | wc -l)
OUTCOME="partial"
[[ "$PASS_COUNT" == "$TOTAL" ]] && OUTCOME="pass"
[[ "$PASS_COUNT" == "0" ]] && OUTCOME="fail"

docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO actions (connection_id, phase, action_type, target_env, outcome, evidence_url, notes)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        2, 'sandbox_validate', 'provider-sandbox', '$OUTCOME',
        '$EVID', 'Pass $PASS_COUNT/$TOTAL endpoints');
SQL
```

### 4. Detectar mismatches doc vs realidad

Para cada endpoint con HTTP 2xx, comparar shape response con la doc declarada (`pilots/<slug>/inputs/doc/`):
- Campos esperados que no aparecen → registrar `surprise`
- Campos extra no documentados → registrar `surprise`
- Status codes diferentes a lo declarado → `surprise`

```bash
# Skill ejecuta diff manualmente o sugiere al humano qué inspeccionar
```

## Edge cases

- Provider sandbox no responde → outcome='fail', surprise "sandbox down/unreachable"
- Auth falla → no continúa con los otros 5, outcome='fail'
- Endpoint devuelve 5xx → surprise "sandbox unstable" + outcome='partial'
