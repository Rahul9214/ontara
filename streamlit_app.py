"""Ontara — Governed Supply Chain Intelligence."""

import streamlit as st

from ontara_app.components import (
    inject_css,
    render_brand,
)
from ontara_app.views import (
    render_action_center,
    render_ask_ontara,
    render_blast_radius,
    render_contract_verifier,
    render_governance,
    render_overview,
)

st.set_page_config(
    page_title="Ontara · Governed Supply Chain Intelligence",
    page_icon="◈",
    layout="wide",
    initial_sidebar_state="expanded",
)

inject_css()
render_brand()

with st.sidebar:
    st.markdown("### Ontara")
    st.caption("Governed Supply Chain Intelligence")

    page = st.radio(
        "Navigate",
        [
            "Executive Overview",
            "Ask Ontara",
            "Semantic Contract Verifier",
            "Ontology Blast Radius",
            "Governed Action Center",
            "Trust & Governance",
        ],
        label_visibility="collapsed",
    )

    st.divider()

    st.caption("Snowflake-native")
    st.caption("Semantic Contract v1.0.0")
    st.caption("Human-in-the-loop actions")

if page == "Executive Overview":
    render_overview()
elif page == "Ask Ontara":
    render_ask_ontara()
elif page == "Semantic Contract Verifier":
    render_contract_verifier()
elif page == "Ontology Blast Radius":
    render_blast_radius()
elif page == "Governed Action Center":
    render_action_center()
else:
    render_governance()