--
-- PostgreSQL database dump
--

\restrict mkhOgCoHYBGVBxhjmthELeti7zlfRdeEWYFl9mRwFl2U9ejT6ThxbzwIaiBYsao

-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.surprises DROP CONSTRAINT IF EXISTS surprises_connection_id_fkey;
ALTER TABLE IF EXISTS ONLY public.phase_log DROP CONSTRAINT IF EXISTS phase_log_connection_id_fkey;
ALTER TABLE IF EXISTS ONLY public.metrics DROP CONSTRAINT IF EXISTS metrics_connection_id_fkey;
ALTER TABLE IF EXISTS ONLY public.hitl_gates DROP CONSTRAINT IF EXISTS hitl_gates_connection_id_fkey;
ALTER TABLE IF EXISTS ONLY public.checklist_responses DROP CONSTRAINT IF EXISTS checklist_responses_connection_id_fkey;
ALTER TABLE IF EXISTS ONLY public.actions DROP CONSTRAINT IF EXISTS actions_connection_id_fkey;
DROP TRIGGER IF EXISTS connections_updated_at ON public.connections;
DROP INDEX IF EXISTS public.work_log_ts_idx;
DROP INDEX IF EXISTS public.surprises_open_idx;
DROP INDEX IF EXISTS public.phase_log_conn_idx;
DROP INDEX IF EXISTS public.metrics_name_idx;
DROP INDEX IF EXISTS public.hitl_gates_pending_idx;
DROP INDEX IF EXISTS public.connections_status_idx;
DROP INDEX IF EXISTS public.connections_factory_idx;
DROP INDEX IF EXISTS public.checklist_cross_idx;
DROP INDEX IF EXISTS public.actions_type_idx;
DROP INDEX IF EXISTS public.actions_conn_idx;
ALTER TABLE IF EXISTS ONLY public.work_log DROP CONSTRAINT IF EXISTS work_log_pkey;
ALTER TABLE IF EXISTS ONLY public.surprises DROP CONSTRAINT IF EXISTS surprises_pkey;
ALTER TABLE IF EXISTS ONLY public.phase_log DROP CONSTRAINT IF EXISTS phase_log_pkey;
ALTER TABLE IF EXISTS ONLY public.metrics DROP CONSTRAINT IF EXISTS metrics_pkey;
ALTER TABLE IF EXISTS ONLY public.metrics DROP CONSTRAINT IF EXISTS metrics_connection_id_target_env_metric_date_metric_name_key;
ALTER TABLE IF EXISTS ONLY public.hitl_gates DROP CONSTRAINT IF EXISTS hitl_gates_pkey;
ALTER TABLE IF EXISTS ONLY public.hitl_gates DROP CONSTRAINT IF EXISTS hitl_gates_connection_id_gate_number_key;
ALTER TABLE IF EXISTS ONLY public.connections DROP CONSTRAINT IF EXISTS connections_slug_key;
ALTER TABLE IF EXISTS ONLY public.connections DROP CONSTRAINT IF EXISTS connections_pkey;
ALTER TABLE IF EXISTS ONLY public.checklist_template_pull DROP CONSTRAINT IF EXISTS checklist_template_pull_pkey;
ALTER TABLE IF EXISTS ONLY public.checklist_responses DROP CONSTRAINT IF EXISTS checklist_responses_pkey;
ALTER TABLE IF EXISTS ONLY public.checklist_responses DROP CONSTRAINT IF EXISTS checklist_responses_connection_id_row_key_key;
ALTER TABLE IF EXISTS ONLY public.actions DROP CONSTRAINT IF EXISTS actions_pkey;
ALTER TABLE IF EXISTS public.work_log ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.surprises ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.phase_log ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.metrics ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.hitl_gates ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.connections ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.checklist_responses ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.actions ALTER COLUMN id DROP DEFAULT;
DROP VIEW IF EXISTS public.work_summary;
DROP VIEW IF EXISTS public.work_process;
DROP SEQUENCE IF EXISTS public.work_log_id_seq;
DROP VIEW IF EXISTS public.work_daily;
DROP VIEW IF EXISTS public.work_events;
DROP VIEW IF EXISTS public.work_timeline;
DROP TABLE IF EXISTS public.work_log;
DROP SEQUENCE IF EXISTS public.surprises_id_seq;
DROP TABLE IF EXISTS public.surprises;
DROP SEQUENCE IF EXISTS public.phase_log_id_seq;
DROP TABLE IF EXISTS public.phase_log;
DROP SEQUENCE IF EXISTS public.metrics_id_seq;
DROP TABLE IF EXISTS public.metrics;
DROP SEQUENCE IF EXISTS public.hitl_gates_id_seq;
DROP TABLE IF EXISTS public.hitl_gates;
DROP SEQUENCE IF EXISTS public.connections_id_seq;
DROP TABLE IF EXISTS public.connections;
DROP TABLE IF EXISTS public.checklist_template_pull;
DROP SEQUENCE IF EXISTS public.checklist_responses_id_seq;
DROP TABLE IF EXISTS public.checklist_responses;
DROP SEQUENCE IF EXISTS public.actions_id_seq;
DROP TABLE IF EXISTS public.actions;
DROP FUNCTION IF EXISTS public.trg_updated_at();
--
-- Name: trg_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actions (
    id integer NOT NULL,
    connection_id integer,
    phase integer,
    action_type text NOT NULL,
    target_env text NOT NULL,
    outcome text,
    evidence_url text,
    notes text,
    occurred_at timestamp with time zone DEFAULT now(),
    CONSTRAINT actions_outcome_check CHECK (((outcome IS NULL) OR (outcome = ANY (ARRAY['pass'::text, 'fail'::text, 'partial'::text, 'skipped'::text]))))
);


--
-- Name: actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.actions_id_seq OWNED BY public.actions.id;


--
-- Name: checklist_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_responses (
    id integer NOT NULL,
    connection_id integer,
    section text NOT NULL,
    row_key text NOT NULL,
    row_label text,
    expected text,
    provider_value text,
    classification text,
    evidence_ref text,
    justification text,
    marked_by text,
    marked_at timestamp with time zone DEFAULT now(),
    reviewed_by text,
    reviewed_at timestamp with time zone,
    CONSTRAINT checklist_responses_classification_check CHECK ((classification = ANY (ARRAY['green'::text, 'yellow'::text, 'red'::text, 'na'::text])))
);


--
-- Name: checklist_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklist_responses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklist_responses_id_seq OWNED BY public.checklist_responses.id;


--
-- Name: checklist_template_pull; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_template_pull (
    section text NOT NULL,
    row_key text NOT NULL,
    row_label text NOT NULL,
    expected text NOT NULL
);


--
-- Name: connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connections (
    id integer NOT NULL,
    slug text NOT NULL,
    display_name text NOT NULL,
    factory text NOT NULL,
    mode text,
    is_pilot boolean DEFAULT false,
    current_phase integer DEFAULT 0,
    status text DEFAULT 'active'::text,
    owner_hitl text,
    dev_status text DEFAULT 'not_deployed'::text,
    prod_status text DEFAULT 'not_deployed'::text,
    dev_commit text,
    prod_commit text,
    dev_pr_url text,
    prod_pr_url text,
    intake_doc_url text,
    intake_sandbox_ok boolean,
    intake_contact_name text,
    intake_contact_email text,
    intake_volume_notes text,
    score_initial integer,
    score_real integer,
    contact_name text,
    contact_email text,
    jira_epic_url text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT connections_factory_check CHECK ((factory = ANY (ARRAY['pull'::text, 'push'::text, 'espejo'::text, 'pushout'::text]))),
    CONSTRAINT connections_mode_check CHECK (((mode IS NULL) OR (mode = ANY (ARRAY['A'::text, 'B'::text])))),
    CONSTRAINT connections_status_check CHECK ((status = ANY (ARRAY['active'::text, 'dormant'::text, 'done'::text, 'dropped'::text, 'rejected_intake'::text, 'awaiting_intake'::text])))
);


--
-- Name: connections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.connections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.connections_id_seq OWNED BY public.connections.id;


--
-- Name: hitl_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hitl_gates (
    id integer NOT NULL,
    connection_id integer,
    gate_number integer NOT NULL,
    gate_title text,
    status text DEFAULT 'pending'::text,
    approver text,
    decided_at timestamp with time zone,
    evidence_url text,
    notes text,
    CONSTRAINT hitl_gates_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'skipped'::text])))
);


--
-- Name: hitl_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hitl_gates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hitl_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hitl_gates_id_seq OWNED BY public.hitl_gates.id;


--
-- Name: metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metrics (
    id integer NOT NULL,
    connection_id integer,
    target_env text NOT NULL,
    metric_date date NOT NULL,
    metric_name text NOT NULL,
    value numeric,
    source text
);


--
-- Name: metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.metrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.metrics_id_seq OWNED BY public.metrics.id;


--
-- Name: phase_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phase_log (
    id integer NOT NULL,
    connection_id integer,
    from_phase integer,
    to_phase integer NOT NULL,
    actor text,
    notes text,
    occurred_at timestamp with time zone DEFAULT now()
);


--
-- Name: phase_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.phase_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: phase_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.phase_log_id_seq OWNED BY public.phase_log.id;


--
-- Name: surprises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.surprises (
    id integer NOT NULL,
    connection_id integer,
    title text NOT NULL,
    description text,
    catalog_anexo text,
    related_row_key text,
    resolved boolean DEFAULT false,
    detected_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone,
    resolution_notes text
);


--
-- Name: surprises_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.surprises_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surprises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.surprises_id_seq OWNED BY public.surprises.id;


--
-- Name: work_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_log (
    id integer NOT NULL,
    ts timestamp with time zone DEFAULT now() NOT NULL,
    actor text NOT NULL,
    role text,
    event_type text NOT NULL,
    connection_slug text,
    detail text
);


--
-- Name: work_timeline; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_timeline AS
 SELECT a.occurred_at AS ts,
    'Santi'::text AS actor,
    'executor'::text AS role,
    ('action:'::text || a.action_type) AS event_type,
    c.slug AS connection_slug,
    "left"(COALESCE(a.notes, ''::text), 120) AS detail
   FROM (public.actions a
     JOIN public.connections c ON ((c.id = a.connection_id)))
UNION ALL
 SELECT pl.occurred_at AS ts,
        CASE
            WHEN (pl.actor ~~* '%pedro%'::text) THEN 'Pedro'::text
            ELSE 'Santi'::text
        END AS actor,
        CASE
            WHEN (pl.actor ~~* '%pedro%'::text) THEN 'approver'::text
            ELSE 'executor'::text
        END AS role,
    ((('phase:'::text || pl.from_phase) || '->'::text) || pl.to_phase) AS event_type,
    c.slug AS connection_slug,
    "left"(COALESCE(pl.notes, ''::text), 120) AS detail
   FROM (public.phase_log pl
     JOIN public.connections c ON ((c.id = pl.connection_id)))
UNION ALL
 SELECT cr.marked_at AS ts,
    'Santi'::text AS actor,
    'executor'::text AS role,
    ('checklist:'::text || cr.classification) AS event_type,
    c.slug AS connection_slug,
    cr.row_key AS detail
   FROM (public.checklist_responses cr
     JOIN public.connections c ON ((c.id = cr.connection_id)))
  WHERE (cr.marked_at IS NOT NULL)
UNION ALL
 SELECT s.detected_at AS ts,
    'Santi'::text AS actor,
    'executor'::text AS role,
    'surprise'::text AS event_type,
    c.slug AS connection_slug,
    "left"(COALESCE(s.title, ''::text), 120) AS detail
   FROM (public.surprises s
     JOIN public.connections c ON ((c.id = s.connection_id)))
UNION ALL
 SELECT g.decided_at AS ts,
    COALESCE(NULLIF(g.approver, ''::text), 'Pedro'::text) AS actor,
    'approver'::text AS role,
    ((('hitl#'::text || g.gate_number) || ':'::text) || g.status) AS event_type,
    c.slug AS connection_slug,
    "left"(COALESCE(g.notes, ''::text), 120) AS detail
   FROM (public.hitl_gates g
     JOIN public.connections c ON ((c.id = g.connection_id)))
  WHERE (g.decided_at IS NOT NULL);


--
-- Name: work_events; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_events AS
 SELECT work_log.ts,
    work_log.actor,
    work_log.role,
    work_log.event_type,
    work_log.connection_slug,
    work_log.detail,
    'live'::text AS src
   FROM public.work_log
UNION ALL
 SELECT work_timeline.ts,
    work_timeline.actor,
    work_timeline.role,
    work_timeline.event_type,
    work_timeline.connection_slug,
    work_timeline.detail,
    'derived'::text AS src
   FROM public.work_timeline;


--
-- Name: work_daily; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_daily AS
 SELECT (ts)::date AS day,
    min(ts) AS primer,
    max(ts) AS ultimo,
    (max(ts) - min(ts)) AS efectivo,
    round((EXTRACT(epoch FROM (max(ts) - min(ts))) / 3600.0), 2) AS efectivo_horas,
    count(*) AS eventos,
    count(*) FILTER (WHERE (event_type = 'prompt'::text)) AS mensajes_dev
   FROM public.work_events
  GROUP BY ((ts)::date)
  ORDER BY ((ts)::date);


--
-- Name: work_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.work_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: work_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.work_log_id_seq OWNED BY public.work_log.id;


--
-- Name: work_process; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_process AS
 SELECT connection_slug AS slug,
    min(ts) AS inicio,
    max(ts) AS fin,
    (max(ts) - min(ts)) AS total_calendario,
    round((EXTRACT(epoch FROM (max(ts) - min(ts))) / 86400.0), 2) AS total_dias,
    count(DISTINCT (ts)::date) AS dias_con_actividad,
    count(*) AS eventos
   FROM public.work_events
  WHERE (connection_slug IS NOT NULL)
  GROUP BY connection_slug
  ORDER BY connection_slug;


--
-- Name: work_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_summary AS
 SELECT ( SELECT round(sum(work_daily.efectivo_horas), 2) AS round
           FROM public.work_daily) AS efectivo_horas_total,
    ( SELECT count(*) AS count
           FROM public.work_daily) AS dias_trabajados,
    ( SELECT round((EXTRACT(epoch FROM (max(work_events.ts) - min(work_events.ts))) / 86400.0), 2) AS round
           FROM public.work_events) AS total_dias_calendario;


--
-- Name: actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions ALTER COLUMN id SET DEFAULT nextval('public.actions_id_seq'::regclass);


--
-- Name: checklist_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_responses ALTER COLUMN id SET DEFAULT nextval('public.checklist_responses_id_seq'::regclass);


--
-- Name: connections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections ALTER COLUMN id SET DEFAULT nextval('public.connections_id_seq'::regclass);


--
-- Name: hitl_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hitl_gates ALTER COLUMN id SET DEFAULT nextval('public.hitl_gates_id_seq'::regclass);


--
-- Name: metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics ALTER COLUMN id SET DEFAULT nextval('public.metrics_id_seq'::regclass);


--
-- Name: phase_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phase_log ALTER COLUMN id SET DEFAULT nextval('public.phase_log_id_seq'::regclass);


--
-- Name: surprises id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprises ALTER COLUMN id SET DEFAULT nextval('public.surprises_id_seq'::regclass);


--
-- Name: work_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log ALTER COLUMN id SET DEFAULT nextval('public.work_log_id_seq'::regclass);


--
-- Data for Name: actions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.actions (id, connection_id, phase, action_type, target_env, outcome, evidence_url, notes, occurred_at) FROM stdin;
1	1	2	sandbox_validate	provider-sandbox-TST	fail	pilots/avoris-pull/evidence/sandbox-20260526-1625	TST alcanzable (avail responde en ~0.2s) pero AUTH falla: HTTP Basic -> 401 "Invalid auth"; headers user/password -> 401. Mecanismo de auth no documentado (Q#3). Bloqueado hasta respuesta de Avoris o Swagger.	2026-05-26 14:26:01.079469+00
2	1	2	sandbox_validate	provider-PRO	partial	pilots/avoris-pull/evidence/sandbox-pro-20260604/	Creds PRO Perlatours (user 4144001, Basic) FUNCIONAN. 5/6 checks PASS: auth OK · search OK (BCN GEOGRAPHIC: 119 hoteles, 1.06s, 2MB) · statics hotelInformation OK (services+images+chain) · prebook CONFIRMED (paridad exacta avail->prebook 317.23 EUR, ttl=3360s explicito, 3 tramos cancelacion) · 1er prebook dio Result availables mismatch (carrera inventario, retry inmediato OK). BOOK NO testeado: PRO = reserva real facturable, requiere decision humana. TST sigue 401 con creds nuevas y viejas.	2026-06-04 12:40:58.766272+00
3	1	2	sandbox_validate	provider-PRO	pass	pilots/avoris-pull/evidence/sandbox-pro-20260609-e2e/	FLUJO COMPLETO 6/6 PASS en PRO con tarifa reembolsable (coste 0): search BCN sep -> prebook CONFIRMED (234.98 EUR, ttl 3360s) -> BOOK CONFIRMED (bookingReferenceID 802885266, voucher Alisios Tours 052035) -> bookingDetail CONFIRMED (2 travellers) -> CANCEL status=CANCEL sin gasto -> bookingDetail post=CANCEL. Hallazgo: travellers usan index de HABITACION (ambos pax index=1 para [30,30]), no index de pasajero -> 1er intento ERROR_GENERAL_ERROR_REQUEST Traveller ages mismatch.	2026-06-09 08:12:05.582679+00
4	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/1-basic-prebook.json	basic_1_night: 1 noche 2 adultos BCN -> prebook CONFIRMED	2026-06-09 10:04:34.725769+00
5	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/2-multinight-prebook.json	multi_night: 7 noches -> CONFIRMED, sell 1420.33 EUR. HALLAZGO: pricing es TOTAL de estancia, NO desglose nightly	2026-06-09 10:04:34.725769+00
6	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/3-multiroom-prebook.json	multi_room: 2 habitaciones mismo booking -> CONFIRMED, 2 rooms en distribucion	2026-06-09 10:04:34.725769+00
7	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/4-occupancy-prebook.json	multi_occupancy: 2ad+nino8+bebe1 -> CONFIRMED, configuration 1a2|30|30n1|8b1|1 (segmentos a=adulto n=nino b=bebe con edades)	2026-06-09 10:04:34.725769+00
8	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/5-currency-USD.json	currency_switch: pedido EUR->EUR, pedido USD->EUR. HALLAZGO: divisa NO forzable por request, cuenta es single-currency EUR	2026-06-09 10:04:34.725769+00
9	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/6-edge-12months.json	edge_dates: manana (62 hoteles) y +12 meses (3 hoteles) -> ambos HTTP 200 sin error	2026-06-09 10:04:34.725769+00
10	1	3	mock_test	perlahub-dev	pass	pilots/avoris-pull/evidence/mocktests-20260609/7-cancel.json	cancel_flow: reembolsable book CONFIRMED (802886128) -> cancel requirio RETRY (1er intento inmediato dio ERROR_BOOKCENTER_NOT_LODGING_EXCEPTION Booking does not exist), cancelada en reintento, estado final CANCEL, coste 0. NRF detectada (NOREEMBOLSABLE) NO bookeada.	2026-06-09 10:04:34.725769+00
11	1	4	mismatches_classify	factory	pass	pilots/avoris-pull/outputs/mismatches-classified.md	16 mismatches clasificados, 0 precedente cross-conexion (1a Pull, siembra Anexo D). 0 rojos. Grupos: A) 6 ya resueltas/decididas, B) 5 mapeo catalogo PH (P4), C) 5 a confirmar Avoris (no bloqueante). 5 wrappers Core a aplicar (RateKeyBuffer, TimezoneResolver, BackoffExpStrategy, CoreCancelNotFound, PriceChangedTolerance); CurrencyForcer descartado (single-currency). -> HITL #2.	2026-06-09 10:06:40.038118+00
12	1	5	report_compile	factory	pass	pilots/avoris-pull/outputs/informe.md	Informe final Fase 5: score 11/15, veredicto PROCEDER a F6. 0 rojos, 5 wrappers Core existentes, 13 sorpresas (Anexo D). Validacion E2E + 7/7 mock tests en PRO coste 0.	2026-06-09 10:28:10.529762+00
\.


--
-- Data for Name: checklist_responses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.checklist_responses (id, connection_id, section, row_key, row_label, expected, provider_value, classification, evidence_ref, justification, marked_by, marked_at, reviewed_by, reviewed_at) FROM stdin;
1	1	A	op_search	Search	Disponibilidad multi-hotel multi-fecha. ¿batch / per-hotel / per-room?	\N	green	§5.1	[conf:H] expected multi-hotel multi-fecha; Avoris HotelAvailPublicRQ multi-hotel hasta 200 codes + location GEO/ZONE/COMMERCIAL, multi-room por index+passengerAges. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
3	1	A	op_book	Book	Confirma reserva + devuelve locator. ¿sync / async + polling?	\N	green	§5.3	[conf:H] expected confirma+locator sync/async; Avoris /booking SINCRONO -> CONFIRMED/ALREADY_CONFIRMED/ERROR + bookingReferenceID + voucher. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
23	1	G	occupancy_adults	Adultos por habitación	minAdults / maxAdults	\N	green	§5.1/§7	[conf:M] expected min/maxAdults; Avoris passengerAges por room, max 9 pax/room, requiere >=1 adulto (error si no). Modelo de capacidad documentado.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
25	1	G	occupancy_babies	Bebés / cunas	¿se modelan?	\N	green	§5.1.2	[conf:M] expected se modelan bebes; Avoris bebes via edad en passengerAges; configuration ...n0b0 (b=bebes). Si, modelados.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
29	1	I	restrict_allotment	Allotment / cupos	¿open/close/release? Disponibilidad por día	\N	na	§5.1.2	[conf:M] expected open/close/release disponibilidad por dia; gestion de cupo NO aplica a Pull (consumimos avail en vivo, roomQty). NA.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
28	1	I	restrict_stopsale	Stop sale	Por hotel / room / fechas	\N	na	§5.1	[conf:M] expected stop-sale por hotel/room/fechas; en Pull stop-sale = no aparece en avail, no se gestiona. NA.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
30	1	J	static_geo	Geolocalización	Lat/lon + dirección estructurada vs string libre	\N	green	§6/xlsx	[conf:H] expected lat/lon + direccion estructurada; Avoris portfolio: Latitud/Longitud + direccion estructurada completa (calle, CP, ciudad, pais, provincia, cadena). Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
35	1	K	book_async_poll	Async/polling	¿Book sync o async? Si async, endpoint polling + timeout	\N	green	§5.3	[conf:H] expected sync o async + polling; Avoris book SINCRONO (CONFIRMED/ALREADY_CONFIRMED/ERROR inmediato), sin polling. Cumple (sync).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
32	1	K	book_locator	Locator	Formato (numérico/alfanum) + longitud. ¿provider locator vs PerlaHub locator?	\N	green	§4/§5.3	[conf:H] expected formato + provider vs PH locator; Avoris bookingReferenceID (locator provider, alfanum ej 601564057/81233554Q) + requestReferenceID (nuestro). Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
38	1	L	auth_rate_limits	Rate limits	RPS / RPM / burst. Headers de rate limit	\N	yellow	§7	[conf:M] expected RPS/RPM/burst + headers; Avoris HTTP 429 Rate Limiter existe pero sin numeros publicados; exige avisar ante picos. No documentado.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
37	1	L	auth_rotation	Rotación credenciales	¿Rotación periódica? ¿revocación?	\N	yellow	§2.2	[conf:L] expected rotacion/revocacion; Avoris creds TST dadas, PRO tras certificacion; sin politica de rotacion/revocacion documentada. No concluyente.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
39	1	L	op_session_state	Estado de sesión	Stateful (open/close session) vs stateless. Cookies / tokens	\N	green	§4	[conf:H] expected stateful vs stateless; Avoris REST JSON/POST stateless; token=trazabilidad, bookToken porta estado; sin sesion. Cumple (stateless).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
26	1	H	rate_promos	Promociones	PerlaHub NO clasifica promos en el flujo. Los rateIDs (opaca/NRF/etc.) se usan como FILTRO de Distribución a nivel credencial/conexión (p.ej. solicitar solo opacas). ¿Qué rateIDs entrega el provider para poder filtrar?	\N	green	§5.1.2	[conf:M] expected EarlyBooking/NRF/LongStay/Mobile/Member; Avoris rateID PUBLICA/NOREEMBOLSABLE/OPACA/OPACANRF/MAYORES65(NRF). Cubre NRF/opaca/senior; faltan otros; mapear a categorias PH. | [rev:Pedro] PerlaHub NO clasifica promos (el flujo de reserva no las trata). Las OPACAS se gestionan con restricciones de Distribucion a nivel de CREDENCIAL (solicitar solo ese producto); otros rateIDs se reciben como filtro de producto a nivel de conexion. Avoris entrega los rateIDs -> verde, sin mapeo a categorias. [META: el expected (clasificar promos) esta mal planteado vs PH.]	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
36	1	L	auth_method	Método auth	API key / OAuth2 / JWT / Basic / SOAP WS-Security / mTLS	\N	green	§2.2/§3	[conf:H CONFIRMADO en Swagger publico] auth = HTTP Basic (securityScheme {type:http,scheme:basic} en polarisapi.avoristravel.com/{avail,book,staticdata}/v2/api-docs?group=Public; header Authorization). Metodo resuelto. NOTA operativa: las creds net/Test01Net dan 401 Invalid auth en TST -> ver sorpresa (validez de creds, no del metodo).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
31	1	J	static_images	Imágenes	CDN URLs vs IDs. Resolución estándar	\N	green	§6.1	[conf:H CONFIRMADO en Swagger publico staticdata] Image {url (string), order (int), section (string), name (string)} - URLs COMPLETAS (no IDs), una sola resolucion (sin variantes). PerlaHub puede consumir las URLs directamente. Cumple lo que pide PH.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
20	1	E	checkout_time	Check-out time	¿Por hotel? ¿default 11:00?	\N	yellow	§5.1	[conf:H CONFIRMADO ausente en Swagger publico staticdata] Idem checkin_time: /staticdata/v1/hotelInformation no expone checkOutTime. Preguntar a Avoris (Q#9).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
22	1	F	meal_addons	Addons meal plan	Add-ons (almuerzo/cena suplementos) ¿en meal o aparte?	\N	na	§5.1.2	[conf:H CONFIRMADO en Swagger publico avail] No existe concepto de add-on/suplemento de regimen en el spec; meal es unico por distribucion. NA al modelo de Polaris.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
27	1	H	rate_minstay	Minimum stay	Por rate plan / por hotel / global	\N	yellow	§5.1	[conf:H CONFIRMADO en Swagger publico avail] minStay/minimumStay NO existe como campo en avail spec; disponibilidad respeta el limite server-side (devuelve solo combinaciones validas). No consultable explicitamente.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
33	1	K	book_states	Estados de reserva	CONFIRMED / PENDING / FAILED. Mapeo a BookingFlowStatuses PH (BOOKED/CANCELLED/ERROR)	\N	yellow	§5.3/§5.5	[conf:H CONFIRMADO en Swagger publico book] Enum por operacion: PreBooking/Booking = CONFIRMED, ON_REQUEST, CANCEL, ERROR, ALREADY_ERROR, ALREADY_CONFIRMED, ALREADY_BOOK_CONFIRMED. BookingDetail/Cancellation = EMPTY, PRICE_CHANGED, PROVIDER_CHANGED, CONFIRMED, ERROR, ERROR_CREATE_BOOKING, CONFIRMED_CREATE_BOOKING, WARNING, ON_REQUEST, CANCEL, ALREADY_BOOK_CANCEL. Mapeo a BookingFlowStatuses PH (BOOKED/CANCELLED/ERROR/WARNING/ON_REQUEST).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
2	1	A	op_prebook	Prebook / CheckRate	Revalida precio con rateKey antes de book. ¿endpoint separado / mismo Search / skip?	\N	green	§5.2	[conf:H] expected revalida precio antes de book; Avoris /preBooking obligatorio via bookToken, sus valores son los de facturacion. Endpoint separado. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
4	1	A	op_cancel	Cancel	Anula reserva. ¿con locator / con rateKey?	\N	green	§5.5	[conf:H] expected anula con locator/rateKey; Avoris /cancellation por bookingReferenceID -> status CANCEL. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
6	1	A	op_statics	Statics (hotels/rooms/etc.)	Carga catálogos P1. ¿dump completo / incremental / per id?	\N	green	§6	[conf:H] expected carga catalogos dump/incremental/per-id; Avoris Portfolio API: hotels (paginado), hotel_details (per id), cities, categories, mealPlans; update semanal. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
7	1	B	id_hotel_codes	Códigos de hotel	¿Códigos propios provider / GIATA / both? ¿estables en tiempo?	\N	yellow	§6/xlsx	[conf:M] expected codigos propios/GIATA + estables; Avoris codigos propios (Codigo AVO), sin GIATA; portfolio da el mapa. Estabilidad no documentada -> parcial.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
5	1	A	op_getbookings	GetBookings	Consulta histórico/estado. ¿per locator / por rango / batch?	\N	green	§5.4	[conf:M] expected per locator/rango/batch; Avoris bookingDetail por ID (TST+PRO) y bookingDetails por StayDate/CreationDate solo PRO, max 1 mes. Capability cumple; rango solo PRO. | [Swagger book confirmado] Grupo Public solo expone /book/v1/bookingDetail (singular, por bookingReferenceID); bookingDetails (plural por STAYDATE/CREATIONDATE) NO esta en el grupo Public -> confirma PRO-only.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
8	1	B	id_room_codes	Códigos de habitación	PerlaHub es global: NO requiere unicidad por hotel. Importa CÓMO los define el provider (detalle hotel / endpoint) para mapearlos. ¿estables tras edición provider?	\N	yellow	§5.1.2	[conf:H] expected como define el provider los codigos para mapear + estables; Avoris id compuesto (ej H|EXT) + configuration string inline en avail; sin catalogo limpio; estabilidad no documentada. Requiere mapeo. | [rev:Pedro] PREGUNTAR a Avoris la identificacion de rooms: si la cadena configuration codifica caracteristicas (room_amenity) o solo ocupacion.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
9	1	B	id_meal_codes	Códigos de meal plan	¿Códigos de meal del provider (enum / strings libres)? Mapeo necesario contra el catálogo CONFIGURABLE de PerlaHub (BBDD), igual que rooms/hotels (NO enum hardcoded)	\N	yellow	§5.1.2/§6.1	[conf:M] expected enum/strings + mapeo; Avoris meal {id,name} ej SA/AD + catalogo /mealPlans. Enum provider, requiere mapeo a PH. | [rev:Pedro] PerlaHub NO usa enum: catalogo CONFIGURABLE en BBDD; el mapeo se hace contra ese catalogo (igual que rooms/hotels).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
21	1	F	meal_codes_mapping	Mapping meal plan	Códigos provider → catálogo CONFIGURABLE de PerlaHub (BBDD). P4: mapear contra el catálogo real (como rooms/hotels), nunca inventar. NO es un enum hardcoded	\N	yellow	§5.1.2/§6.1	[conf:M] expected strings provider->enum PH (P4); Avoris meal id (SA,AD..) + catalogo /mealPlans. Requiere mapeo a catalogo PH. | [rev:Pedro] PerlaHub NO usa enum: catalogo CONFIGURABLE en BBDD; el mapeo se hace contra ese catalogo (igual que rooms/hotels).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
24	1	G	occupancy_children	Niños y edades	PerlaHub usa EDADES exactas (edad del niño a check-in). Los rangos infant/child/teen son config por conector si el provider los requiere. ¿Provider entrega edad exacta?	\N	green	§5.1	[conf:M] expected ageConfiguration infant/child/teen RANGOS; Avoris edad EXACTA a check-in en passengerAges, NO rangos. PH debe bucketizar -> mapeo. | [rev:Pedro] PerlaHub trabaja con EDADES exactas, NO rangos; los rangos son config por conector cuando hace falta. Avoris da edad exacta a check-in = lo que usa PH -> verde (match). [META: el expected (rangos infant/child/teen) esta mal planteado.]	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
12	1	C	search_pvp_net	PVP vs Net	¿Entrega PVP, neto o ambos? Si PVP, % comisión obligatorio	\N	green	§5.1.2	[conf:H] expected PVP/neto/ambos + comision; Avoris pricing entrega sell(PVP)+net+commission(comAgency,comTaxPercent,comTaxAmount). Cumple ambos.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
11	1	C	search_rate_breakdown	Rate breakdown	PerlaHub: total + precio por room (NO pide precio por noche). Provider puede dar nightly|total → mapear. ¿impuestos incluidos / aparte?	\N	green	§5.1.2	[conf:M] expected total + por room (NO por noche); Avoris pricing por room y por rate (total estancia), sin nightly. Cumple lo que pide PH.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
13	1	C	search_rate_key	rateKey TTL	Identificador de disponibilidad reservable (por room/opción) para prebook; "rateKey" es nombre heredado. Token opaco. ¿TTL declarado? <10min → RateKeyBuffer	\N	green	§4/§7	[conf:H] expected token opaco con TTL, <10min->buffer; Avoris bookToken opaco, TTL declarado=58min. 58>10 -> no dispara buffer. Cumple.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
16	1	D	cancel_policy_format	Formato política cancelación	Canónico PerlaHub: penalización en AMOUNT (importe; convertir % y noches). refundable = flag GENERAL (no por tramo). SIN flag "modificable". Match CoreCancellationPolicy	\N	yellow	§5.1.2	[conf:M] expected penal en AMOUNT, refundable flag GENERAL no por tramo; Avoris cancellationPolicies por tramos from/to con pricing AMOUNT + NRF via rateID + 100% en estancia implicito no via API. Amount OK pero por tramos. | [rev:Pedro] ASEGURAR que el NO-REEMBOLSABLE del provider se refleje en el bloque de politicas (refundable=false en CoreCancellationPolicy), SIN tener que cruzar con el rateID para detectarlo (evitar alimentacion cruzada). El conector mapea rateID NOREEMBOLSABLE -> refundable=false. | [Swagger avail] CancellationPolicyPublic = {from, to, pricing, desc(string)}. El campo "desc" por tramo puede usarse para reflejar NRF (rev:Pedro) sin tener que cruzar con el rateID.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
17	1	D	cancel_timezone	Cancellation timezone	P5: deadlines se guardan en UTC; el conector convierte el offset fijo del provider (p.ej. GMT+1) a UTC. PerlaHub NO usa IANA per-hotel. Provider sin offset claro = revisar	\N	yellow	§2/§5.1.2	[conf:H VERIFICADO EN CODIGO PerlaHub] Deadlines de cancelacion se guardan en UTC (AccomodationBookingCancellationPolicyPenaltyDb.Deadline //UTC; core DateTimeKind.Utc). NO existe IANA/TimeZoneInfo/CET en todo el codigo (0 matches). Conector entrega UTC: TGX hace SpecifyKind(Utc) sin convertir (su provider ya da UTC). Avoris da GMT+1 FIJO -> el conector Avoris debe convertir GMT+1->UTC = -1h fijo (sin DST, sin per-hotel). 🟡 conversion simple en el conector. NOTA: el expected P5 (UTC + IANA per-hotel) esta MAL en la parte IANA -> PerlaHub no usa IANA.	claude/factory-review	2026-05-26 12:02:46.823848+00	\N	\N
15	1	C	search_taxes	Impuestos / fees	¿Incluidos en total / desglosados? Stay taxes vs city taxes	\N	yellow	§5.1.2	[conf:M] expected incluidos/desglosados, stay vs city; Avoris comTax (comision) estructurado, pero city tax/resort fees solo texto libre en observations. Parcial: city/stay tax no estructurado. | [rev:Pedro] DECISION: NO estructurar city tax/resort fees (riesgo de mis-parseo). Pasar las observations (texto libre) tal cual como comentario al cliente. Solo comTax (comision) va estructurado.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
10	1	B	id_amenities	Amenities	¿taxonomía propia / estándar? Cómo se entregan	\N	yellow	§6.1	[conf:H CONFIRMADO en Swagger publico staticdata] HotelAmenity {id, type, name} en HotelDetailsPublic.services. Sin taxonomia/codigos estandar. P4: mapear (id+type) al catalogo de amenities de PerlaHub (BBDD). [rev:Pedro] carga de contenidos, no flujo de reserva.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
19	1	E	checkin_time	Check-in time	¿Por hotel? ¿default 15:00? Late check-in policy	\N	yellow	§5.1/§6.1	[conf:H CONFIRMADO ausente en Swagger publico staticdata] /staticdata/v1/hotelInformation NO expone checkInTime ni similar (campos del hotel: category, address, contact, services, images). Doc silente y spec silente -> preguntar a Avoris (Q#9).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
14	1	C	search_currency	Currency	¿Forzable en request o se entrega como acepte provider?	\N	yellow	§5.1.2	[conf:H CONFIRMADO en Swagger publico avail] market per-request (ISO 3166-1 alpha-2, ej "ES"); currency en la RESPUESTA (ISO-4217, ej "EUR") - no en el request. Sin account-level default en spec -> config-driven a nivel de cuenta (acordar EUR/USD/GBP con Avoris).	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
34	1	K	book_errors	Errores estándar	Catálogo de error codes y mapping a errores PerlaHub	\N	yellow	§7	[conf:H CONFIRMADO en Swagger publico book] Catalogo en enum IntegrationError.type (~20 valores: ERROR_GENERAL_EXCEPTION, ERROR_GENERAL_TIMEOUT_EXCEPTION, ERROR_GENERAL_PROVIDER, ERROR_GENERAL_BOOK_TOKEN_REQUEST, ERROR_GENERAL_OPERATION_BOOK_TOKEN_FINISHED, ERROR_AVAILABILITY_EMPTY_*, ERROR_BRMS_EXCEPTION, ERROR_BOOKCENTER_*, ERROR_HOTEL_INFORMATION_EXCEPTION, varios WARNING_*). Estructura: AdviceIntegration.err[].{type,desc}. Mapeo claro a errores PH.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
18	1	D	cancel_partial	Cancelación parcial	¿Soporta room-level / solo booking completo?	\N	green	§5.5	[conf:M] expected room-level o solo completo; Avoris cancela la reserva completa (por bookingReferenceID), sin room-level (§5.5). [rev:Pedro] Alineado con PerlaHub (PH no requiere cancelacion por habitacion) -> verde. Sin framing de gap. | [Swagger book confirmado] cancellation solo acepta bookingReference (BookingReferencePublic) + token + clientCode. NO hay roomIndex ni parametros room-level.	claude/factory-pull	2026-05-26 11:36:19.163332+00	\N	\N
\.


--
-- Data for Name: checklist_template_pull; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.checklist_template_pull (section, row_key, row_label, expected) FROM stdin;
A	op_search	Search	Disponibilidad multi-hotel multi-fecha. ¿batch / per-hotel / per-room?
A	op_prebook	Prebook / CheckRate	Revalida precio con rateKey antes de book. ¿endpoint separado / mismo Search / skip?
A	op_book	Book	Confirma reserva + devuelve locator. ¿sync / async + polling?
A	op_cancel	Cancel	Anula reserva. ¿con locator / con rateKey?
A	op_getbookings	GetBookings	Consulta histórico/estado. ¿per locator / por rango / batch?
A	op_statics	Statics (hotels/rooms/etc.)	Carga catálogos P1. ¿dump completo / incremental / per id?
B	id_hotel_codes	Códigos de hotel	¿Códigos propios provider / GIATA / both? ¿estables en tiempo?
B	id_room_codes	Códigos de habitación	PerlaHub es global: NO requiere unicidad por hotel. Importa CÓMO los define el provider (detalle hotel / endpoint) para mapearlos. ¿estables tras edición provider?
B	id_amenities	Amenities	¿taxonomía propia / estándar? Cómo se entregan
C	search_rate_breakdown	Rate breakdown	PerlaHub: total + precio por room (NO pide precio por noche). Provider puede dar nightly|total → mapear. ¿impuestos incluidos / aparte?
C	search_pvp_net	PVP vs Net	¿Entrega PVP, neto o ambos? Si PVP, % comisión obligatorio
C	search_rate_key	rateKey TTL	Identificador de disponibilidad reservable (por room/opción) para prebook; "rateKey" es nombre heredado. Token opaco. ¿TTL declarado? <10min → RateKeyBuffer
C	search_currency	Currency	¿Forzable en request o se entrega como acepte provider?
C	search_taxes	Impuestos / fees	¿Incluidos en total / desglosados? Stay taxes vs city taxes
D	cancel_policy_format	Formato política cancelación	Canónico PerlaHub: penalización en AMOUNT (importe; convertir % y noches). refundable = flag GENERAL (no por tramo). SIN flag "modificable". Match CoreCancellationPolicy
D	cancel_partial	Cancelación parcial	¿Soporta room-level / solo booking completo?
E	checkin_time	Check-in time	¿Por hotel? ¿default 15:00? Late check-in policy
E	checkout_time	Check-out time	¿Por hotel? ¿default 11:00?
F	meal_addons	Addons meal plan	Add-ons (almuerzo/cena suplementos) ¿en meal o aparte?
G	occupancy_adults	Adultos por habitación	minAdults / maxAdults
G	occupancy_babies	Bebés / cunas	¿se modelan?
H	rate_minstay	Minimum stay	Por rate plan / por hotel / global
I	restrict_stopsale	Stop sale	Por hotel / room / fechas
I	restrict_allotment	Allotment / cupos	¿open/close/release? Disponibilidad por día
J	static_geo	Geolocalización	Lat/lon + dirección estructurada vs string libre
J	static_images	Imágenes	CDN URLs vs IDs. Resolución estándar
K	book_locator	Locator	Formato (numérico/alfanum) + longitud. ¿provider locator vs PerlaHub locator?
K	book_states	Estados de reserva	CONFIRMED / PENDING / FAILED. Mapeo a BookingFlowStatuses PH (BOOKED/CANCELLED/ERROR)
K	book_errors	Errores estándar	Catálogo de error codes y mapping a errores PerlaHub
K	book_async_poll	Async/polling	¿Book sync o async? Si async, endpoint polling + timeout
L	auth_method	Método auth	API key / OAuth2 / JWT / Basic / SOAP WS-Security / mTLS
L	auth_rotation	Rotación credenciales	¿Rotación periódica? ¿revocación?
L	auth_rate_limits	Rate limits	RPS / RPM / burst. Headers de rate limit
L	op_session_state	Estado de sesión	Stateful (open/close session) vs stateless. Cookies / tokens
D	cancel_timezone	Cancellation timezone	P5: deadlines se guardan en UTC; el conector convierte el offset fijo del provider (p.ej. GMT+1) a UTC. PerlaHub NO usa IANA per-hotel. Provider sin offset claro = revisar
B	id_meal_codes	Códigos de meal plan	¿Códigos de meal del provider (enum / strings libres)? Mapeo necesario contra el catálogo CONFIGURABLE de PerlaHub (BBDD), igual que rooms/hotels (NO enum hardcoded)
F	meal_codes_mapping	Mapping meal plan	Códigos provider → catálogo CONFIGURABLE de PerlaHub (BBDD). P4: mapear contra el catálogo real (como rooms/hotels), nunca inventar. NO es un enum hardcoded
G	occupancy_children	Niños y edades	PerlaHub usa EDADES exactas (edad del niño a check-in). Los rangos infant/child/teen son config por conector si el provider los requiere. ¿Provider entrega edad exacta?
H	rate_promos	Promociones	PerlaHub NO clasifica promos en el flujo. Los rateIDs (opaca/NRF/etc.) se usan como FILTRO de Distribución a nivel credencial/conexión (p.ej. solicitar solo opacas). ¿Qué rateIDs entrega el provider para poder filtrar?
\.


--
-- Data for Name: connections; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.connections (id, slug, display_name, factory, mode, is_pilot, current_phase, status, owner_hitl, dev_status, prod_status, dev_commit, prod_commit, dev_pr_url, prod_pr_url, intake_doc_url, intake_sandbox_ok, intake_contact_name, intake_contact_email, intake_volume_notes, score_initial, score_real, contact_name, contact_email, jira_epic_url, notes, created_at, updated_at) FROM stdin;
1	avoris-pull	Avoris (Polaris) — Pull nativo	pull	\N	t	5	active	Pedro	not_deployed	not_deployed	\N	\N	\N	\N	https://developers.avoris.com/polaris	t	Vanesa	vanesa@avoris.example	150 hoteles · 2 clientes · 50 htls/request · frecuencia diaria	\N	11	Vanesa	vanesa@avoris.example	\N	Piloto Pull v0. Intake aprobado en ensayo (sandbox asumido OK). Kickoff 13-abr · calibra la línea.	2026-05-26 08:58:02.094829+00	2026-06-09 10:28:10.526543+00
\.


--
-- Data for Name: hitl_gates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hitl_gates (id, connection_id, gate_number, gate_title, status, approver, decided_at, evidence_url, notes) FROM stdin;
3	1	3	Aprobar PR código (Fase 6)	pending	\N	\N	\N	\N
4	1	4	Go-live PROD (Fase 8)	pending	\N	\N	\N	\N
1	1	1	Revisión análisis (Fase 1)	approved	Pedro	2026-05-26 14:17:25.752504+00	\N	Revision Fase 1 COMPLETA (factory-review). Tally 18 verde / 19 amarillo / 0 rojo / 2 na. G1: rate_promos+occupancy_children->verde (PH no clasifica promos / usa edades exactas); meal=catalogo BBDD; amenities=contenidos; room=preguntar config. G2: cancel_partial->verde (alineado PH); cancel_policy NRF en bloque (sin cross-feeding); timezone GMT+1->UTC -1h; taxes=pasar observations. G3 (9) a verificar en sandbox/Swagger + 15 preguntas a Avoris (outputs/preguntas-avoris.md). Canonico corregido (P5 timezone + rate_promos/occupancy_children/meal). Procede a Fase 2.
2	1	2	Aprobar mismatches y wrappers (Fase 4)	approved	Pedro	2026-06-09 10:26:57.532492+00	\N	Mismatches Fase 4 aprobados: 16 (0 rojos), todas con ruta clara. 5 wrappers Core confirmados (RateKeyBuffer, TimezoneResolver, BackoffExpStrategy, CoreCancelNotFound, PriceChangedTolerance); CurrencyForcer descartado (single-currency EUR). Decisiones Pedro ratificadas (NRF en bloque, taxes=observations). Procede a Fase 5 informe.
\.


--
-- Data for Name: metrics; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.metrics (id, connection_id, target_env, metric_date, metric_name, value, source) FROM stdin;
\.


--
-- Data for Name: phase_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.phase_log (id, connection_id, from_phase, to_phase, actor, notes, occurred_at) FROM stdin;
1	1	0	1	claude/factory-new	Intake OK · 4 criterios cumplen (ensayo)	2026-05-26 08:58:02.094829+00
2	1	1	2	Pedro/factory-review	HITL #1 (revision analisis) aprobado -> avanza a Fase 2 (sandbox)	2026-05-26 14:17:25.752504+00
3	1	2	3	claude/factory-pull	Sandbox Fase 2 PASS (flujo E2E 6/6 en PRO, reserva 802885266 creada+cancelada coste 0). Avanza a Fase 3 Mock Tests.	2026-06-09 08:24:51.49231+00
4	1	3	4	claude/factory-pull	Mock Tests Fase 3: 7/7 PASS en PRO (coste 0). Hallazgos: pricing total no-nightly, single-currency EUR, cancel necesita retry. Avanza a Fase 4 Mismatches.	2026-06-09 10:05:19.565863+00
5	1	4	5	claude/factory-pull	HITL #2 aprobado (Pedro). Avanza a Fase 5 informe final.	2026-06-09 10:26:57.53635+00
\.


--
-- Data for Name: surprises; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.surprises (id, connection_id, title, description, catalog_anexo, related_row_key, resolved, detected_at, resolved_at, resolution_notes) FROM stdin;
9	1	Penalidad 100% en estancia NO viene via API	Cualquier cancelacion entre check-in y check-out aplica 100% penalidad, pero NO aparece en cancellationPolicies; la doc lo dice en texto. Hay que asumirlo en el wrapper de politicas.	D	cancel_policy_format	f	2026-05-26 11:36:44.704379+00	\N	\N
10	1	Parity estricta Prebook->Book (sin tolerancia book-side)	Cualquier diff de precio/politica entre Prebook y Book devuelve ERROR_GENERAL_PROVIDER. Cambios solo permitidos Avail->Prebook. No hay tolerancia en el paso Book.	D	op_prebook	f	2026-05-26 11:36:44.704379+00	\N	\N
12	1	bookingDetails por fecha es PRO-only (no testeable en TST)	Busqueda por STAYDATE/CREATIONDATE solo en PRO, no en sandbox TST. En TST solo bookingDetail por bookingReferenceID. Validar GetBookings por fecha queda para PRO.	D	op_getbookings	f	2026-05-26 11:36:44.704379+00	\N	\N
18	1	Cancel inmediato tras Book falla: "Booking does not exist" (latencia propagacion)	Tras un Book CONFIRMED, cancelar de inmediato devuelve ERROR_BOOKCENTER_NOT_LODGING_EXCEPTION "Booking does not exist" - la reserva confirma pero tarda en propagarse al subsistema de cancelacion (eventual consistency). Reintentando ~3-6s despues, cancela OK (status CANCEL). Confirmado en vivo PRO 2026-06-09 con reserva 802886128. IMPLICACION conector: el wrapper de Cancel necesita retry con backoff (BackoffExpStrategy) ante NOT_LODGING tras un book reciente, y tratar ALREADY_BOOK_CANCEL/CANCEL como exito idempotente.	D	op_cancel	f	2026-06-09 10:04:49.977916+00	\N	\N
19	1	Cuenta Perlatours es single-currency EUR (divisa NO forzable por request)	El campo currency en searchAvail NO fuerza la divisa: pedido USD devuelve igualmente EUR. La cuenta 4144001 esta configurada single-currency EUR. El doc decia "depende de config (single/multi-currency)" -> confirmado single. IMPLICACION: CurrencyForcer NO aplica para esta cuenta; PerlaHub recibe siempre EUR. Si se necesita multi-currency, pedir a Avoris reconfig de cuenta.	D	search_currency	f	2026-06-09 10:04:49.977916+00	\N	\N
14	1	Swagger/OpenAPI de Polaris es PUBLICO (resuelve acceso a doc)	Los specs OpenAPI estan accesibles sin auth en polarisapi.avoristravel.com/avail|book|staticdata/v2/api-docs?group=Public (y el UI en swagger-ui-polaris.barceloviajes.com/polaris). Resuelve Q#1 (no hace falta invitacion) y permite resolver varias G3 (amenities, imagenes, rate types) leyendo el spec staticdata/book.	D	auth_method	f	2026-05-26 15:21:00.343744+00	\N	\N
11	1	City tax / resort fees solo en observations (texto libre)	comTax (comision) estructurado, pero city tax y resort fees solo como texto libre en observations. Requiere parseo; riesgo de no capturarlos de forma fiable. [DECISION rev:Pedro: NO parsear city tax/resort fees a campos; pasar observations tal cual como comentario.]	D	search_taxes	f	2026-05-26 11:36:44.704379+00	\N	\N
7	1	Timezone deadlines: PerlaHub guarda UTC (no IANA); Avoris GMT+1 -> conector resta 1h	VERIFICADO EN CODIGO: PerlaHub guarda deadlines en UTC (DB model //UTC; DateTimeKind.Utc) y NO usa IANA/TimeZoneInfo/CET. El conector entrega UTC (TGX hace SpecifyKind(Utc) porque su provider ya da UTC). Avoris opera en GMT+1 fijo -> el conector Avoris debe convertir GMT+1->UTC (-1h fijo). CORREGIDO en el canonico (P5 + plantilla + docs, 2026-05-26): el expected ya no dice UTC+IANA per-hotel.	D	cancel_timezone	f	2026-05-26 11:36:44.704379+00	\N	\N
13	1	Auth = HTTP Basic (Swagger publico), pero creds net/Test01Net dan 401 Invalid auth	Encontrado el Swagger PUBLICO (polarisapi.avoristravel.com/{avail,book,staticdata}/v2/api-docs?group=Public): el auth es HTTP Basic (header Authorization). Enviado Basic correcto con net/Test01Net -> 401 "Invalid auth" en TST, tanto en /avail/availability como en /avail/v1/availability. CONCLUSION: el metodo es correcto (Basic); el blocker es la VALIDEZ de las credenciales -> pedir a Avoris confirmar/activar/reemitir creds TST. HALLAZGO extra: las rutas reales llevan /v1/ (el PDF las lista sin /v1/).	D	auth_method	t	2026-05-26 14:26:01.094733+00	2026-06-04 12:40:58.778654+00	Resuelto con las claves de la hoja Perlatours: las credenciales PRO de Perlatours (ver pilots/avoris-pull/inputs/03-credentials.local.env, git-ignored) son las creds PRO y funcionan con HTTP Basic (avail 200, statics 200, prebook CONFIRMED). Las net/Test01Net de la cert doc siguen muertas en TST (401 en ambas rutas). Pendiente: pedir a Avoris creds TST validas para la certificacion formal.
15	1	Estados de reserva mas amplios que el PDF (ON_REQUEST, PRICE_CHANGED, PROVIDER_CHANGED, WARNING)	El Swagger public revela mas estados que los 4 del PDF (CONFIRMED/ALREADY_CONFIRMED/ERROR/CANCEL). PreBooking/Booking incluyen ON_REQUEST. BookingDetail/Cancellation incluyen ademas EMPTY, PRICE_CHANGED, PROVIDER_CHANGED, WARNING, ALREADY_BOOK_CANCEL. Implicacion: PH debe manejar (a) flujo on-request (no instant-confirm), (b) reconciliacion price-changed/provider-changed entre prebook/book/detail.	D	book_states	f	2026-06-03 17:03:49.635609+00	\N	\N
8	1	bookToken TTL = 58 min (Prebook->Book)	El bookToken caduca a 58 min entre Prebook y Book (error Booktoken expired -> nueva search). Primer TTL medido en la planta Pull; muy por encima del umbral RateKeyBuffer (<10min). || CONFIRMADO EN VIVO (PRO 2026-06-04): la respuesta del prebook expone el campo ttl explicito = 3360s (56 min). RateKeyBuffer puede leer el TTL dinamicamente del RS en vez de hardcodear 58min.	D	search_rate_key	f	2026-05-26 11:36:44.704379+00	\N	\N
16	1	travellers[].index = indice de HABITACION, no de pasajero	En BookRQ, index de cada traveller identifica la HABITACION (los N pax de una habitacion comparten index), NO es indice secuencial por pasajero. Para [30,30] ambos adultos van con index=1. Poner 1 y 2 da ERROR_GENERAL_ERROR_REQUEST "Traveller ages mismatch". Confirmado en vivo PRO 2026-06-09.	D	occupancy_adults	f	2026-06-09 08:12:05.594581+00	\N	\N
17	1	Voucher trae empresa facturadora (issuingBrand) variable	BookRS devuelve voucher.payable + voucher.issuingBrand con la empresa del grupo Avoris que factura. Observado: "Alisios Tours, S.L." / 052035 (catalogo PDF: 052035=Alisios, 166030=Planet, 164020=Orbe, 047036=Travelsens). PerlaHub debe leer/conservar issuingBrand por reserva.	D	book_locator	f	2026-06-09 08:12:05.597659+00	\N	\N
\.


--
-- Data for Name: work_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.work_log (id, ts, actor, role, event_type, connection_slug, detail) FROM stdin;
1	2026-06-09 10:00:50.182075+00	Santi	developer	prompt	avoris-pull	incia los mocktest ahora Factory Perlatours · Planta de conexiones Piso de planta Aprendizaje  en vivo 3 HITL gates pendientes(0 >2 días esp
2	2026-06-09 10:00:56.634064+00	Santi	executor	skill	avoris-pull	factory-mocktests run avoris-pull --env perlahub-dev
3	2026-06-09 10:05:24.067841+00	Santi	executor	skill	avoris-pull	factory-mismatches classify avoris-pull
4	2026-06-09 10:26:31.132216+00	Santi	developer	prompt	\N	sigue con la sigueinte fase
5	2026-06-09 10:33:10.310828+00	Santi	developer	prompt	\N	vamos con fase 5
6	2026-06-09 10:55:45.630763+00	Santi	developer	prompt	\N	monta todo en Factory factory-424324      Select EIP 101.46.140.159      para que luego pedro sigue, has commit push y asi le paso a pedro. 
\.


--
-- Name: actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.actions_id_seq', 12, true);


--
-- Name: checklist_responses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.checklist_responses_id_seq', 39, true);


--
-- Name: connections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.connections_id_seq', 1, true);


--
-- Name: hitl_gates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hitl_gates_id_seq', 4, true);


--
-- Name: metrics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.metrics_id_seq', 1, false);


--
-- Name: phase_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.phase_log_id_seq', 5, true);


--
-- Name: surprises_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.surprises_id_seq', 19, true);


--
-- Name: work_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.work_log_id_seq', 6, true);


--
-- Name: actions actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: checklist_responses checklist_responses_connection_id_row_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_responses
    ADD CONSTRAINT checklist_responses_connection_id_row_key_key UNIQUE (connection_id, row_key);


--
-- Name: checklist_responses checklist_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_responses
    ADD CONSTRAINT checklist_responses_pkey PRIMARY KEY (id);


--
-- Name: checklist_template_pull checklist_template_pull_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_template_pull
    ADD CONSTRAINT checklist_template_pull_pkey PRIMARY KEY (section, row_key);


--
-- Name: connections connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (id);


--
-- Name: connections connections_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_slug_key UNIQUE (slug);


--
-- Name: hitl_gates hitl_gates_connection_id_gate_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hitl_gates
    ADD CONSTRAINT hitl_gates_connection_id_gate_number_key UNIQUE (connection_id, gate_number);


--
-- Name: hitl_gates hitl_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hitl_gates
    ADD CONSTRAINT hitl_gates_pkey PRIMARY KEY (id);


--
-- Name: metrics metrics_connection_id_target_env_metric_date_metric_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT metrics_connection_id_target_env_metric_date_metric_name_key UNIQUE (connection_id, target_env, metric_date, metric_name);


--
-- Name: metrics metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT metrics_pkey PRIMARY KEY (id);


--
-- Name: phase_log phase_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phase_log
    ADD CONSTRAINT phase_log_pkey PRIMARY KEY (id);


--
-- Name: surprises surprises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprises
    ADD CONSTRAINT surprises_pkey PRIMARY KEY (id);


--
-- Name: work_log work_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_log
    ADD CONSTRAINT work_log_pkey PRIMARY KEY (id);


--
-- Name: actions_conn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX actions_conn_idx ON public.actions USING btree (connection_id, occurred_at DESC);


--
-- Name: actions_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX actions_type_idx ON public.actions USING btree (action_type);


--
-- Name: checklist_cross_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_cross_idx ON public.checklist_responses USING btree (row_key, classification);


--
-- Name: connections_factory_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX connections_factory_idx ON public.connections USING btree (factory);


--
-- Name: connections_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX connections_status_idx ON public.connections USING btree (status);


--
-- Name: hitl_gates_pending_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hitl_gates_pending_idx ON public.hitl_gates USING btree (status) WHERE (status = 'pending'::text);


--
-- Name: metrics_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX metrics_name_idx ON public.metrics USING btree (metric_name, metric_date DESC);


--
-- Name: phase_log_conn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phase_log_conn_idx ON public.phase_log USING btree (connection_id, occurred_at DESC);


--
-- Name: surprises_open_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX surprises_open_idx ON public.surprises USING btree (connection_id) WHERE (NOT resolved);


--
-- Name: work_log_ts_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX work_log_ts_idx ON public.work_log USING btree (ts);


--
-- Name: connections connections_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER connections_updated_at BEFORE UPDATE ON public.connections FOR EACH ROW EXECUTE FUNCTION public.trg_updated_at();


--
-- Name: actions actions_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actions
    ADD CONSTRAINT actions_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- Name: checklist_responses checklist_responses_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_responses
    ADD CONSTRAINT checklist_responses_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- Name: hitl_gates hitl_gates_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hitl_gates
    ADD CONSTRAINT hitl_gates_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- Name: metrics metrics_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT metrics_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- Name: phase_log phase_log_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phase_log
    ADD CONSTRAINT phase_log_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- Name: surprises surprises_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprises
    ADD CONSTRAINT surprises_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.connections(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict mkhOgCoHYBGVBxhjmthELeti7zlfRdeEWYFl9mRwFl2U9ejT6ThxbzwIaiBYsao

