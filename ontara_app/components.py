"""Reusable visual components for Ontara."""

import streamlit as st

from ontara_app.config import (
    APP_CSS,
    APP_SUBTITLE,
    APP_TITLE,
    TAGLINE,
)


def inject_css() -> None:
    st.markdown(
        APP_CSS,
        unsafe_allow_html=True,
    )


def render_brand() -> None:
    st.markdown(
        f"""
<div class="ontara-brand">
    <div class="ontara-kicker">
        {APP_SUBTITLE}
    </div>
    <div class="ontara-title">
        {APP_TITLE}
    </div>
    <div class="ontara-subtitle">
        {TAGLINE}
    </div>
</div>
""",
        unsafe_allow_html=True,
    )

    st.markdown(
        """
<div class="trust-strip">
    <strong>Governed by Snowflake semantic truth.</strong>
    Metrics, impact analysis, and operational actions resolve
    from governed Snowflake objects rather than client-supplied
    business values.
</div>
""",
        unsafe_allow_html=True,
    )


def section_title(
    title: str,
    description: str,
) -> None:
    st.subheader(title)
    st.caption(description)


def metric_card(
    label: str,
    value: str,
    help_text: str | None = None,
) -> None:
    st.metric(
        label=label,
        value=value,
        help=help_text,
    )


def surface_card(
    title: str,
    text: str,
) -> None:
    st.markdown(
        f"""
<div class="surface-card">
    <h4>{title}</h4>
    <p>{text}</p>
</div>
""",
        unsafe_allow_html=True,
    )