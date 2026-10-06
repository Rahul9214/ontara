"""Snowflake data-access layer for Ontara Streamlit."""

from __future__ import annotations

import json
from collections.abc import Sequence
from typing import Any

import pandas as pd
from snowflake.snowpark.context import get_active_session

from ontara_app.config import METRICS


def _rows(
    query: str,
    params: Sequence[Any] | None = None,
) -> list[dict[str, Any]]:
    session = get_active_session()

    result = session.sql(
        query,
        params=params,
    ).collect()

    return [
        row.as_dict(recursive=True)
        for row in result
    ]


def query_frame(
    query: str,
    params: Sequence[Any] | None = None,
) -> pd.DataFrame:
    return pd.DataFrame(
        _rows(
            query,
            params=params,
        )
    )


def query_one(
    query: str,
    params: Sequence[Any] | None = None,
) -> dict[str, Any]:
    rows = _rows(
        query,
        params=params,
    )

    if not rows:
        return {}

    return rows[0]


def current_identity() -> dict[str, Any]:
    return query_one(
        """
SELECT
    CURRENT_USER() AS USER_NAME,
    CURRENT_ROLE() AS ROLE_NAME,
    CURRENT_WAREHOUSE() AS WAREHOUSE_NAME,
    CURRENT_DATABASE() AS DATABASE_NAME
"""
    )


def metric_value(metric_name: str) -> float:
    contract = METRICS[metric_name]

    row = query_one(
        str(contract["query"])
    )

    column = str(contract["column"])

    if column not in row:
        raise RuntimeError(
            f"Semantic metric column {column} was not returned."
        )

    return float(row[column])


def all_metric_values() -> dict[str, float]:
    return {
        metric_name: metric_value(metric_name)
        for metric_name in METRICS
    }


def executive_health() -> dict[str, Any]:
    return query_one(
        """
SELECT
    (
        SELECT COUNT_IF(STATUS = 'DISRUPTED')
        FROM ONTARA.CORE.SUPPLIERS
    ) AS DISRUPTED_SUPPLIERS,

    (
        SELECT COUNT_IF(IMPACT_RISK_BAND = 'CRITICAL')
        FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
    ) AS CRITICAL_IMPACT_PATHS,

    (
        SELECT MAX(IMPACT_RISK_SCORE)
        FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
    ) AS MAX_RISK_SCORE,

    (
        SELECT COUNT_IF(
            STATUS IN (
                'PENDING_APPROVAL',
                'APPROVED',
                'IN_PROGRESS'
            )
        )
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    ) AS OPEN_GOVERNED_ACTIONS
"""
    )


def supplier_options() -> pd.DataFrame:
    return query_frame(
        """
SELECT
    SUPPLIER_ID,
    SUPPLIER_NAME,
    STATUS,
    RISK_TIER
FROM ONTARA.CORE.SUPPLIERS
ORDER BY SUPPLIER_ID
"""
    )


def blast_summary(supplier_id: str) -> pd.DataFrame:
    return query_frame(
        """
SELECT *
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = ?
""",
        params=[supplier_id],
    )


def blast_details(supplier_id: str) -> pd.DataFrame:
    return query_frame(
        """
SELECT
    SUPPLIER_ID,
    PART_ID,
    PLANT_ID,
    ORDER_ID,
    CUSTOMER_ID,
    IMPACT_RISK_SCORE AS RISK_SCORE,
    IMPACT_RISK_BAND AS RISK_BAND,
    OUTSTANDING_ORDER_UNITS AS OUTSTANDING_UNITS,
    OUTSTANDING_REVENUE_EXPOSURE_USD AS REVENUE_EXPOSURE_USD,
    AVAILABLE_INVENTORY_UNITS,
    SAFETY_STOCK_UNITS,
    INVENTORY_SHORTFALL_TO_SAFETY_UNITS
        AS INVENTORY_SHORTFALL_UNITS,
    DAYS_OF_INVENTORY,
    ACTIVE_ALTERNATE_SUPPLIER_COUNT,
    FASTEST_ALTERNATE_LEAD_TIME_DAYS
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
WHERE SUPPLIER_ID = ?
ORDER BY
    IMPACT_RISK_SCORE DESC,
    PART_ID,
    ORDER_ID
""",
        params=[supplier_id],
    )


def alternate_sources(supplier_id: str) -> pd.DataFrame:
    return query_frame(
        """
SELECT *
FROM ONTARA.SEMANTIC.SUPPLY_ALTERNATE_SOURCES
WHERE ORIGIN_SUPPLIER_ID = ?
ORDER BY
    PART_ID,
    ALTERNATE_RANK
""",
        params=[supplier_id],
    )


def action_center() -> pd.DataFrame:
    return query_frame(
        """
SELECT *
FROM ONTARA.GOVERNANCE.ACTION_CENTER
ORDER BY UPDATED_AT DESC
"""
    )


def action_events(exception_id: str) -> pd.DataFrame:
    return query_frame(
        """
SELECT
    EVENT_TYPE,
    FROM_STATUS,
    TO_STATUS,
    ACTOR,
    EVENT_NOTE,
    EVENT_PAYLOAD,
    EVENT_AT
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS
WHERE EXCEPTION_ID = ?
ORDER BY
    EVENT_AT,
    EVENT_ID
""",
        params=[exception_id],
    )


def _call(
    query: str,
    params: Sequence[Any],
) -> dict[str, Any]:
    row = query_one(
        query,
        params=params,
    )

    if not row:
        return {}

    value = next(iter(row.values()))

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        try:
            parsed = json.loads(value)

            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass

    return {
        "result": str(value),
    }


def request_supply_exception(
    request_key: str,
    supplier_id: str,
    part_id: str,
    order_id: str,
    exception_type: str,
    title: str,
    recommended_action: str,
    source_question: str,
    actor: str,
) -> dict[str, Any]:
    return _call(
        """
CALL ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
""",
        [
            request_key,
            supplier_id,
            part_id,
            order_id,
            exception_type,
            title,
            recommended_action,
            source_question,
            actor,
        ],
    )


def decide_supply_exception(
    exception_id: str,
    decision: str,
    actor: str,
    note: str,
) -> dict[str, Any]:
    return _call(
        """
CALL ONTARA.GOVERNANCE.DECIDE_SUPPLY_EXCEPTION(
    ?,
    ?,
    ?,
    ?
)
""",
        [
            exception_id,
            decision,
            actor,
            note,
        ],
    )


def update_supply_exception_status(
    exception_id: str,
    new_status: str,
    actor: str,
    note: str,
) -> dict[str, Any]:
    return _call(
        """
CALL ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
    ?,
    ?,
    ?,
    ?
)
""",
        [
            exception_id,
            new_status,
            actor,
            note,
        ],
    )