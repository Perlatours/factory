"""
Factory · Panel de control de la planta
========================================
NO es BI. Es la pantalla operativa del piso de planta.
"¿dónde está cada coche? ¿qué HITL bloquea? ¿qué estación espera input?"

Lanzar: cd dashboard && streamlit run app.py
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timezone

st.set_page_config(
    page_title="Factory · Panel de control",
    page_icon="🏭",
    layout="wide",
)

# ---------------------------------------------------------------------
# Conexión (st.connection cachea bajo el capó con cache_resource)
# ---------------------------------------------------------------------
conn = st.connection("factory", type="sql")

TTL = "60s"  # más corto que los 10min del plan inicial — operativo, no BI

def q(sql: str, **kwargs) -> pd.DataFrame:
    return conn.query(sql, ttl=TTL, **kwargs)

# ---------------------------------------------------------------------
# Header + refresh
# ---------------------------------------------------------------------
col_t, col_r = st.columns([4, 1])
with col_t:
    st.title("🏭 Factory · Panel de control")
    st.caption(
        "Planta autónoma de fabricación de conexiones · "
        f"snapshot: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}"
    )
with col_r:
    if st.button("↻ Refresh", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

# ---------------------------------------------------------------------
# Banner HITLs pendientes (rojo, arriba)
# ---------------------------------------------------------------------
hitls = q("""
    SELECT c.slug, c.factory, h.gate_number, h.gate_title,
           COALESCE(c.owner_hitl,'—') AS owner,
           EXTRACT(EPOCH FROM (NOW() - c.updated_at))/86400.0 AS days_waiting
    FROM hitl_gates h
    JOIN connections c ON c.id = h.connection_id
    WHERE h.status = 'pending'
      AND c.status IN ('active','awaiting_intake')
    ORDER BY c.updated_at;
""")

if not hitls.empty:
    n = len(hitls)
    overdue = hitls[hitls["days_waiting"] > 2]
    severity = "🔴" if not overdue.empty else "🟡"
    st.error(
        f"{severity} **{n} HITL gates pendientes** "
        f"({len(overdue)} >2 días esperando)"
    )
    with st.expander("Ver pendientes", expanded=len(overdue) > 0):
        hitls_view = hitls.copy()
        hitls_view["days_waiting"] = hitls_view["days_waiting"].round(1)
        st.dataframe(hitls_view, use_container_width=True, hide_index=True)
else:
    st.success("✅ Sin HITL gates pendientes")

# ---------------------------------------------------------------------
# Pantallas (orden operativo)
# ---------------------------------------------------------------------
tab1, tab2, tab3, tab4 = st.tabs([
    "🏭 Piso de planta",
    "🔍 Por conexión",
    "📚 Aprendizaje cross-conexión",
    "📊 Métricas",
])

# =====================================================================
# Pantalla 1 — Piso de planta (kanban por fase)
# =====================================================================
with tab1:
    st.subheader("Kanban operativo · ¿dónde está cada coche?")

    # Filtros
    fcol1, fcol2, fcol3 = st.columns(3)
    with fcol1:
        f_factory = st.multiselect(
            "Factory",
            ["pull", "push", "espejo", "pushout"],
            default=["pull"],  # v0: Pull only
        )
    with fcol2:
        f_status = st.multiselect(
            "Status",
            ["active", "awaiting_intake", "dormant", "done", "rejected_intake"],
            default=["active", "awaiting_intake"],
        )
    with fcol3:
        show_gap = st.checkbox("Solo gap DEV/PROD", value=False)

    where = []
    if f_factory:
        where.append(f"factory IN ({','.join([repr(x) for x in f_factory])})")
    if f_status:
        where.append(f"status IN ({','.join([repr(x) for x in f_status])})")
    if show_gap:
        where.append("(dev_status='deployed' AND prod_status!='deployed')")
    where_sql = "WHERE " + " AND ".join(where) if where else ""

    conns = q(f"""
        SELECT slug, display_name, factory, COALESCE(mode,'—') AS mode,
               current_phase, status, dev_status, prod_status,
               COALESCE(owner_hitl,'—') AS owner,
               COALESCE(contact_name,'—') AS contact,
               COALESCE((SELECT string_agg('#'||gate_number,',' ORDER BY gate_number)
                         FROM hitl_gates h
                         WHERE h.connection_id = c.id AND h.status='pending'),'—') AS hitls_pend
        FROM connections c
        {where_sql}
        ORDER BY current_phase DESC, slug;
    """)

    # Kanban por fase
    if conns.empty:
        st.info("Sin conexiones con los filtros actuales.")
    else:
        phases = sorted(conns["current_phase"].unique())
        cols = st.columns(max(len(phases), 1))
        for col, phase in zip(cols, phases):
            with col:
                st.markdown(f"### Fase {phase}")
                phase_conns = conns[conns["current_phase"] == phase]
                for _, row in phase_conns.iterrows():
                    badge = {
                        "active": "🟢",
                        "awaiting_intake": "🟡",
                        "dormant": "💤",
                        "done": "✅",
                        "rejected_intake": "🚫",
                    }.get(row["status"], "⚪")
                    st.markdown(
                        f"**{badge} {row['slug']}**  \n"
                        f"_{row['display_name']}_  \n"
                        f"Modo: {row['mode']} · HITL: {row['hitls_pend']}  \n"
                        f"Owner: {row['owner']}"
                    )
                    st.divider()

# =====================================================================
# Pantalla 2 — Por conexión (drill-down)
# =====================================================================
with tab2:
    all_slugs = q("SELECT slug FROM connections ORDER BY slug;")["slug"].tolist()
    if not all_slugs:
        st.info("No hay conexiones registradas.")
    else:
        slug = st.selectbox("Conexión", all_slugs)

        c = q(
            "SELECT * FROM connections WHERE slug = :slug;",
            params={"slug": slug},
        ).iloc[0]

        col_a, col_b, col_c = st.columns(3)
        col_a.metric("Fase", c["current_phase"])
        col_b.metric("Status", c["status"])
        col_c.metric("DEV / PROD", f"{c['dev_status']} / {c['prod_status']}")

        st.markdown(f"**{c['display_name']}** · _{c['factory']}_ · Contacto: {c['contact_name'] or '—'}")
        if c["notes"]:
            st.info(c["notes"])

        # HITL gates
        st.subheader("HITL Gates")
        gates = q(
            """SELECT gate_number, gate_title, status, approver, decided_at, notes
               FROM hitl_gates
               WHERE connection_id = (SELECT id FROM connections WHERE slug = :slug)
               ORDER BY gate_number;""",
            params={"slug": slug},
        )
        st.dataframe(gates, use_container_width=True, hide_index=True)

        # Phase log
        st.subheader("Phase log (últimas 10)")
        plog = q(
            """SELECT from_phase, to_phase, actor, occurred_at, notes
               FROM phase_log
               WHERE connection_id = (SELECT id FROM connections WHERE slug = :slug)
               ORDER BY occurred_at DESC LIMIT 10;""",
            params={"slug": slug},
        )
        st.dataframe(plog, use_container_width=True, hide_index=True)

        # Checklist resumen
        st.subheader("Checklist")
        cl = q(
            """SELECT section,
                      COUNT(*) AS total,
                      COUNT(*) FILTER (WHERE classification IS NULL) AS pending,
                      COUNT(*) FILTER (WHERE classification='green')  AS green,
                      COUNT(*) FILTER (WHERE classification='yellow') AS yellow,
                      COUNT(*) FILTER (WHERE classification='red')    AS red,
                      COUNT(*) FILTER (WHERE classification='na')     AS na
               FROM checklist_responses
               WHERE connection_id = (SELECT id FROM connections WHERE slug = :slug)
               GROUP BY section ORDER BY section;""",
            params={"slug": slug},
        )
        if cl.empty:
            st.caption("Sin filas de checklist clonadas (¿conexión Push, sin template v0? ¿rechazada en Intake?)")
        else:
            st.dataframe(cl, use_container_width=True, hide_index=True)

        # Sorpresas abiertas
        st.subheader("Sorpresas abiertas")
        surp = q(
            """SELECT id, title, description, catalog_anexo, detected_at
               FROM surprises
               WHERE connection_id = (SELECT id FROM connections WHERE slug = :slug)
                 AND NOT resolved
               ORDER BY detected_at DESC;""",
            params={"slug": slug},
        )
        if surp.empty:
            st.caption("Sin sorpresas abiertas.")
        else:
            st.dataframe(surp, use_container_width=True, hide_index=True)

# =====================================================================
# Pantalla 3 — Aprendizaje cross-conexión
# =====================================================================
with tab3:
    st.subheader("Filas con mayor tasa 🔴 cross-conexión")
    st.caption("Estas filas son las que casi siempre fallan — candidatas a wrapper Core.")

    top_red = q("""
        SELECT row_key, row_label,
               COUNT(*) AS total_marked,
               COUNT(*) FILTER (WHERE classification='red')    AS reds,
               COUNT(*) FILTER (WHERE classification='yellow') AS yellows,
               COUNT(*) FILTER (WHERE classification='green')  AS greens,
               ROUND(100.0 * COUNT(*) FILTER (WHERE classification='red') / NULLIF(COUNT(*),0), 1) AS pct_red
        FROM checklist_responses
        WHERE classification IS NOT NULL
        GROUP BY row_key, row_label
        HAVING COUNT(*) >= 1
        ORDER BY pct_red DESC NULLS LAST, total_marked DESC
        LIMIT 20;
    """)
    if top_red.empty:
        st.info("Aún no hay datos cross-conexión. Esta pantalla crece tras los primeros cierres.")
    else:
        st.dataframe(top_red, use_container_width=True, hide_index=True)

    st.divider()
    st.subheader("Sorpresas resueltas (insumo del Anexo D)")
    resolved = q("""
        SELECT s.title, s.catalog_anexo, c.slug, s.resolution_notes, s.resolved_at
        FROM surprises s JOIN connections c ON c.id = s.connection_id
        WHERE s.resolved
        ORDER BY s.resolved_at DESC
        LIMIT 30;
    """)
    if resolved.empty:
        st.caption("Sin sorpresas resueltas todavía.")
    else:
        st.dataframe(resolved, use_container_width=True, hide_index=True)

# =====================================================================
# Pantalla 4 — Métricas (vacía hasta tener datos)
# =====================================================================
with tab4:
    st.subheader("Métricas por conexión y entorno")
    st.caption("Usar SOLO con datos reales (≥5 conexiones cerradas). Antes está vacía y eso está bien.")

    m = q("""
        SELECT c.slug, m.target_env, m.metric_date, m.metric_name, m.value, m.source
        FROM metrics m JOIN connections c ON c.id = m.connection_id
        ORDER BY m.metric_date DESC, c.slug;
    """)
    if m.empty:
        st.info("Sin métricas registradas. Usa `/factory-metric <slug> --env ... --name booking_error_rate --value 0.024`")
    else:
        st.dataframe(m, use_container_width=True, hide_index=True)

# ---------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------
st.divider()
st.caption(
    "📖 Documentación: `PLAN.md` · `docs/factory_pull/` (briefing + checklist + plant diagram)  \n"
    "🛠️ Comandos: `bash scripts/dump-registry.sh` · skills en `.claude/skills/`"
)
