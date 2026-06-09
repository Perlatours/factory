#!/usr/bin/env bash
# _lib.sh — helpers compartidos para los mock-cases de Avoris (Polaris) contra PRO.
# Regla: coste 0. Casos 1-6 solo hasta prebook. Caso 7 book+cancel reembolsable.
set -uo pipefail

: "${AVORIS_PRO_BASE_URL:=https://polarisapi.avoristravel.com}"
: "${AVORIS_PRO_USER:?falta AVORIS_PRO_USER}"
: "${AVORIS_PRO_PASSWORD:?falta AVORIS_PRO_PASSWORD}"
AUTH="$AVORIS_PRO_USER:$AVORIS_PRO_PASSWORD"

api() { # api <path> <json-file>  -> imprime body, status en $API_HTTP
  local path="$1" body="$2" out
  out=$(curl -sS -w '\n%{http_code}' -X POST "$AVORIS_PRO_BASE_URL$path" \
        -u "$AUTH" -H 'Content-Type: application/json' --data @"$body" --max-time 45)
  API_HTTP="${out##*$'\n'}"
  printf '%s' "${out%$'\n'*}"
}

# avail_rq <file> <checkIn> <checkOut> <destJSON> <roomsJSON> [extra]
avail_rq() {
  local f="$1" ci="$2" co="$3" dest="$4" rooms="$5" extra="${6:-}"
  cat > "$f" <<JSON
{ "hotelAvailability": { "searchAvail": {
  "checkIn": "$ci", "checkOut": "$co", "locale": "es_ES", "market": "ES"
  ${extra:+, $extra}, "destination": $dest, "rooms": $rooms
}, "timeout": 30000 }, "token": "perla-mock" }
JSON
}

BCN_GEO='{"hotelCodes":[],"location":{"destinationCode":"BCN","type":"GEOGRAPHIC"}}'
