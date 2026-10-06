"""Judge-facing Streamlit views for Ontara."""

from __future__ import annotations

from typing import Any

import pandas as pd
import streamlit as st

from ontara_app.components import (
    metric_card,
    section_title,
    surface_card,
)
from ontara_app.config import (
    ASK_EXAMPLES,
    METRICS,
    PERSONA_QUESTIONS,
    SEMANTIC_CONTRACT_VERSION,
    SEMANTIC_VIEW,
)
from ontara_app.data import (
    action_center,
    action_events,
    all_metric_values,
    alternate_sources,
    blast_details,
    blast_summary,
    current_identity,
    decide_supply_exception,
    executive_health,
    metric_value,
    request_supply_exception,
    supplier_options,
    update_supply_exception_status,
)
from ontara_app.routing import classify_question


def _numeric(
    value: Any,
    default: float = 0.0,
) -> float:
    if value is None:
        return default

    return float(value)


def _display_columns(
    frame: pd.DataFrame,
    preferred: list[str],
) -> pd.DataFrame:
    available = [
        column
        for column in preferred
        if column in frame.columns
    ]

    if not available:
        return frame

    return frame[available]


def _metric_display(
    metric_name: str,
    value: float,
) -> str:
    contract = METRICS[metric_name]
    precision = int(contract["precision"])
    unit = str(contract["unit"])

    if metric_name == "Landed Cost / Unit":
        return f"${value:,.{precision}f}"

    if unit == "%":
        return f"{value:.{precision}f}%"

    return f"{value:,.{precision}f}{unit}"


def render_overview() -> None:
    section_title(
        "Executive Overview",
        (
            "A governed control tower powered by canonical Snowflake "
            "semantic metrics and operational state."
        ),
    )

    values = all_metric_values()

    columns = st.columns(4)

    for column, metric_name in zip(
        columns,
        METRICS,
        strict=True,
    ):
        with column:
            contract = METRICS[metric_name]

            metric_card(
                metric_name,
                _metric_display(
                    metric_name,
                    values[metric_name],
                ),
                str(contract["definition"]),
            )

    st.write("")

    health = executive_health()
    health_columns = st.columns(4)

    with health_columns[0]:
        metric_card(
            "Disrupted suppliers",
            str(health.get("DISRUPTED_SUPPLIERS", 0)),
        )

    with health_columns[1]:
        metric_card(
            "Critical impact paths",
            str(health.get("CRITICAL_IMPACT_PATHS", 0)),
        )

    with health_columns[2]:
        metric_card(
            "Maximum risk score",
            f"{_numeric(health.get('MAX_RISK_SCORE')):.0f}/100",
        )

    with health_columns[3]:
        metric_card(
            "Open governed actions",
            str(health.get("OPEN_GOVERNED_ACTIONS", 0)),
        )

    st.write("")
    section_title(
        "Why Ontara is different",
        (
            "The product connects semantic consistency, quantitative "
            "ontology impact, and human-governed execution."
        ),
    )

    c1, c2, c3 = st.columns(3)

    with c1:
        surface_card(
            "01 · Semantic Contract Verifier",
            (
                "Planning, Procurement, and Logistics questions resolve "
                "to the same governed metric definition and value."
            ),
        )

    with c2:
        surface_card(
            "02 · Ontology Blast Radius",
            (
                "Trace Supplier → Part → Plant → Order → Customer while "
                "quantifying revenue, inventory, sourcing, and risk."
            ),
        )

    with c3:
        surface_card(
            "03 · Governed Action Loop",
            (
                "Convert trusted evidence into persisted actions with "
                "human approval, controlled transitions, and audit history."
            ),
        )

    st.write("")
    section_title(
        "Recent governed actions",
        (
            "Operational state is read directly from "
            "ONTARA.GOVERNANCE.ACTION_CENTER."
        ),
    )

    actions = action_center()

    if actions.empty:
        st.info("No governed actions have been created yet.")
        return

    preferred = [
        "STATUS",
        "APPROVAL_STATUS",
        "SUPPLIER_NAME",
        "PART_NAME",
        "ORDER_ID",
        "CUSTOMER_NAME",
        "RISK_SCORE",
        "RISK_BAND",
        "REVENUE_EXPOSURE_USD",
        "RECOMMENDED_RESPONSE",
        "UPDATED_AT",
    ]

    st.dataframe(
        _display_columns(
            actions,
            preferred,
        ),
        use_container_width=True,
        hide_index=True,
    )


def render_ask_ontara() -> None:
    section_title(
        "Ask Ontara",
        (
            "Conversational access to governed metrics and supply-chain "
            "impact without inventing unsupported answers."
        ),
    )

    st.markdown(
        """
<div class="guardrail">
    <strong>Verified-query mode is active.</strong>
    Cortex/CoCo agent responses are not simulated while account
    entitlement is pending. Supported questions resolve through
    governed Snowflake semantic objects; unsupported questions fail
    safely instead of generating ungoverned analytics.
</div>
""",
        unsafe_allow_html=True,
    )

    st.write("")

    example = st.selectbox(
        "Try a governed question",
        ASK_EXAMPLES,
    )

    custom = st.text_input(
        "Or ask your own question",
        placeholder=(
            "Example: What is the downstream impact of "
            "disrupted supplier SUP-003?"
        ),
    )

    question = custom.strip() or example

    if not st.button(
        "Ask Ontara",
        type="primary",
        use_container_width=True,
    ):
        return

    route = classify_question(question)

    st.caption(f"Question: {question}")

    if route["kind"] == "metric":
        metric_name = str(route["metric"])
        contract = METRICS[metric_name]
        value = metric_value(metric_name)

        st.success(
            "Resolved through the governed semantic contract."
        )

        metric_card(
            metric_name,
            _metric_display(
                metric_name,
                value,
            ),
            str(contract["definition"]),
        )

        with st.expander(
            "Why this answer?",
            expanded=True,
        ):
            st.write(
                f"**Contract:** {contract['version']}"
            )
            st.write(
                f"**Semantic source:** {contract['source']}"
            )
            st.write(
                f"**Semantic view:** `{SEMANTIC_VIEW}`"
            )
            st.write(
                f"**Definition:** {contract['definition']}"
            )
            st.code(
                str(contract["query"]).strip(),
                language="sql",
            )

        return

    if route["kind"] == "blast_radius":
        supplier_id = str(route["supplier_id"])
        summary = blast_summary(supplier_id)
        details = blast_details(supplier_id)

        if summary.empty and details.empty:
            st.warning(
                f"No governed impact evidence exists for {supplier_id}."
            )
            return

        st.success(

                f"Resolved governed downstream impact for "
                f"{supplier_id}."

        )

        if not summary.empty:
            st.dataframe(
                summary,
                use_container_width=True,
                hide_index=True,
            )

        if not details.empty:
            st.dataframe(
                details,
                use_container_width=True,
                hide_index=True,
            )

        return

    st.warning(

            "Ontara could not map this question to an approved semantic "
            "metric or governed impact path. No analytical answer was "
            "generated."

    )

    st.write(
        "Use one of the supported metric questions or include a "
        "supplier identifier such as `SUP-003` with an impact question."
    )


def render_contract_verifier() -> None:
    section_title(
        "Semantic Contract Verifier",
        (
            "Prove that different business personas receive the same "
            "canonical answer for the same metric intent."
        ),
    )

    metric_name = st.selectbox(
        "Canonical metric",
        list(METRICS.keys()),
    )

    contract = METRICS[metric_name]
    persona_questions = PERSONA_QUESTIONS[metric_name]

    results: list[dict[str, Any]] = []

    for persona, question in persona_questions:
        value = metric_value(metric_name)

        results.append(
            {
                "Persona": persona,
                "Question": question,
                "Metric": metric_name,
                "Canonical Value": _metric_display(
                    metric_name,
                    value,
                ),
                "Raw Value": value,
                "Contract": contract["version"],
            }
        )

    raw_values = [
        round(float(result["Raw Value"]), 8)
        for result in results
    ]

    contract_pass = len(set(raw_values)) == 1

    if contract_pass:
        st.markdown(
            """
<div class="contract-pass">
    <strong>SEMANTIC CONTRACT PASS</strong><br/>
    All persona variants resolved to the same governed metric value.
</div>
""",
            unsafe_allow_html=True,
        )
    else:
        st.error(
            "Semantic contract failed: persona answers diverged."
        )

    result_frame = pd.DataFrame(results).drop(
        columns=["Raw Value"]
    )

    st.dataframe(
        result_frame,
        use_container_width=True,
        hide_index=True,
    )

    c1, c2, c3 = st.columns(3)

    with c1:
        metric_card(
            "Contract version",
            str(contract["version"]),
        )

    with c2:
        metric_card(
            "Semantic contract",
            SEMANTIC_CONTRACT_VERSION,
        )

    with c3:
        metric_card(
            "Result",
            "PASS" if contract_pass else "FAIL",
        )

    with st.expander(
        "Why this answer?",
        expanded=True,
    ):
        st.write(
            f"**Definition:** {contract['definition']}"
        )
        st.write(
            f"**Semantic source:** `{contract['source']}`"
        )
        st.write(
            f"**Semantic view:** `{SEMANTIC_VIEW}`"
        )
        st.write(

                "**Verification rule:** persona wording can change, "
                "but the canonical metric definition and result cannot."

        )
        st.code(
            str(contract["query"]).strip(),
            language="sql",
        )


def render_blast_radius() -> None:
    section_title(
        "Ontology Blast Radius",
        (
            "Quantify how supplier disruption propagates through the "
            "governed supply-chain ontology."
        ),
    )

    suppliers = supplier_options()

    if suppliers.empty:
        st.warning("No supplier master data is available.")
        return

    ids = suppliers["SUPPLIER_ID"].astype(str).tolist()

    default_index = (
        ids.index("SUP-003")
        if "SUP-003" in ids
        else 0
    )

    supplier_id = st.selectbox(
        "Supplier",
        ids,
        index=default_index,
        format_func=lambda value: _supplier_label(
            suppliers,
            value,
        ),
    )

    summary = blast_summary(supplier_id)
    details = blast_details(supplier_id)

    alternate_error = None

    try:
        alternates = alternate_sources(supplier_id)
    except Exception as exc:
        alternates = pd.DataFrame()
        alternate_error = str(exc)

    if summary.empty and details.empty:
        st.info(
            "No governed downstream impact exists for this supplier."
        )
        return

    st.markdown(
        """
`Supplier` → `Part` → `Plant` → `Order` → `Customer`
"""
    )

    if not details.empty:
        kpis = st.columns(5)

        with kpis[0]:
            metric_card(
                "Affected orders",
                str(details["ORDER_ID"].nunique()),
            )

        with kpis[1]:
            metric_card(
                "Affected customers",
                str(details["CUSTOMER_ID"].nunique()),
            )

        with kpis[2]:
            outstanding = details["OUTSTANDING_UNITS"].fillna(0).sum()

            metric_card(
                "Outstanding units",
                f"{float(outstanding):,.0f}",
            )

        with kpis[3]:
            exposure = (
                details["REVENUE_EXPOSURE_USD"]
                .fillna(0)
                .sum()
            )

            metric_card(
                "Revenue exposure",
                f"${float(exposure):,.2f}",
            )

        with kpis[4]:
            risk = details["RISK_SCORE"].fillna(0).max()

            metric_card(
                "Maximum risk",
                f"{float(risk):.0f}/100",
            )

    summary_tab, detail_tab, alternate_tab = st.tabs(
        [
            "Impact summary",
            "Impact paths",
            "Alternate sourcing",
        ]
    )

    with summary_tab:
        if summary.empty:
            st.info("No supplier-level impact summary.")
        else:
            st.dataframe(
                summary,
                use_container_width=True,
                hide_index=True,
            )

    with detail_tab:
        if details.empty:
            st.info("No downstream impact paths.")
        else:
            st.dataframe(
                details,
                use_container_width=True,
                hide_index=True,
            )

    with alternate_tab:
        if alternate_error:
            st.warning(
                "Alternate-source evidence is temporarily unavailable. "
                "Core blast-radius evidence remains available."
            )

            with st.expander("Technical detail"):
                st.code(alternate_error)

        elif alternates.empty:
            st.warning(
                "No active alternate-source evidence was found."
            )

        else:
            st.dataframe(
                alternates,
                use_container_width=True,
                hide_index=True,
            )


def _supplier_label(
    suppliers: pd.DataFrame,
    supplier_id: str,
) -> str:
    match = suppliers[
        suppliers["SUPPLIER_ID"].astype(str) == supplier_id
    ]

    if match.empty:
        return supplier_id

    row = match.iloc[0]

    return (
        f"{supplier_id} · {row['SUPPLIER_NAME']} · "
        f"{row['STATUS']} · {row['RISK_TIER']}"
    )


def _flash_action_result() -> None:
    result = st.session_state.pop(
        "ontara_action_result",
        None,
    )

    if result is None:
        return

    st.success(
        "Governed Snowflake action completed."
    )
    st.json(result)


def _set_action_result(
    result: dict[str, Any],
) -> None:
    st.session_state["ontara_action_result"] = result
    st.rerun()


def render_action_center() -> None:
    section_title(
        "Governed Action Center",
        (
            "Turn disruption evidence into controlled operational "
            "actions with human approval and persisted audit history."
        ),
    )

    _flash_action_result()

    identity = current_identity()
    actor = str(
        identity.get(
            "USER_NAME",
            "UNKNOWN_USER",
        )
    )

    st.caption(

            f"Authenticated Snowflake actor: `{actor}` · "
            "the UI does not ask the user to type an approval identity."

    )

    actions = action_center()

    current_tab, create_tab, approval_tab, execution_tab, audit_tab = (
        st.tabs(
            [
                "Current actions",
                "Create action",
                "Approval gate",
                "Execution",
                "Audit trail",
            ]
        )
    )

    with current_tab:
        _render_current_actions(actions)

    with create_tab:
        _render_create_action(actor)

    with approval_tab:
        _render_approval_gate(
            actions,
            actor,
        )

    with execution_tab:
        _render_execution_gate(
            actions,
            actor,
        )

    with audit_tab:
        _render_audit_trail(actions)


def _render_current_actions(
    actions: pd.DataFrame,
) -> None:
    if actions.empty:
        st.info("No governed actions currently exist.")
        return

    status_columns = st.columns(5)

    statuses = [
        "PENDING_APPROVAL",
        "APPROVED",
        "IN_PROGRESS",
        "RESOLVED",
        "REJECTED",
    ]

    for column, status in zip(
        status_columns,
        statuses,
        strict=True,
    ):
        with column:
            count = int(
                (
                    actions["STATUS"].astype(str) == status
                ).sum()
            )

            metric_card(
                status.replace("_", " ").title(),
                str(count),
            )

    preferred = [
        "EXCEPTION_ID",
        "STATUS",
        "APPROVAL_STATUS",
        "SUPPLIER_NAME",
        "PART_NAME",
        "PLANT_NAME",
        "ORDER_ID",
        "CUSTOMER_NAME",
        "RISK_SCORE",
        "RISK_BAND",
        "REVENUE_EXPOSURE_USD",
        "RECOMMENDED_RESPONSE",
        "RECOMMENDED_ACTION",
        "REQUESTED_BY",
        "APPROVED_BY",
        "LAST_EVENT_TYPE",
        "UPDATED_AT",
    ]

    st.dataframe(
        _display_columns(
            actions,
            preferred,
        ),
        use_container_width=True,
        hide_index=True,
    )


def _render_create_action(
    actor: str,
) -> None:
    suppliers = supplier_options()

    if suppliers.empty:
        st.info("No supplier evidence is available.")
        return

    supplier_ids = suppliers["SUPPLIER_ID"].astype(str).tolist()

    default_index = (
        supplier_ids.index("SUP-003")
        if "SUP-003" in supplier_ids
        else 0
    )

    supplier_id = st.selectbox(
        "Impacted supplier",
        supplier_ids,
        index=default_index,
        key="action_supplier",
        format_func=lambda value: _supplier_label(
            suppliers,
            value,
        ),
    )

    details = blast_details(supplier_id)

    if details.empty:
        st.info(
            "This supplier has no governed impact path to action."
        )
        return

    option_indexes = list(range(len(details)))

    selected_index = st.selectbox(
        "Governed impact path",
        option_indexes,
        format_func=lambda index: _impact_option_label(
            details.iloc[index],
        ),
    )

    selected = details.iloc[selected_index]

    part_id = str(selected["PART_ID"])
    order_id = str(selected["ORDER_ID"])

    request_key = (
        f"UI-{supplier_id}-{part_id}-{order_id}-"
        "SUPPLIER-DISRUPTION-V1"
    )

    st.caption(
        f"Idempotency key: `{request_key}`"
    )

    title = st.text_input(
        "Action title",
        value=(
            f"Mitigate {supplier_id} disruption for "
            f"{part_id} / {order_id}"
        ),
    )

    recommended_action = st.text_area(
        "Recommended operational action",
        value=(
            "Expedite mitigation and evaluate the governed "
            "alternate-source options."
        ),
    )

    source_question = st.text_input(
        "Source analytical question",
        value=(
            f"What is the downstream impact of disrupted "
            f"supplier {supplier_id}?"
        ),
    )

    st.write(

            f"**Governed risk:** {selected['RISK_SCORE']} "
            f"({selected['RISK_BAND']})"

    )

    st.write(

            "**Governed revenue exposure:** "
            f"${float(selected['REVENUE_EXPOSURE_USD']):,.2f}"

    )

    if st.button(
        "Submit for human approval",
        type="primary",
        use_container_width=True,
    ):
        result = request_supply_exception(
            request_key=request_key,
            supplier_id=supplier_id,
            part_id=part_id,
            order_id=order_id,
            exception_type="SUPPLIER_DISRUPTION",
            title=title,
            recommended_action=recommended_action,
            source_question=source_question,
            actor=actor,
        )

        _set_action_result(result)


def _impact_option_label(
    row: pd.Series,
) -> str:
    return (
        f"{row['PART_ID']} → {row['PLANT_ID']} → "
        f"{row['ORDER_ID']} → {row['CUSTOMER_ID']} · "
        f"Risk {row['RISK_SCORE']} {row['RISK_BAND']}"
    )


def _render_approval_gate(
    actions: pd.DataFrame,
    actor: str,
) -> None:
    if actions.empty:
        st.info("No actions are awaiting review.")
        return

    pending = actions[
        actions["STATUS"].astype(str) == "PENDING_APPROVAL"
    ]

    if pending.empty:
        st.info(
            "No governed actions are currently awaiting approval."
        )
        return

    exception_ids = pending["EXCEPTION_ID"].astype(str).tolist()

    exception_id = st.selectbox(
        "Pending action",
        exception_ids,
        format_func=lambda value: _action_label(
            pending,
            value,
        ),
    )

    selected = pending[
        pending["EXCEPTION_ID"].astype(str) == exception_id
    ].iloc[0]

    st.write(

            f"**Recommended response:** "
            f"{selected['RECOMMENDED_RESPONSE']}"

    )

    st.write(

            f"**Risk:** {selected['RISK_SCORE']} "
            f"{selected['RISK_BAND']}"

    )

    st.write(

            "**Revenue exposure:** "
            f"${float(selected['REVENUE_EXPOSURE_USD']):,.2f}"

    )

    note = st.text_area(
        "Reviewer decision note",
        value=(
            "Reviewed governed risk, customer impact, inventory "
            "exposure, and sourcing resilience."
        ),
    )

    approve_col, reject_col = st.columns(2)

    with approve_col:
        if st.button(
            "Approve action",
            type="primary",
            use_container_width=True,
        ):
            result = decide_supply_exception(
                exception_id=exception_id,
                decision="APPROVE",
                actor=actor,
                note=note,
            )

            _set_action_result(result)

    with reject_col:
        if st.button(
            "Reject action",
            use_container_width=True,
        ):
            result = decide_supply_exception(
                exception_id=exception_id,
                decision="REJECT",
                actor=actor,
                note=note,
            )

            _set_action_result(result)


def _render_execution_gate(
    actions: pd.DataFrame,
    actor: str,
) -> None:
    if actions.empty:
        st.info("No approved actions are available.")
        return

    executable = actions[
        actions["STATUS"].astype(str).isin(
            [
                "APPROVED",
                "IN_PROGRESS",
            ]
        )
    ]

    if executable.empty:
        st.info(

                "No approved action currently requires an execution "
                "transition."

        )
        return

    exception_ids = (
        executable["EXCEPTION_ID"]
        .astype(str)
        .tolist()
    )

    exception_id = st.selectbox(
        "Executable action",
        exception_ids,
        key="execution_action",
        format_func=lambda value: _action_label(
            executable,
            value,
        ),
    )

    selected = executable[
        executable["EXCEPTION_ID"].astype(str) == exception_id
    ].iloc[0]

    current_status = str(selected["STATUS"])

    target_status = (
        "IN_PROGRESS"
        if current_status == "APPROVED"
        else "RESOLVED"
    )

    st.write(
        f"Current state: **{current_status}**"
    )
    st.write(
        f"Allowed next state: **{target_status}**"
    )

    note = st.text_area(
        "Execution note",
        value=(
            "Execute the approved governed mitigation workflow."
        ),
        key="execution_note",
    )

    if st.button(
        f"Move to {target_status}",
        type="primary",
        use_container_width=True,
    ):
        result = update_supply_exception_status(
            exception_id=exception_id,
            new_status=target_status,
            actor=actor,
            note=note,
        )

        _set_action_result(result)


def _action_label(
    actions: pd.DataFrame,
    exception_id: str,
) -> str:
    selected = actions[
        actions["EXCEPTION_ID"].astype(str) == exception_id
    ]

    if selected.empty:
        return exception_id

    row = selected.iloc[0]

    return (
        f"{row['STATUS']} · {row['SUPPLIER_ID']} · "
        f"{row['PART_ID']} · {row['ORDER_ID']}"
    )


def _render_audit_trail(
    actions: pd.DataFrame,
) -> None:
    if actions.empty:
        st.info("No action audit history exists.")
        return

    exception_ids = actions["EXCEPTION_ID"].astype(str).tolist()

    exception_id = st.selectbox(
        "Governed action",
        exception_ids,
        key="audit_action",
        format_func=lambda value: _action_label(
            actions,
            value,
        ),
    )

    events = action_events(exception_id)

    if events.empty:
        st.info("No audit events exist for this action.")
        return

    st.dataframe(
        events,
        use_container_width=True,
        hide_index=True,
    )


def render_governance() -> None:
    section_title(
        "Trust & Governance",
        (
            "Inspect the contracts, runtime identity, provenance, and "
            "guardrails behind every Ontara answer and action."
        ),
    )

    identity = current_identity()

    identity_columns = st.columns(4)

    values = [
        (
            "Snowflake user",
            identity.get("USER_NAME", "Unknown"),
        ),
        (
            "Active role",
            identity.get("ROLE_NAME", "Unknown"),
        ),
        (
            "Warehouse",
            identity.get("WAREHOUSE_NAME", "Unknown"),
        ),
        (
            "Semantic contract",
            SEMANTIC_CONTRACT_VERSION,
        ),
    ]

    for column, item in zip(
        identity_columns,
        values,
        strict=True,
    ):
        with column:
            metric_card(
                item[0],
                str(item[1]),
            )

    st.write("")
    section_title(
        "Canonical metric contracts",
        (
            "These definitions are shared across business personas "
            "and queried from the native Snowflake semantic view."
        ),
    )

    contracts = []

    for metric_name, contract in METRICS.items():
        contracts.append(
            {
                "Metric": metric_name,
                "Version": contract["version"],
                "Definition": contract["definition"],
                "Semantic Source": contract["source"],
            }
        )

    st.dataframe(
        pd.DataFrame(contracts),
        use_container_width=True,
        hide_index=True,
    )

    st.write("")
    section_title(
        "Governed object chain",
        "The product surface resolves through these Snowflake objects.",
    )

    st.code(
        """
ONTARA.SEMANTIC.SUPPLY_CHAIN
        │
        ├── canonical semantic metrics
        │
        ├── ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
        ├── ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
        ├── ONTARA.SEMANTIC.SUPPLY_ALTERNATE_SOURCES
        │
        └── governed action procedures
                │
                ├── REQUEST_SUPPLY_EXCEPTION
                ├── DECIDE_SUPPLY_EXCEPTION
                └── UPDATE_SUPPLY_EXCEPTION_STATUS
                        │
                        └── ONTARA.GOVERNANCE.ACTION_CENTER
""".strip(),
        language="text",
    )

    st.write("")
    c1, c2, c3 = st.columns(3)

    with c1:
        surface_card(
            "Fail closed",
            (
                "Unsupported conversational questions do not receive "
                "fabricated analytical answers."
            ),
        )

    with c2:
        surface_card(
            "Human approval enforced",
            (
                "Execution transitions are rejected by Snowflake until "
                "the governed action receives explicit approval."
            ),
        )

    with c3:
        surface_card(
            "Auditability",
            (
                "Requests, decisions, and lifecycle transitions persist "
                "as an append-only workflow event history."
            ),
        )

    st.info(

            "Cortex/CoCo agent integration is intentionally not "
            "simulated while the Snowflake entitlement incident remains "
            "open. Ontara continues operating through deterministic "
            "governed-query fallback."

    )
