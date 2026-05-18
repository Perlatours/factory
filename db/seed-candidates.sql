-- =====================================================================
-- Seed · 9 candidatos reales (estado al 2026-05-18)
-- =====================================================================

INSERT INTO connections (
  slug, display_name, factory, mode, is_pilot, current_phase, status, owner_hitl,
  contact_name, contact_email, jira_epic_url, notes
) VALUES
-- Pull
('avoris-pull',       'Avoris (Polaris) — Pull nativo', 'pull',    NULL, TRUE,  1, 'active',
 'Pedro', 'Vanesa', 'vanesa@avoris.example', NULL,
 'Piloto Pull v0. Kickoff 13-abr. Sandbox por configurar. Calibra la línea.'),
('hotelbeds-pull',    'Hotelbeds — Cert directa',       'pull',    NULL, FALSE, 0, 'awaiting_intake',
 'Pedro', NULL, NULL, 'caso #54977952',
 'Certificación directa caso #54977952 en curso. Referencia mental Pull (no piloto v0).'),
('expedia-pull',      'Expedia EPS B2B',                 'pull',    NULL, FALSE, 6, 'active',
 'Pedro', 'Eva Soriano', 'eva.soriano@perlatours.com', 'Case #2110684',
 'Handoff operativo Eva 28-abr. Bundle deploy en curso (rama expedia-prod).'),

-- Push (FUERA v0 operativo, solo registrados)
('siteminder-push',   'SiteMinder — Channel Manager',    'push',    NULL, TRUE,  0, 'dormant',
 'Pedro', NULL, NULL, NULL,
 'Piloto Push (Modo a clasificar). Fuera v0 operativo; activar tras Pull estable.'),
('gna-pushin',        'GNA Hotel Solutions',             'push',    'B',  FALSE, 1, 'dormant',
 'Pedro', 'Noemí Becchi', NULL, NULL,
 'Provider id=2 creado en TEST 14-may, sandbox key emitida. Faltan hoteles+webhook. Fuera v0.'),
('cnbooking-push',    'CNBooking — Conexión directa',    'push',    'A',  FALSE, 2, 'dormant',
 'Pedro', 'Heming', NULL, NULL,
 'Primer cliente conexión directa PerlaHub (cred 224). Skill cnbooking-direct. Fuera v0.'),

-- Espejo
('welcomebeds-espejo','Welcomebeds — Espejo TGX',        'espejo',  NULL, FALSE, 1, 'awaiting_intake',
 'Pedro', 'Lara/Cristina Marco', NULL, NULL,
 'Logs entregados 28-abr (escenario B). Fuera v0 operativo, en backlog Espejo.'),
('destinia-espejo',   'Destinia/Techtool — Espejo TGX',  'espejo',  NULL, FALSE, 0, 'awaiting_intake',
 'Pedro', 'Michela Uderzo / Miguel Gomes', NULL, NULL,
 'Evaluación espejo TGX. Rappel 2026 pendiente firma.'),

-- Pushout
('topdog-pushout',    'Top Dog UK — Push Out directo',   'pushout', NULL, FALSE, 0, 'dormant',
 'Santi', 'Graeme', NULL, NULL,
 'Propuesta API directa enviada. Sin código formal hasta candidatos 2-3.')
ON CONFLICT (slug) DO NOTHING;

-- HITL gates por candidato Pull (4 gates estándar Pull)
INSERT INTO hitl_gates (connection_id, gate_number, gate_title, status)
SELECT c.id, g.gate_number, g.gate_title, 'pending'
FROM connections c
CROSS JOIN (VALUES
  (1, 'Informe final (Fase 5)'),
  (2, 'Aprobar mismatches y wrappers (Fase 4)'),
  (3, 'Aprobar PR código (Fase 6)'),
  (4, 'Go-live PROD (Fase 8)')
) g(gate_number, gate_title)
WHERE c.factory = 'pull'
ON CONFLICT (connection_id, gate_number) DO NOTHING;

-- Phase log inicial
INSERT INTO phase_log (connection_id, from_phase, to_phase, actor, notes)
SELECT c.id, NULL, c.current_phase, 'seed', 'Bootstrap factory v0 — estado inicial al 2026-05-18'
FROM connections c
WHERE NOT EXISTS (
  SELECT 1 FROM phase_log p WHERE p.connection_id = c.id
);

-- Verificación
SELECT factory, COUNT(*) FROM connections GROUP BY factory ORDER BY factory;
SELECT status, COUNT(*) FROM connections GROUP BY status ORDER BY status;
