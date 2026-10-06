"""Tests for Ontara governed conversational routing."""

from ontara_app.routing import classify_question


def test_routes_on_time_delivery() -> None:
    result = classify_question(
        "What is our on-time delivery rate?"
    )

    assert result["kind"] == "metric"
    assert result["metric"] == "On-Time Delivery"


def test_routes_fill_rate() -> None:
    result = classify_question(
        "What is our current fill rate?"
    )

    assert result["kind"] == "metric"
    assert result["metric"] == "Fill Rate"


def test_routes_days_of_inventory() -> None:
    result = classify_question(
        "How many days of inventory do we have?"
    )

    assert result["kind"] == "metric"
    assert result["metric"] == "Days of Inventory"


def test_routes_landed_cost() -> None:
    result = classify_question(
        "What is our landed cost per unit?"
    )

    assert result["kind"] == "metric"
    assert result["metric"] == "Landed Cost / Unit"


def test_routes_supplier_blast_radius() -> None:
    result = classify_question(
        "What is the downstream impact of disrupted supplier SUP-003?"
    )

    assert result["kind"] == "blast_radius"
    assert result["supplier_id"] == "SUP-003"


def test_fails_closed_for_unsupported_question() -> None:
    result = classify_question(
        "Predict next year's demand using assumptions."
    )

    assert result["kind"] == "unsupported"
    assert result["metric"] is None
    assert result["supplier_id"] is None