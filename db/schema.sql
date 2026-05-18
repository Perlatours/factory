-- =====================================================================
-- Factory · Schema v0 (idempotente)
-- 7 tablas: connections, phase_log, hitl_gates, actions,
--          checklist_responses, surprises, metrics
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. connections — 1 fila por integración (Pull/Push/Espejo/PushOut)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS connections (
  id              SERIAL PRIMARY KEY,
  slug            TEXT UNIQUE NOT NULL,
  display_name    TEXT NOT NULL,
  factory         TEXT NOT NULL CHECK (factory IN ('pull','push','espejo','pushout')),
  mode            TEXT CHECK (mode IS NULL OR mode IN ('A','B')),
  is_pilot        BOOLEAN DEFAULT FALSE,
  current_phase   INTEGER DEFAULT 0,
  status          TEXT DEFAULT 'active'
                  CHECK (status IN ('active','dormant','done','dropped',
                                    'rejected_intake','awaiting_intake')),
  owner_hitl      TEXT,
  -- DEV/PROD tracking
  dev_status      TEXT DEFAULT 'not_deployed',
  prod_status     TEXT DEFAULT 'not_deployed',
  dev_commit      TEXT,
  prod_commit     TEXT,
  dev_pr_url      TEXT,
  prod_pr_url     TEXT,
  -- Intake (Fase 0) fields
  intake_doc_url       TEXT,
  intake_sandbox_ok    BOOLEAN,
  intake_contact_name  TEXT,
  intake_contact_email TEXT,
  intake_volume_notes  TEXT,
  -- Métricas factory
  score_initial   INTEGER,
  score_real      INTEGER,
  contact_name    TEXT,
  contact_email   TEXT,
  jira_epic_url   TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS connections_status_idx ON connections (status);
CREATE INDEX IF NOT EXISTS connections_factory_idx ON connections (factory);

-- ---------------------------------------------------------------------
-- 2. phase_log — transiciones de fase (incluye rebobinado)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS phase_log (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  from_phase    INTEGER,
  to_phase      INTEGER NOT NULL,
  actor         TEXT,
  notes         TEXT,
  occurred_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS phase_log_conn_idx ON phase_log (connection_id, occurred_at DESC);

-- ---------------------------------------------------------------------
-- 3. hitl_gates — puntos de control de calidad humano
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hitl_gates (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  gate_number   INTEGER NOT NULL,
  gate_title    TEXT,
  status        TEXT DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected','skipped')),
  approver      TEXT,
  decided_at    TIMESTAMPTZ,
  evidence_url  TEXT,
  notes         TEXT,
  UNIQUE (connection_id, gate_number)
);

CREATE INDEX IF NOT EXISTS hitl_gates_pending_idx ON hitl_gates (status) WHERE status='pending';

-- ---------------------------------------------------------------------
-- 4. actions — audit granular por entorno
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS actions (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  phase         INTEGER,
  action_type   TEXT NOT NULL,
  target_env    TEXT NOT NULL,
  outcome       TEXT CHECK (outcome IS NULL OR outcome IN ('pass','fail','partial','skipped')),
  evidence_url  TEXT,
  notes         TEXT,
  occurred_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS actions_conn_idx ON actions (connection_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS actions_type_idx ON actions (action_type);

-- ---------------------------------------------------------------------
-- 5. checklist_responses — ~150 filas/conexión Pull, ~170 Push
--    Cross-conexión via (row_key, classification)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checklist_responses (
  id              SERIAL PRIMARY KEY,
  connection_id   INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  section         TEXT NOT NULL,
  row_key         TEXT NOT NULL,
  row_label       TEXT,
  expected        TEXT,
  provider_value  TEXT,
  classification  TEXT CHECK (classification IN ('green','yellow','red','na')),
  evidence_ref    TEXT,
  justification   TEXT,
  marked_by       TEXT,
  marked_at       TIMESTAMPTZ DEFAULT NOW(),
  reviewed_by     TEXT,
  reviewed_at     TIMESTAMPTZ,
  UNIQUE (connection_id, row_key)
);

CREATE INDEX IF NOT EXISTS checklist_cross_idx ON checklist_responses (row_key, classification);

-- ---------------------------------------------------------------------
-- 6. surprises — hallazgos no anticipados
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS surprises (
  id               SERIAL PRIMARY KEY,
  connection_id    INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  description      TEXT,
  catalog_anexo    TEXT,
  related_row_key  TEXT,
  resolved         BOOLEAN DEFAULT FALSE,
  detected_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at      TIMESTAMPTZ,
  resolution_notes TEXT
);

CREATE INDEX IF NOT EXISTS surprises_open_idx ON surprises (connection_id) WHERE NOT resolved;

-- ---------------------------------------------------------------------
-- 7. metrics — métricas por entorno y fecha
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS metrics (
  id            SERIAL PRIMARY KEY,
  connection_id INTEGER REFERENCES connections(id) ON DELETE CASCADE,
  target_env    TEXT NOT NULL,
  metric_date   DATE NOT NULL,
  metric_name   TEXT NOT NULL,
  value         NUMERIC,
  source        TEXT,
  UNIQUE (connection_id, target_env, metric_date, metric_name)
);

CREATE INDEX IF NOT EXISTS metrics_name_idx ON metrics (metric_name, metric_date DESC);

-- ---------------------------------------------------------------------
-- Trigger: updated_at auto en connections
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS connections_updated_at ON connections;
CREATE TRIGGER connections_updated_at
  BEFORE UPDATE ON connections
  FOR EACH ROW EXECUTE FUNCTION trg_updated_at();
