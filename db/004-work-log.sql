-- 004-work-log.sql · Control de tiempos del proceso factory
-- Tiempo EFECTIVO = por día, del primer al último mensaje del developer (hook UserPromptSubmit).
-- Tiempo TOTAL    = del primer al último evento, por conexión (calendario).
-- Actor por rol real: ejecución -> Santi (executor); aprobación HITL -> Pedro (approver).

-- ── Registro granular (lo escribe el hook .claude/hooks/worklog.sh) ──
CREATE TABLE IF NOT EXISTS work_log (
  id              serial PRIMARY KEY,
  ts              timestamptz NOT NULL DEFAULT now(),
  actor           text        NOT NULL,            -- 'Santi' | 'Pedro' | ...
  role            text,                            -- 'developer' | 'executor' | 'approver'
  event_type      text        NOT NULL,            -- 'prompt' | 'skill'
  connection_slug text,                            -- inferido del prompt/args si aplica
  detail          text                             -- nombre de skill+args, o extracto del prompt
);
CREATE INDEX IF NOT EXISTS work_log_ts_idx  ON work_log (ts);

-- ── Timeline retroactivo: deriva el histórico ya hecho de las tablas existentes ──
-- (para días previos al hook no hay 'prompt', así que el día se estima por escrituras en DB)
CREATE OR REPLACE VIEW work_timeline AS
  SELECT a.occurred_at AS ts, 'Santi'::text AS actor, 'executor'::text AS role,
         'action:'||a.action_type AS event_type, c.slug AS connection_slug,
         left(coalesce(a.notes,''),120) AS detail
    FROM actions a JOIN connections c ON c.id = a.connection_id
  UNION ALL
  SELECT pl.occurred_at,
         CASE WHEN pl.actor ILIKE '%pedro%' THEN 'Pedro' ELSE 'Santi' END,
         CASE WHEN pl.actor ILIKE '%pedro%' THEN 'approver' ELSE 'executor' END,
         'phase:'||pl.from_phase||'->'||pl.to_phase, c.slug,
         left(coalesce(pl.notes,''),120)
    FROM phase_log pl JOIN connections c ON c.id = pl.connection_id
  UNION ALL
  SELECT cr.marked_at, 'Santi', 'executor',
         'checklist:'||cr.classification, c.slug, cr.row_key
    FROM checklist_responses cr JOIN connections c ON c.id = cr.connection_id
   WHERE cr.marked_at IS NOT NULL
  UNION ALL
  SELECT s.detected_at, 'Santi', 'executor',
         'surprise', c.slug, left(coalesce(s.title,''),120)
    FROM surprises s JOIN connections c ON c.id = s.connection_id
  UNION ALL
  SELECT g.decided_at,
         coalesce(nullif(g.approver,''),'Pedro'), 'approver',
         'hitl#'||g.gate_number||':'||g.status, c.slug,
         left(coalesce(g.notes,''),120)
    FROM hitl_gates g JOIN connections c ON c.id = g.connection_id
   WHERE g.decided_at IS NOT NULL;

-- ── Stream unificado: hook (en vivo) + retroactivo ──
CREATE OR REPLACE VIEW work_events AS
  SELECT ts, actor, role, event_type, connection_slug, detail, 'live'::text AS src FROM work_log
  UNION ALL
  SELECT ts, actor, role, event_type, connection_slug, detail, 'derived'      FROM work_timeline;

-- ── Tiempo EFECTIVO por día (ventana primer→último evento del día) ──
CREATE OR REPLACE VIEW work_daily AS
  SELECT ts::date                                   AS day,
         min(ts)                                    AS primer,
         max(ts)                                    AS ultimo,
         (max(ts) - min(ts))                        AS efectivo,
         round(extract(epoch FROM (max(ts)-min(ts)))/3600.0, 2) AS efectivo_horas,
         count(*)                                   AS eventos,
         count(*) FILTER (WHERE event_type='prompt') AS mensajes_dev
    FROM work_events
   GROUP BY ts::date
   ORDER BY day;

-- ── Tiempo TOTAL del proceso por conexión (calendario) ──
CREATE OR REPLACE VIEW work_process AS
  SELECT connection_slug                            AS slug,
         min(ts)                                    AS inicio,
         max(ts)                                    AS fin,
         (max(ts) - min(ts))                        AS total_calendario,
         round(extract(epoch FROM (max(ts)-min(ts)))/86400.0, 2) AS total_dias,
         count(DISTINCT ts::date)                   AS dias_con_actividad,
         count(*)                                   AS eventos
    FROM work_events
   WHERE connection_slug IS NOT NULL
   GROUP BY connection_slug
   ORDER BY slug;

-- ── Resumen: efectivo total (suma de ventanas diarias) vs total calendario ──
CREATE OR REPLACE VIEW work_summary AS
  SELECT
    (SELECT round(sum(efectivo_horas),2) FROM work_daily)              AS efectivo_horas_total,
    (SELECT count(*) FROM work_daily)                                  AS dias_trabajados,
    (SELECT round(extract(epoch FROM (max(ts)-min(ts)))/86400.0,2) FROM work_events) AS total_dias_calendario;
