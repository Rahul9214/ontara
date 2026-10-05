"""Independent contract tests for Ontara's synthetic supply-chain dataset."""

from __future__ import annotations

from copy import deepcopy
from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import Any

import pytest

from scripts.generate_synthetic_data import (
    DATASET_SEED,
    PRIMARY_KEYS,
    TABLE_ORDER,
    Dataset,
    DatasetContractError,
    build_dataset,
    sha256_file,
    validate_dataset,
    write_dataset,
)

EXPECTED_ROW_COUNTS = {
    "suppliers": 8,
    "parts": 12,
    "plants": 4,
    "supplier_parts": 23,
    "purchase_orders": 24,
    "customers": 10,
    "customer_orders": 30,
    "shipments": 32,
    "shipment_events": 192,
    "inventory_snapshots": 48,
}


@pytest.fixture(scope="module")
def dataset() -> Dataset:
    """Build one validated dataset for read-only contract tests."""

    return build_dataset(seed=DATASET_SEED)


def _index(
    rows: list[dict[str, Any]],
    key: str,
) -> dict[Any, dict[str, Any]]:
    return {row[key]: row for row in rows}


def test_expected_table_contract(dataset: Dataset) -> None:
    """The dataset exposes exactly the governed source tables."""

    assert tuple(dataset) == TABLE_ORDER
    assert set(dataset) == set(EXPECTED_ROW_COUNTS)

    for table_name, expected_count in EXPECTED_ROW_COUNTS.items():
        assert len(dataset[table_name]) == expected_count


def test_generation_is_deterministic_in_memory() -> None:
    """The same seed must generate exactly the same in-memory dataset."""

    first = build_dataset(seed=DATASET_SEED)
    second = build_dataset(seed=DATASET_SEED)

    assert first == second


def test_generated_files_are_byte_reproducible(tmp_path: Path) -> None:
    """Repeated generation must produce byte-identical CSV artifacts."""

    first_dataset = build_dataset(seed=DATASET_SEED)
    second_dataset = build_dataset(seed=DATASET_SEED)

    first_files = write_dataset(
        first_dataset,
        output_dir=tmp_path / "first",
    )
    second_files = write_dataset(
        second_dataset,
        output_dir=tmp_path / "second",
    )

    assert tuple(first_files) == TABLE_ORDER
    assert tuple(second_files) == TABLE_ORDER

    for table_name in TABLE_ORDER:
        first_path = first_files[table_name]
        second_path = second_files[table_name]

        assert first_path.read_bytes() == second_path.read_bytes()
        assert sha256_file(first_path) == sha256_file(second_path)


def test_primary_keys_are_unique(dataset: Dataset) -> None:
    """Every table must satisfy its declared primary-key contract."""

    for table_name, key_fields in PRIMARY_KEYS.items():
        keys = [
            tuple(row[field] for field in key_fields)
            for row in dataset[table_name]
        ]

        assert len(keys) == len(set(keys))


def test_supplier_part_foreign_keys(dataset: Dataset) -> None:
    """Supplier-part relationships must reference valid masters."""

    supplier_ids = {
        row["supplier_id"]
        for row in dataset["suppliers"]
    }
    part_ids = {
        row["part_id"]
        for row in dataset["parts"]
    }

    for row in dataset["supplier_parts"]:
        assert row["supplier_id"] in supplier_ids
        assert row["part_id"] in part_ids


def test_purchase_order_foreign_keys(dataset: Dataset) -> None:
    """Purchase orders must reference valid supplier, plant, and part masters."""

    supplier_ids = {
        row["supplier_id"]
        for row in dataset["suppliers"]
    }
    plant_ids = {
        row["plant_id"]
        for row in dataset["plants"]
    }
    part_ids = {
        row["part_id"]
        for row in dataset["parts"]
    }

    for row in dataset["purchase_orders"]:
        assert row["supplier_id"] in supplier_ids
        assert row["plant_id"] in plant_ids
        assert row["part_id"] in part_ids


def test_customer_order_foreign_keys(dataset: Dataset) -> None:
    """Customer orders must reference valid customer, plant, and part masters."""

    customer_ids = {
        row["customer_id"]
        for row in dataset["customers"]
    }
    plant_ids = {
        row["plant_id"]
        for row in dataset["plants"]
    }
    part_ids = {
        row["part_id"]
        for row in dataset["parts"]
    }

    for row in dataset["customer_orders"]:
        assert row["customer_id"] in customer_ids
        assert row["plant_id"] in plant_ids
        assert row["part_id"] in part_ids


def test_inventory_foreign_keys(dataset: Dataset) -> None:
    """Inventory snapshots must reference valid plant-part combinations."""

    plant_ids = {
        row["plant_id"]
        for row in dataset["plants"]
    }
    part_ids = {
        row["part_id"]
        for row in dataset["parts"]
    }

    for row in dataset["inventory_snapshots"]:
        assert row["plant_id"] in plant_ids
        assert row["part_id"] in part_ids


def test_shipment_foreign_keys_and_direction(dataset: Dataset) -> None:
    """Inbound and outbound shipments must obey directional relationship contracts."""

    purchase_orders = _index(
        dataset["purchase_orders"],
        "purchase_order_id",
    )
    customer_orders = _index(
        dataset["customer_orders"],
        "order_id",
    )

    for shipment in dataset["shipments"]:
        if shipment["shipment_type"] == "INBOUND":
            purchase_order_id = shipment["purchase_order_id"]

            assert purchase_order_id in purchase_orders
            assert shipment["customer_order_id"] is None
            assert shipment["customer_id"] is None

            purchase_order = purchase_orders[purchase_order_id]

            assert shipment["supplier_id"] == purchase_order["supplier_id"]
            assert shipment["plant_id"] == purchase_order["plant_id"]
            assert shipment["part_id"] == purchase_order["part_id"]

        elif shipment["shipment_type"] == "OUTBOUND":
            customer_order_id = shipment["customer_order_id"]

            assert customer_order_id in customer_orders
            assert shipment["purchase_order_id"] is None
            assert shipment["supplier_id"] is None

            customer_order = customer_orders[customer_order_id]

            assert shipment["customer_id"] == customer_order["customer_id"]
            assert shipment["plant_id"] == customer_order["plant_id"]
            assert shipment["part_id"] == customer_order["part_id"]

        else:
            pytest.fail(
                f"Unexpected shipment type: {shipment['shipment_type']}"
            )


def test_shipment_events_are_referentially_valid(dataset: Dataset) -> None:
    """Every shipment event must belong to a real shipment."""

    shipment_ids = {
        row["shipment_id"]
        for row in dataset["shipments"]
    }

    for event in dataset["shipment_events"]:
        assert event["shipment_id"] in shipment_ids


def test_purchase_order_quantity_contracts(dataset: Dataset) -> None:
    """Inbound quantities must remain positive and internally consistent."""

    for row in dataset["purchase_orders"]:
        ordered = int(row["ordered_units"])
        received = int(row["received_units"])

        assert ordered > 0
        assert received >= 0
        assert received <= ordered


def test_customer_order_quantity_contracts(dataset: Dataset) -> None:
    """Customer-order fulfillment cannot exceed demand."""

    for row in dataset["customer_orders"]:
        ordered = int(row["ordered_units"])
        fulfilled = int(row["fulfilled_units"])

        assert ordered > 0
        assert fulfilled >= 0
        assert fulfilled <= ordered


def test_inventory_quantity_contracts(dataset: Dataset) -> None:
    """Inventory quantities are non-negative and demand baselines are positive."""

    quantity_fields = (
        "on_hand_units",
        "allocated_units",
        "in_transit_units",
        "safety_stock_units",
    )

    for row in dataset["inventory_snapshots"]:
        for field in quantity_fields:
            assert int(row[field]) >= 0

        assert Decimal(str(row["avg_daily_demand_units"])) > 0


def test_monetary_values_are_non_negative(dataset: Dataset) -> None:
    """All governed monetary inputs must be non-negative."""

    monetary_fields = {
        "parts": ("standard_unit_cost_usd",),
        "supplier_parts": ("contracted_unit_cost_usd",),
        "purchase_orders": (
            "unit_purchase_cost_usd",
            "freight_cost_usd",
            "duty_cost_usd",
            "handling_cost_usd",
        ),
        "customer_orders": ("unit_sale_price_usd",),
    }

    for table_name, fields in monetary_fields.items():
        for row in dataset[table_name]:
            for field in fields:
                assert Decimal(str(row[field])) >= 0


def test_delivered_shipment_dates_are_consistent(dataset: Dataset) -> None:
    """Only delivered shipments may contain actual delivery dates."""

    for shipment in dataset["shipments"]:
        ship_date = shipment["ship_date"]
        actual_delivery_date = shipment["actual_delivery_date"]

        assert isinstance(ship_date, date)

        if shipment["status"] == "DELIVERED":
            assert isinstance(actual_delivery_date, date)
            assert actual_delivery_date >= ship_date
        else:
            assert actual_delivery_date is None


def test_shipment_event_ordering(dataset: Dataset) -> None:
    """Event sequences and timestamps must remain strictly ordered per shipment."""

    events_by_shipment: dict[str, list[dict[str, Any]]] = {}

    for event in dataset["shipment_events"]:
        shipment_id = str(event["shipment_id"])
        events_by_shipment.setdefault(shipment_id, []).append(event)

    for shipment in dataset["shipments"]:
        shipment_id = str(shipment["shipment_id"])
        events = events_by_shipment[shipment_id]

        events = sorted(
            events,
            key=lambda event: int(event["event_sequence"]),
        )

        sequences = [
            int(event["event_sequence"])
            for event in events
        ]
        timestamps = [
            event["event_timestamp"]
            for event in events
        ]

        assert sequences == list(
            range(1, len(events) + 1)
        )
        assert timestamps == sorted(timestamps)

        if shipment["status"] == "DELIVERED":
            assert events[-1]["event_type"] == "DELIVERED"

        if shipment["status"] == "DELAYED":
            event_types = {
                event["event_type"]
                for event in events
            }
            assert "DELAY_REPORTED" in event_types


def test_supplier_disruption_scenario(dataset: Dataset) -> None:
    """SUP-003 is the stable disruption anchor for ontology traversal."""

    suppliers = _index(
        dataset["suppliers"],
        "supplier_id",
    )

    supplier = suppliers["SUP-003"]

    assert supplier["status"] == "DISRUPTED"
    assert supplier["risk_tier"] == "HIGH"

    disrupted_parts = {
        row["part_id"]
        for row in dataset["supplier_parts"]
        if row["supplier_id"] == "SUP-003"
    }

    assert disrupted_parts == {
        "PRT-006",
        "PRT-009",
        "PRT-010",
    }


def test_every_disrupted_part_has_active_alternate_supplier(
    dataset: Dataset,
) -> None:
    """Each disrupted part must have at least one usable alternate source."""

    suppliers = _index(
        dataset["suppliers"],
        "supplier_id",
    )

    disrupted_parts = {
        row["part_id"]
        for row in dataset["supplier_parts"]
        if row["supplier_id"] == "SUP-003"
    }

    for part_id in disrupted_parts:
        alternate_suppliers = [
            row["supplier_id"]
            for row in dataset["supplier_parts"]
            if (
                row["part_id"] == part_id
                and row["supplier_id"] != "SUP-003"
                and suppliers[row["supplier_id"]]["status"] == "ACTIVE"
            )
        ]

        assert alternate_suppliers


def test_partial_fulfillment_scenario(dataset: Dataset) -> None:
    """ORD-008 remains the stable quantity-weighted fill-rate exception."""

    orders = _index(
        dataset["customer_orders"],
        "order_id",
    )

    order = orders["ORD-008"]

    assert order["customer_id"] == "CUS-003"
    assert order["plant_id"] == "PLT-003"
    assert order["part_id"] == "PRT-009"
    assert order["ordered_units"] == 100
    assert order["fulfilled_units"] == 40
    assert order["status"] == "PARTIAL"


def test_late_delivery_scenario(dataset: Dataset) -> None:
    """SHP-OUT-006 remains the stable OTD exception."""

    shipments = _index(
        dataset["shipments"],
        "shipment_id",
    )

    shipment = shipments["SHP-OUT-006"]

    assert shipment["status"] == "DELIVERED"
    assert shipment["actual_delivery_date"] > shipment["promised_delivery_date"]


def test_inventory_shortage_scenario(dataset: Dataset) -> None:
    """PLT-003 and PRT-009 remain below the governed safety-stock threshold."""

    snapshot = next(
        row
        for row in dataset["inventory_snapshots"]
        if (
            row["plant_id"] == "PLT-003"
            and row["part_id"] == "PRT-009"
        )
    )

    available_inventory = (
        int(snapshot["on_hand_units"])
        - int(snapshot["allocated_units"])
    )

    assert available_inventory == 5
    assert int(snapshot["safety_stock_units"]) == 20
    assert available_inventory < int(snapshot["safety_stock_units"])
    assert Decimal(str(snapshot["avg_daily_demand_units"])) == Decimal("12.00")


def test_landed_cost_variance_scenario(dataset: Dataset) -> None:
    """PO-012 remains the controlled high ancillary-cost exception."""

    purchase_orders = _index(
        dataset["purchase_orders"],
        "purchase_order_id",
    )

    purchase_order = purchase_orders["PO-012"]

    assert purchase_order["freight_cost_usd"] == Decimal("4200.00")
    assert purchase_order["duty_cost_usd"] == Decimal("1600.00")
    assert purchase_order["handling_cost_usd"] == Decimal("900.00")

    scenario_ancillary_cost = (
        purchase_order["freight_cost_usd"]
        + purchase_order["duty_cost_usd"]
        + purchase_order["handling_cost_usd"]
    )

    other_ancillary_costs = [
        row["freight_cost_usd"]
        + row["duty_cost_usd"]
        + row["handling_cost_usd"]
        for row in dataset["purchase_orders"]
        if row["purchase_order_id"] != "PO-012"
    ]

    assert scenario_ancillary_cost == Decimal("6700.00")
    assert scenario_ancillary_cost > max(other_ancillary_costs)


def test_strategic_customer_exposure(dataset: Dataset) -> None:
    """The disrupted SUP-003 network reaches a strategic customer."""

    customers = _index(
        dataset["customers"],
        "customer_id",
    )
    orders = _index(
        dataset["customer_orders"],
        "order_id",
    )

    order = orders["ORD-008"]
    customer = customers[order["customer_id"]]

    assert order["part_id"] == "PRT-009"
    assert customer["customer_id"] == "CUS-003"
    assert customer["priority_tier"] == "STRATEGIC"


def test_disruption_has_end_to_end_blast_radius_path(dataset: Dataset) -> None:
    """SUP-003 must connect through part and plant to downstream customer demand."""

    disrupted_parts = {
        row["part_id"]
        for row in dataset["supplier_parts"]
        if row["supplier_id"] == "SUP-003"
    }

    disrupted_plant_parts = {
        (row["plant_id"], row["part_id"])
        for row in dataset["purchase_orders"]
        if (
            row["supplier_id"] == "SUP-003"
            and row["part_id"] in disrupted_parts
        )
    }

    impacted_orders = [
        row
        for row in dataset["customer_orders"]
        if (
            row["plant_id"],
            row["part_id"],
        )
        in disrupted_plant_parts
    ]

    impacted_order_ids = {
        row["order_id"]
        for row in impacted_orders
    }
    impacted_customer_ids = {
        row["customer_id"]
        for row in impacted_orders
    }

    assert "ORD-008" in impacted_order_ids
    assert "CUS-003" in impacted_customer_ids


def test_on_time_delivery_metric_prerequisites(dataset: Dataset) -> None:
    """The data contains both on-time and late delivered shipments."""

    delivered = [
        row
        for row in dataset["shipments"]
        if row["status"] == "DELIVERED"
    ]

    on_time = [
        row
        for row in delivered
        if row["actual_delivery_date"] <= row["promised_delivery_date"]
    ]

    late = [
        row
        for row in delivered
        if row["actual_delivery_date"] > row["promised_delivery_date"]
    ]

    assert delivered
    assert on_time
    assert late


def test_fill_rate_metric_prerequisites(dataset: Dataset) -> None:
    """Quantity-weighted fill rate has valid numerator and denominator inputs."""

    total_ordered = sum(
        int(row["ordered_units"])
        for row in dataset["customer_orders"]
    )
    total_fulfilled = sum(
        int(row["fulfilled_units"])
        for row in dataset["customer_orders"]
    )

    assert total_ordered > 0
    assert total_fulfilled > 0
    assert total_fulfilled < total_ordered


def test_days_of_inventory_metric_prerequisites(dataset: Dataset) -> None:
    """Every inventory row supports a safe days-of-inventory calculation."""

    for row in dataset["inventory_snapshots"]:
        available_inventory = (
            Decimal(str(row["on_hand_units"]))
            - Decimal(str(row["allocated_units"]))
        )
        average_daily_demand = Decimal(
            str(row["avg_daily_demand_units"])
        )

        assert average_daily_demand > 0

        days_of_inventory = (
            available_inventory
            / average_daily_demand
        )

        assert days_of_inventory.is_finite()


def test_landed_cost_metric_prerequisites(dataset: Dataset) -> None:
    """Every purchase order supports the canonical landed-cost calculation."""

    for row in dataset["purchase_orders"]:
        purchase_cost = (
            Decimal(str(row["received_units"]))
            * Decimal(str(row["unit_purchase_cost_usd"]))
        )

        landed_cost = (
            purchase_cost
            + Decimal(str(row["freight_cost_usd"]))
            + Decimal(str(row["duty_cost_usd"]))
            + Decimal(str(row["handling_cost_usd"]))
        )

        assert landed_cost >= 0


def test_validation_rejects_over_fulfillment(dataset: Dataset) -> None:
    """The generator must fail loudly when a quantity contract is corrupted."""

    corrupted = deepcopy(dataset)

    corrupted["customer_orders"][0]["fulfilled_units"] = (
        int(corrupted["customer_orders"][0]["ordered_units"]) + 1
    )

    with pytest.raises(
        DatasetContractError,
        match="fulfilled quantity",
    ):
        validate_dataset(corrupted)


def test_validation_rejects_orphan_supplier(dataset: Dataset) -> None:
    """The generator must fail loudly when a foreign key is corrupted."""

    corrupted = deepcopy(dataset)

    corrupted["purchase_orders"][0]["supplier_id"] = "SUP-999"

    with pytest.raises(
        DatasetContractError,
        match="orphan supplier",
    ):
        validate_dataset(corrupted)