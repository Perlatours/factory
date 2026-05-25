-- =====================================================================
-- Template de filas checklist Pull (v0).
-- Fuente: docs/factory_pull/factory_pull_checklist.md v3 (~134 filas reales).
-- v0 mantiene las ~40 filas más críticas. El resto se agrega incrementalmente
-- (cada cierre Pull en factory-close puede añadir filas nuevas).
-- v3 (18-may): correcciones Pedro al modelo canónico PerlaHub — global (no por hotel),
--   penalización en amount (no percent), refundable flag general, sin flag "modificable",
--   precio por room (no por noche), rateKey = identificador de disponibilidad reservable.
--   NO aplican a Push/PushOut (modelo PerlaPush/PurchaseContract).
-- =====================================================================

-- Plantilla en tabla auxiliar (sin FK a connections, para clonar al crear).
CREATE TABLE IF NOT EXISTS checklist_template_pull (
  section     TEXT NOT NULL,
  row_key     TEXT NOT NULL,
  row_label   TEXT NOT NULL,
  expected    TEXT NOT NULL,
  PRIMARY KEY (section, row_key)
);

INSERT INTO checklist_template_pull (section, row_key, row_label, expected) VALUES
-- A. Operaciones (6 interfaces canónicas)
('A','op_search',            'Search',                       'Disponibilidad multi-hotel multi-fecha. ¿batch / per-hotel / per-room?'),
('A','op_prebook',           'Prebook / CheckRate',          'Revalida precio con rateKey antes de book. ¿endpoint separado / mismo Search / skip?'),
('A','op_book',              'Book',                         'Confirma reserva + devuelve locator. ¿sync / async + polling?'),
('A','op_cancel',            'Cancel',                       'Anula reserva. ¿con locator / con rateKey?'),
('A','op_getbookings',       'GetBookings',                  'Consulta histórico/estado. ¿per locator / por rango / batch?'),
('A','op_statics',           'Statics (hotels/rooms/etc.)',  'Carga catálogos P1. ¿dump completo / incremental / per id?'),
-- B. Identificación y catálogos
('B','id_hotel_codes',       'Códigos de hotel',             '¿Códigos propios provider / GIATA / both? ¿estables en tiempo?'),
('B','id_room_codes',        'Códigos de habitación',        'PerlaHub es global: NO requiere unicidad por hotel. Importa CÓMO los define el provider (detalle hotel / endpoint) para mapearlos. ¿estables tras edición provider?'),
('B','id_meal_codes',        'Códigos de meal plan',         '¿enum estándar / strings libres? Mapeo necesario'),
('B','id_amenities',         'Amenities',                    '¿taxonomía propia / estándar? Cómo se entregan'),
-- C. Search response (disponibilidad y precio)
('C','search_rate_breakdown','Rate breakdown',               'PerlaHub: total + precio por room (NO pide precio por noche). Provider puede dar nightly|total → mapear. ¿impuestos incluidos / aparte?'),
('C','search_pvp_net',       'PVP vs Net',                   '¿Entrega PVP, neto o ambos? Si PVP, % comisión obligatorio'),
('C','search_rate_key',      'rateKey TTL',                  'Identificador de disponibilidad reservable (por room/opción) para prebook; "rateKey" es nombre heredado. Token opaco. ¿TTL declarado? <10min → RateKeyBuffer'),
('C','search_currency',      'Currency',                     '¿Forzable en request o se entrega como acepte provider?'),
('C','search_taxes',         'Impuestos / fees',             '¿Incluidos en total / desglosados? Stay taxes vs city taxes'),
-- D. Cancellation policy
('D','cancel_policy_format', 'Formato política cancelación', 'Canónico PerlaHub: penalización en AMOUNT (importe; convertir % y noches). refundable = flag GENERAL (no por tramo). SIN flag "modificable". Match CoreCancellationPolicy'),
('D','cancel_timezone',      'Cancellation timezone',        'P5: debe ser UTC + Hotel.TimeZoneId IANA. Provider local time = mismatch'),
('D','cancel_partial',       'Cancelación parcial',          '¿Soporta room-level / solo booking completo?'),
-- E. Check-in / check-out
('E','checkin_time',         'Check-in time',                '¿Por hotel? ¿default 15:00? Late check-in policy'),
('E','checkout_time',        'Check-out time',               '¿Por hotel? ¿default 11:00?'),
-- F. Meal plan
('F','meal_codes_mapping',   'Mapping meal plan',            'Strings provider → enum PerlaHub. P4: usar catálogo real PH'),
('F','meal_addons',          'Addons meal plan',             'Add-ons (almuerzo/cena suplementos) ¿en meal o aparte?'),
-- G. Ocupación, edades, huéspedes
('G','occupancy_adults',     'Adultos por habitación',       'minAdults / maxAdults'),
('G','occupancy_children',   'Niños y edades',               'ageConfiguration: infant/child/teen rangos'),
('G','occupancy_babies',     'Bebés / cunas',                '¿se modelan?'),
-- H. Rate types y promociones
('H','rate_promos',          'Promociones',                  'Early Booking / NRF / Long Stay / Mobile rate / Member rate'),
('H','rate_minstay',         'Minimum stay',                 'Por rate plan / por hotel / global'),
-- I. Restricciones y allotment
('I','restrict_stopsale',    'Stop sale',                    'Por hotel / room / fechas'),
('I','restrict_allotment',   'Allotment / cupos',            '¿open/close/release? Disponibilidad por día'),
-- J. Contenido estático
('J','static_geo',           'Geolocalización',              'Lat/lon + dirección estructurada vs string libre'),
('J','static_images',        'Imágenes',                     'CDN URLs vs IDs. Resolución estándar'),
-- K. Book response
('K','book_locator',         'Locator',                      'Formato (numérico/alfanum) + longitud. ¿provider locator vs PerlaHub locator?'),
('K','book_states',          'Estados de reserva',           'CONFIRMED / PENDING / FAILED. Mapeo a BookingFlowStatuses PH (BOOKED/CANCELLED/ERROR)'),
('K','book_errors',          'Errores estándar',             'Catálogo de error codes y mapping a errores PerlaHub'),
('K','book_async_poll',      'Async/polling',                '¿Book sync o async? Si async, endpoint polling + timeout'),
-- L. Auth y operativa
('L','auth_method',          'Método auth',                  'API key / OAuth2 / JWT / Basic / SOAP WS-Security / mTLS'),
('L','auth_rotation',        'Rotación credenciales',        '¿Rotación periódica? ¿revocación?'),
('L','auth_rate_limits',     'Rate limits',                  'RPS / RPM / burst. Headers de rate limit'),
('L','op_session_state',     'Estado de sesión',             'Stateful (open/close session) vs stateless. Cookies / tokens')
ON CONFLICT (section, row_key) DO UPDATE
SET row_label = EXCLUDED.row_label,
    expected  = EXCLUDED.expected;

-- Verificación
SELECT section, COUNT(*) FROM checklist_template_pull GROUP BY section ORDER BY section;
