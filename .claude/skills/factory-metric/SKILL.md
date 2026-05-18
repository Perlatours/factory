---
name: factory-metric
description: |
  Registra una métrica de una conexión por entorno y fecha (booking_error_rate, reject_shape_rate,
  tiempo_calendario_fase, horas_santi, etc.). Las métricas alimentan §15 (curva aprendizaje cualitativa)
  y la pantalla "Métricas" del panel control.
  Invocar cuando Santi diga "métrica X de Y en PROD = N", "registra error rate de Avoris".
version: "0"
allowed-tools: [Bash]
---

# Factory Metric

## Sintaxis

```
/factory-metric <slug> --env <env> --date <YYYY-MM-DD> --name <metric_name> --value <num> [--source <grafana|audit_api|manual>]
/factory-metric list <slug>
```

## Nombres de métrica reconocidos

| metric_name | Threshold / target | Notas |
|---|---|---|
| `booking_error_rate` | < 4% (Pull) | DoD principal Pull |
| `reject_shape_rate` | < 2% (Push, 7 días) | DoD principal Push |
| `tiempo_calendario_fase` | (descriptivo) | Días entre transiciones fase |
| `horas_santi` | (descriptivo) | Horas efectivas Santi por conexión |
| `score_complejidad` | 0-15 inicial / real | Suma 5 ejes |
| `mismatches_nuevos` | 0-1 industrial | Cuántos no estaban en catálogo |

## add

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
INSERT INTO metrics (connection_id, target_env, metric_date, metric_name, value, source)
VALUES ((SELECT id FROM connections WHERE slug='$SLUG'),
        '$ENV', '$DATE', '$NAME', $VALUE, '$SOURCE')
ON CONFLICT (connection_id, target_env, metric_date, metric_name) DO UPDATE
SET value = EXCLUDED.value, source = EXCLUDED.source;
SQL
```

## list

```bash
docker exec -i factory-db psql -U factory -d factory <<SQL
SELECT metric_date, target_env, metric_name, value, source
FROM metrics
WHERE connection_id=(SELECT id FROM connections WHERE slug='$SLUG')
ORDER BY metric_date DESC, metric_name;
SQL
```

Tras add: `bash scripts/dump-pilot.sh $SLUG`.

## Avisos automáticos

Si al insertar:
- `booking_error_rate >= 0.04` en `perlahub-prod` → avisa "⚠ Threshold superado, posible alarma DoD"
- `reject_shape_rate >= 0.02` en `perlapush-prod` → idem
