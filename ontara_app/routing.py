"""Deterministic guardrail routing for governed Ontara questions."""

import re

from ontara_app.config import METRICS

SUPPLIER_PATTERN = re.compile(r"\bSUP-\d{3}\b", re.IGNORECASE)


def classify_question(question: str) -> dict[str, str | None]:
    """Classify a question without inventing an ungoverned answer."""

    normalized = " ".join(question.lower().split())

    supplier_match = SUPPLIER_PATTERN.search(question)

    impact_terms = (
        "impact",
        "blast",
        "risk",
        "downstream",
        "disruption",
        "affected",
    )

    if supplier_match and any(term in normalized for term in impact_terms):
        return {
            "kind": "blast_radius",
            "metric": None,
            "supplier_id": supplier_match.group(0).upper(),
        }

    for metric_name, contract in METRICS.items():
        aliases = contract["aliases"]

        if any(alias in normalized for alias in aliases):
            return {
                "kind": "metric",
                "metric": metric_name,
                "supplier_id": None,
            }

    return {
        "kind": "unsupported",
        "metric": None,
        "supplier_id": None,
    }