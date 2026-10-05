"""Generate Ontara's deterministic synthetic supply-chain dataset.

The generator creates a controlled, reproducible supply network for governed
metrics, ontology traversal, disruption analysis, and Snowflake demonstrations.

Run from the repository root:

    uv run python scripts/generate_synthetic_data.py
"""

from __future__ import annotations

import csv
import hashlib
import random
from collections.abc import Iterable, Mapping
from datetime import date, datetime, time, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path
from typing import Any

DATASET_VERSION = "1.0.0"
DATASET_SEED = 20261005
SNAPSHOT_DATE = date(2026, 9, 30)

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "data" / "synthetic" / "generated"

Table = list[dict[str, Any]]
Dataset = dict[str, Table]

TABLE_ORDER = (
    "suppliers",
    "parts",
    "plants",
    "supplier_parts",
    "purchase_orders",
    "customers",
    "customer_orders",
    "shipments",
    "shipment_events",
    "inventory_snapshots",
)

PRIMARY_KEYS: dict[str, tuple[str, ...]] = {
    "suppliers": ("supplier_id",),
    "parts": ("part_id",),
    "plants": ("plant_id",),
    "supplier_parts": ("supplier_id", "part_id"),
    "purchase_orders": ("purchase_order_id",),
    "customers": ("customer_id",),
    "customer_orders": ("order_id",),
    "shipments": ("shipment_id",),
    "shipment_events": ("shipment_event_id",),
    "inventory_snapshots": ("snapshot_date", "plant_id", "part_id"),
}


class DatasetContractError(ValueError):
    """Raised when generated data violates an Ontara dataset contract."""


def money(value: Decimal | float | int | str) -> Decimal:
    """Normalize monetary values to two decimal places."""

    return Decimal(str(value)).quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )


def supplier_rows() -> Table:
    """Return the deterministic supplier master."""

    return [
        {
            "supplier_id": "SUP-001",
            "supplier_name": "Northstar Components",
            "country_code": "US",
            "risk_tier": "LOW",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-002",
            "supplier_name": "Apex Industrial",
            "country_code": "DE",
            "risk_tier": "LOW",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-003",
            "supplier_name": "Orion Precision",
            "country_code": "JP",
            "risk_tier": "HIGH",
            "status": "DISRUPTED",
        },
        {
            "supplier_id": "SUP-004",
            "supplier_name": "BlueRiver Manufacturing",
            "country_code": "MX",
            "risk_tier": "MEDIUM",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-005",
            "supplier_name": "Summit Materials",
            "country_code": "CA",
            "risk_tier": "LOW",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-006",
            "supplier_name": "Vertex Supply",
            "country_code": "KR",
            "risk_tier": "MEDIUM",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-007",
            "supplier_name": "Meridian Systems",
            "country_code": "IN",
            "risk_tier": "LOW",
            "status": "ACTIVE",
        },
        {
            "supplier_id": "SUP-008",
            "supplier_name": "Atlas Fabrication",
            "country_code": "PL",
            "risk_tier": "MEDIUM",
            "status": "ACTIVE",
        },
    ]


def part_rows() -> Table:
    """Return the deterministic governed part master."""

    definitions = [
        ("PRT-001", "Control Module", "ELECTRONICS", "84.00"),
        ("PRT-002", "Power Regulator", "ELECTRONICS", "62.50"),
        ("PRT-003", "Sensor Assembly", "ELECTRONICS", "47.80"),
        ("PRT-004", "Drive Coupling", "MECHANICAL", "38.20"),
        ("PRT-005", "Bearing Set", "MECHANICAL", "22.40"),
        ("PRT-006", "Precision Valve", "FLUID_CONTROL", "71.60"),
        ("PRT-007", "Pump Housing", "MECHANICAL", "96.30"),
        ("PRT-008", "Thermal Shield", "THERMAL", "55.90"),
        ("PRT-009", "Servo Controller", "ELECTRONICS", "118.00"),
        ("PRT-010", "Optical Encoder", "ELECTRONICS", "103.50"),
        ("PRT-011", "Cable Harness", "ELECTRICAL", "31.20"),
        ("PRT-012", "Structural Bracket", "MECHANICAL", "18.70"),
    ]

    return [
        {
            "part_id": part_id,
            "part_name": part_name,
            "category": category,
            "unit_of_measure": "EA",
            "standard_unit_cost_usd": money(cost),
        }
        for part_id, part_name, category, cost in definitions
    ]


def plant_rows() -> Table:
    """Return deterministic manufacturing and distribution plants."""

    return [
        {
            "plant_id": "PLT-001",
            "plant_name": "Austin Assembly",
            "country_code": "US",
            "region": "NORTH_AMERICA",
            "capacity_class": "LARGE",
        },
        {
            "plant_id": "PLT-002",
            "plant_name": "Berlin Operations",
            "country_code": "DE",
            "region": "EUROPE",
            "capacity_class": "MEDIUM",
        },
        {
            "plant_id": "PLT-003",
            "plant_name": "Pune Manufacturing",
            "country_code": "IN",
            "region": "ASIA_PACIFIC",
            "capacity_class": "LARGE",
        },
        {
            "plant_id": "PLT-004",
            "plant_name": "Monterrey Distribution",
            "country_code": "MX",
            "region": "NORTH_AMERICA",
            "capacity_class": "MEDIUM",
        },
    ]


def supplier_part_rows() -> Table:
    """Return deterministic supplier-to-part sourcing relationships."""

    definitions = [
        ("SUP-001", "PRT-001", 12, "78.00", 100, True),
        ("SUP-001", "PRT-002", 14, "59.00", 100, True),
        ("SUP-001", "PRT-003", 16, "46.20", 120, False),
        ("SUP-002", "PRT-003", 13, "44.90", 100, True),
        ("SUP-002", "PRT-004", 11, "35.50", 150, True),
        ("SUP-002", "PRT-005", 10, "20.80", 200, True),
        ("SUP-003", "PRT-006", 18, "68.40", 100, True),
        ("SUP-003", "PRT-009", 21, "112.00", 80, True),
        ("SUP-003", "PRT-010", 20, "98.50", 80, True),
        ("SUP-004", "PRT-006", 19, "70.20", 100, False),
        ("SUP-004", "PRT-007", 15, "91.50", 80, True),
        ("SUP-004", "PRT-008", 16, "52.20", 100, True),
        ("SUP-005", "PRT-001", 14, "80.30", 100, False),
        ("SUP-005", "PRT-011", 9, "28.70", 150, True),
        ("SUP-005", "PRT-012", 8, "17.10", 250, True),
        ("SUP-006", "PRT-004", 13, "36.40", 150, False),
        ("SUP-006", "PRT-009", 17, "116.50", 80, False),
        ("SUP-006", "PRT-010", 16, "101.00", 80, False),
        ("SUP-007", "PRT-002", 15, "60.10", 100, False),
        ("SUP-007", "PRT-005", 11, "21.30", 200, False),
        ("SUP-008", "PRT-007", 17, "93.00", 80, False),
        ("SUP-008", "PRT-008", 18, "53.80", 100, False),
        ("SUP-008", "PRT-012", 10, "17.80", 250, False),
    ]

    return [
        {
            "supplier_id": supplier_id,
            "part_id": part_id,
            "lead_time_days": lead_time_days,
            "contracted_unit_cost_usd": money(cost),
            "minimum_order_quantity": minimum_order_quantity,
            "primary_supplier_flag": primary_supplier_flag,
        }
        for (
            supplier_id,
            part_id,
            lead_time_days,
            cost,
            minimum_order_quantity,
            primary_supplier_flag,
        ) in definitions
    ]


def purchase_order_rows(
    supplier_parts: Table,
    seed: int,
) -> Table:
    """Generate deterministic inbound purchase orders."""

    rng = random.Random(seed)

    combinations = [
        ("SUP-001", "PRT-001", "PLT-001"),
        ("SUP-002", "PRT-003", "PLT-002"),
        ("SUP-003", "PRT-006", "PLT-001"),
        ("SUP-004", "PRT-007", "PLT-004"),
        ("SUP-005", "PRT-011", "PLT-002"),
        ("SUP-006", "PRT-009", "PLT-003"),
        ("SUP-007", "PRT-002", "PLT-001"),
        ("SUP-008", "PRT-008", "PLT-004"),
        ("SUP-003", "PRT-009", "PLT-003"),
        ("SUP-001", "PRT-002", "PLT-002"),
        ("SUP-002", "PRT-005", "PLT-004"),
        ("SUP-004", "PRT-007", "PLT-002"),
        ("SUP-005", "PRT-012", "PLT-003"),
        ("SUP-006", "PRT-010", "PLT-001"),
        ("SUP-007", "PRT-005", "PLT-002"),
        ("SUP-008", "PRT-012", "PLT-004"),
        ("SUP-001", "PRT-003", "PLT-003"),
        ("SUP-002", "PRT-004", "PLT-001"),
        ("SUP-003", "PRT-010", "PLT-004"),
        ("SUP-004", "PRT-006", "PLT-002"),
        ("SUP-005", "PRT-001", "PLT-001"),
        ("SUP-006", "PRT-004", "PLT-003"),
        ("SUP-007", "PRT-002", "PLT-004"),
        ("SUP-008", "PRT-007", "PLT-002"),
    ]

    supplier_part_index = {
        (row["supplier_id"], row["part_id"]): row
        for row in supplier_parts
    }

    rows: Table = []

    for index, (supplier_id, part_id, plant_id) in enumerate(
        combinations,
        start=1,
    ):
        supplier_part = supplier_part_index[
            (supplier_id, part_id)
        ]

        lead_time_days = int(
            supplier_part["lead_time_days"]
        )

        order_date = date(2026, 7, 1) + timedelta(
            days=(index - 1) * 3
        )

        promised_delivery_date = order_date + timedelta(
            days=lead_time_days
        )

        ordered_units = 400 + ((index * 73) % 500)
        received_units = ordered_units
        status = "RECEIVED"

        if index == 3:
            received_units = 0
            status = "OPEN"
        elif index == 9:
            ordered_units = 700
            received_units = 280
            status = "PARTIAL"
        elif index == 19:
            received_units = 0
            status = "OPEN"

        contracted_cost = Decimal(
            str(
                supplier_part[
                    "contracted_unit_cost_usd"
                ]
            )
        )

        variation = Decimal(
            str(rng.uniform(-0.04, 0.04))
        )

        unit_purchase_cost = money(
            contracted_cost
            * (Decimal("1") + variation)
        )

        freight_cost = money(
            rng.uniform(280, 850)
        )
        duty_cost = money(
            rng.uniform(90, 320)
        )
        handling_cost = money(
            rng.uniform(45, 170)
        )

        # Controlled Scenario E:
        # materially elevated landed cost.
        if index == 12:
            freight_cost = money("4200")
            duty_cost = money("1600")
            handling_cost = money("900")

            unit_purchase_cost = money(
                contracted_cost * Decimal("1.08")
            )

        rows.append(
            {
                "purchase_order_id": f"PO-{index:03d}",
                "supplier_id": supplier_id,
                "plant_id": plant_id,
                "part_id": part_id,
                "order_date": order_date,
                "promised_delivery_date": (
                    promised_delivery_date
                ),
                "ordered_units": ordered_units,
                "received_units": received_units,
                "unit_purchase_cost_usd": (
                    unit_purchase_cost
                ),
                "freight_cost_usd": freight_cost,
                "duty_cost_usd": duty_cost,
                "handling_cost_usd": handling_cost,
                "status": status,
            }
        )

    return rows


def customer_rows() -> Table:
    """Return deterministic synthetic customer accounts."""

    definitions = [
        (
            "CUS-001",
            "Helios Robotics",
            "INDUSTRIAL",
            "US",
            "PRIORITY",
        ),
        (
            "CUS-002",
            "Nova Mobility",
            "AUTOMOTIVE",
            "DE",
            "STANDARD",
        ),
        (
            "CUS-003",
            "Asterion Aerospace",
            "AEROSPACE",
            "IN",
            "STRATEGIC",
        ),
        (
            "CUS-004",
            "Vector Automation",
            "INDUSTRIAL",
            "SG",
            "PRIORITY",
        ),
        (
            "CUS-005",
            "Cobalt Energy",
            "ENERGY",
            "US",
            "STANDARD",
        ),
        (
            "CUS-006",
            "Lumen Medical",
            "MEDICAL",
            "GB",
            "PRIORITY",
        ),
        (
            "CUS-007",
            "Pioneer Defense",
            "AEROSPACE",
            "US",
            "STRATEGIC",
        ),
        (
            "CUS-008",
            "Solace Systems",
            "INDUSTRIAL",
            "FR",
            "STANDARD",
        ),
        (
            "CUS-009",
            "Ionix Mobility",
            "AUTOMOTIVE",
            "JP",
            "PRIORITY",
        ),
        (
            "CUS-010",
            "TerraGrid",
            "ENERGY",
            "AU",
            "STANDARD",
        ),
    ]

    return [
        {
            "customer_id": customer_id,
            "customer_name": customer_name,
            "segment": segment,
            "country_code": country_code,
            "priority_tier": priority_tier,
        }
        for (
            customer_id,
            customer_name,
            segment,
            country_code,
            priority_tier,
        ) in definitions
    ]


def customer_order_rows(
    parts: Table,
    seed: int,
) -> Table:
    """Generate deterministic customer demand."""

    rng = random.Random(seed + 1)

    part_costs = {
        row["part_id"]: Decimal(
            str(row["standard_unit_cost_usd"])
        )
        for row in parts
    }

    rows: Table = []

    for index in range(1, 31):
        customer_id = (
            f"CUS-{((index - 1) % 10) + 1:03d}"
        )
        plant_id = (
            f"PLT-{((index - 1) % 4) + 1:03d}"
        )
        part_id = (
            f"PRT-{((index * 2 - 1) % 12) + 1:03d}"
        )

        # Controlled downstream exposure to
        # parts sourced from disrupted SUP-003.
        if index == 8:
            customer_id = "CUS-003"
            plant_id = "PLT-003"
            part_id = "PRT-009"
        elif index == 9:
            customer_id = "CUS-007"
            plant_id = "PLT-001"
            part_id = "PRT-006"
        elif index == 10:
            customer_id = "CUS-004"
            plant_id = "PLT-004"
            part_id = "PRT-010"

        order_date = date(2026, 8, 1) + timedelta(
            days=(index - 1) * 2
        )

        promised_ship_date = order_date + timedelta(
            days=5
        )

        ordered_units = 60 + ((index * 17) % 140)
        fulfilled_units = ordered_units
        status = "FULFILLED"

        # Controlled Scenario C.
        if index == 8:
            ordered_units = 100
            fulfilled_units = 40
            status = "PARTIAL"
        elif index in {15, 25}:
            fulfilled_units = 0
            status = "OPEN"

        markup = Decimal(
            str(rng.uniform(1.65, 1.95))
        )

        unit_sale_price = money(
            part_costs[part_id] * markup
        )

        rows.append(
            {
                "order_id": f"ORD-{index:03d}",
                "customer_id": customer_id,
                "plant_id": plant_id,
                "part_id": part_id,
                "order_date": order_date,
                "promised_ship_date": (
                    promised_ship_date
                ),
                "ordered_units": ordered_units,
                "fulfilled_units": fulfilled_units,
                "unit_sale_price_usd": (
                    unit_sale_price
                ),
                "status": status,
            }
        )

    return rows


def shipment_rows(
    purchase_orders: Table,
    customer_orders: Table,
) -> Table:
    """Generate deterministic inbound and outbound shipments."""

    rows: Table = []

    for index, purchase_order in enumerate(
        purchase_orders[:12],
        start=1,
    ):
        promised_delivery_date = purchase_order[
            "promised_delivery_date"
        ]

        assert isinstance(
            promised_delivery_date,
            date,
        )

        ship_date = (
            promised_delivery_date
            - timedelta(days=7)
        )

        status = "DELIVERED"
        actual_delivery_date: date | None = (
            promised_delivery_date
        )

        if index == 3:
            status = "DELAYED"
            actual_delivery_date = None

        if index == 9:
            actual_delivery_date = (
                promised_delivery_date
                + timedelta(days=2)
            )

        shipped_units = int(
            purchase_order["ordered_units"]
        )

        if purchase_order["status"] == "PARTIAL":
            shipped_units = int(
                purchase_order["received_units"]
            )

        rows.append(
            {
                "shipment_id": f"SHP-IN-{index:03d}",
                "shipment_type": "INBOUND",
                "purchase_order_id": (
                    purchase_order[
                        "purchase_order_id"
                    ]
                ),
                "customer_order_id": None,
                "part_id": purchase_order["part_id"],
                "plant_id": purchase_order[
                    "plant_id"
                ],
                "supplier_id": purchase_order[
                    "supplier_id"
                ],
                "customer_id": None,
                "ship_date": ship_date,
                "promised_delivery_date": (
                    promised_delivery_date
                ),
                "actual_delivery_date": (
                    actual_delivery_date
                ),
                "shipped_units": shipped_units,
                "carrier": [
                    "NOVA_FREIGHT",
                    "AXIS_LOGISTICS",
                    "ORBIT_CARGO",
                ][(index - 1) % 3],
                "status": status,
            }
        )

    for index, customer_order in enumerate(
        customer_orders[:20],
        start=1,
    ):
        promised_ship_date = customer_order[
            "promised_ship_date"
        ]

        assert isinstance(
            promised_ship_date,
            date,
        )

        ship_date = promised_ship_date

        promised_delivery_date = (
            ship_date + timedelta(days=3)
        )

        status = "DELIVERED"
        actual_delivery_date: date | None = (
            promised_delivery_date
        )

        # Controlled Scenario B.
        if index == 6:
            actual_delivery_date = (
                promised_delivery_date
                + timedelta(days=3)
            )
        elif index == 11:
            actual_delivery_date = (
                promised_delivery_date
                + timedelta(days=1)
            )
        elif index == 15:
            status = "IN_TRANSIT"
            actual_delivery_date = None

        fulfilled_units = int(
            customer_order["fulfilled_units"]
        )
        ordered_units = int(
            customer_order["ordered_units"]
        )

        shipped_units = fulfilled_units

        if status == "IN_TRANSIT" and shipped_units == 0:
            shipped_units = ordered_units

        rows.append(
            {
                "shipment_id": (
                    f"SHP-OUT-{index:03d}"
                ),
                "shipment_type": "OUTBOUND",
                "purchase_order_id": None,
                "customer_order_id": (
                    customer_order["order_id"]
                ),
                "part_id": customer_order["part_id"],
                "plant_id": customer_order[
                    "plant_id"
                ],
                "supplier_id": None,
                "customer_id": customer_order[
                    "customer_id"
                ],
                "ship_date": ship_date,
                "promised_delivery_date": (
                    promised_delivery_date
                ),
                "actual_delivery_date": (
                    actual_delivery_date
                ),
                "shipped_units": shipped_units,
                "carrier": [
                    "ONTARA_EXPRESS",
                    "NOVA_FREIGHT",
                    "AXIS_LOGISTICS",
                ][(index - 1) % 3],
                "status": status,
            }
        )

    return rows


def shipment_event_rows(
    shipments: Table,
) -> Table:
    """Generate ordered shipment lifecycle events."""

    rows: Table = []
    event_counter = 1

    for shipment_index, shipment in enumerate(
        shipments,
        start=1,
    ):
        shipment_id = str(
            shipment["shipment_id"]
        )
        ship_date = shipment["ship_date"]
        promised_delivery_date = shipment[
            "promised_delivery_date"
        ]
        actual_delivery_date = shipment[
            "actual_delivery_date"
        ]
        status = str(shipment["status"])

        assert isinstance(ship_date, date)
        assert isinstance(
            promised_delivery_date,
            date,
        )

        base = datetime.combine(
            ship_date,
            time(hour=8),
        )

        events: list[
            tuple[str, datetime, str | None]
        ] = [
            (
                "CREATED",
                base - timedelta(hours=4),
                None,
            ),
            (
                "PICKED_UP",
                base,
                None,
            ),
            (
                "DEPARTED",
                base + timedelta(hours=4),
                None,
            ),
            (
                "IN_TRANSIT",
                base + timedelta(days=1),
                None,
            ),
        ]

        if status == "DELAYED":
            events.append(
                (
                    "DELAY_REPORTED",
                    datetime.combine(
                        promised_delivery_date,
                        time(hour=9),
                    ),
                    "SUPPLIER_DISRUPTION",
                )
            )

        if status == "DELIVERED":
            assert isinstance(
                actual_delivery_date,
                date,
            )

            if (
                actual_delivery_date
                > promised_delivery_date
            ):
                events.append(
                    (
                        "DELAY_REPORTED",
                        datetime.combine(
                            promised_delivery_date,
                            time(hour=10),
                        ),
                        "TRANSIT_DELAY",
                    )
                )

            events.extend(
                [
                    (
                        "ARRIVED",
                        datetime.combine(
                            actual_delivery_date,
                            time(hour=9),
                        ),
                        None,
                    ),
                    (
                        "DELIVERED",
                        datetime.combine(
                            actual_delivery_date,
                            time(hour=14),
                        ),
                        None,
                    ),
                ]
            )

        events.sort(
            key=lambda event: event[1]
        )

        for sequence, (
            event_type,
            event_timestamp,
            delay_reason,
        ) in enumerate(events, start=1):
            rows.append(
                {
                    "shipment_event_id": (
                        f"EVT-{event_counter:04d}"
                    ),
                    "shipment_id": shipment_id,
                    "event_sequence": sequence,
                    "event_type": event_type,
                    "event_timestamp": (
                        event_timestamp
                    ),
                    "location_code": (
                        "LOC-"
                        f"{((shipment_index - 1) % 8) + 1:02d}"
                    ),
                    "delay_reason": delay_reason,
                    "source_system": (
                        "SYNTHETIC_TMS"
                    ),
                }
            )

            event_counter += 1

    return rows


def inventory_snapshot_rows(
    seed: int,
) -> Table:
    """Generate deterministic plant-part inventory snapshots."""

    rng = random.Random(seed + 2)
    rows: Table = []

    for plant_index in range(1, 5):
        for part_index in range(1, 13):
            plant_id = (
                f"PLT-{plant_index:03d}"
            )
            part_id = (
                f"PRT-{part_index:03d}"
            )

            on_hand_units = rng.randint(
                140,
                520,
            )

            allocated_units = rng.randint(
                20,
                min(
                    120,
                    on_hand_units - 1,
                ),
            )

            in_transit_units = rng.randint(
                30,
                180,
            )

            safety_stock_units = rng.randint(
                35,
                90,
            )

            avg_daily_demand_units = money(
                rng.uniform(6, 28)
            )

            # Controlled Scenario D.
            if (
                plant_id == "PLT-003"
                and part_id == "PRT-009"
            ):
                on_hand_units = 30
                allocated_units = 25
                in_transit_units = 40
                safety_stock_units = 20
                avg_daily_demand_units = money(
                    "12"
                )

            rows.append(
                {
                    "snapshot_date": SNAPSHOT_DATE,
                    "plant_id": plant_id,
                    "part_id": part_id,
                    "on_hand_units": on_hand_units,
                    "allocated_units": allocated_units,
                    "in_transit_units": (
                        in_transit_units
                    ),
                    "safety_stock_units": (
                        safety_stock_units
                    ),
                    "avg_daily_demand_units": (
                        avg_daily_demand_units
                    ),
                }
            )

    return rows


def build_dataset(
    seed: int = DATASET_SEED,
) -> Dataset:
    """Build and validate the complete dataset in memory."""

    suppliers = supplier_rows()
    parts = part_rows()
    plants = plant_rows()
    supplier_parts = supplier_part_rows()

    purchase_orders = purchase_order_rows(
        supplier_parts=supplier_parts,
        seed=seed,
    )

    customers = customer_rows()

    customer_orders = customer_order_rows(
        parts=parts,
        seed=seed,
    )

    shipments = shipment_rows(
        purchase_orders=purchase_orders,
        customer_orders=customer_orders,
    )

    shipment_events = shipment_event_rows(
        shipments
    )

    inventory_snapshots = (
        inventory_snapshot_rows(seed=seed)
    )

    dataset: Dataset = {
        "suppliers": suppliers,
        "parts": parts,
        "plants": plants,
        "supplier_parts": supplier_parts,
        "purchase_orders": purchase_orders,
        "customers": customers,
        "customer_orders": customer_orders,
        "shipments": shipments,
        "shipment_events": shipment_events,
        "inventory_snapshots": (
            inventory_snapshots
        ),
    }

    validate_dataset(dataset)

    return dataset


def _key(
    row: Mapping[str, Any],
    fields: Iterable[str],
) -> tuple[Any, ...]:
    return tuple(
        row[field] for field in fields
    )


def _assert_unique_primary_keys(
    dataset: Dataset,
) -> None:
    for table_name, key_fields in (
        PRIMARY_KEYS.items()
    ):
        seen: set[
            tuple[Any, ...]
        ] = set()

        for row in dataset[table_name]:
            value = _key(
                row,
                key_fields,
            )

            if value in seen:
                raise DatasetContractError(
                    f"{table_name} contains "
                    f"duplicate key {value!r}"
                )

            seen.add(value)


def _assert_foreign_keys(
    dataset: Dataset,
) -> None:
    supplier_ids = {
        row["supplier_id"]
        for row in dataset["suppliers"]
    }

    part_ids = {
        row["part_id"]
        for row in dataset["parts"]
    }

    plant_ids = {
        row["plant_id"]
        for row in dataset["plants"]
    }

    customer_ids = {
        row["customer_id"]
        for row in dataset["customers"]
    }

    po_ids = {
        row["purchase_order_id"]
        for row in dataset["purchase_orders"]
    }

    order_ids = {
        row["order_id"]
        for row in dataset["customer_orders"]
    }

    shipment_ids = {
        row["shipment_id"]
        for row in dataset["shipments"]
    }

    for row in dataset["supplier_parts"]:
        if row["supplier_id"] not in supplier_ids:
            raise DatasetContractError(
                "supplier_parts contains "
                "orphan supplier"
            )

        if row["part_id"] not in part_ids:
            raise DatasetContractError(
                "supplier_parts contains "
                "orphan part"
            )

    for row in dataset["purchase_orders"]:
        if row["supplier_id"] not in supplier_ids:
            raise DatasetContractError(
                "purchase_orders contains "
                "orphan supplier"
            )

        if row["plant_id"] not in plant_ids:
            raise DatasetContractError(
                "purchase_orders contains "
                "orphan plant"
            )

        if row["part_id"] not in part_ids:
            raise DatasetContractError(
                "purchase_orders contains "
                "orphan part"
            )

    for row in dataset["customer_orders"]:
        if row["customer_id"] not in customer_ids:
            raise DatasetContractError(
                "customer_orders contains "
                "orphan customer"
            )

        if row["plant_id"] not in plant_ids:
            raise DatasetContractError(
                "customer_orders contains "
                "orphan plant"
            )

        if row["part_id"] not in part_ids:
            raise DatasetContractError(
                "customer_orders contains "
                "orphan part"
            )

    for row in dataset[
        "inventory_snapshots"
    ]:
        if row["plant_id"] not in plant_ids:
            raise DatasetContractError(
                "inventory_snapshots "
                "contains orphan plant"
            )

        if row["part_id"] not in part_ids:
            raise DatasetContractError(
                "inventory_snapshots "
                "contains orphan part"
            )

    for row in dataset["shipment_events"]:
        if (
            row["shipment_id"]
            not in shipment_ids
        ):
            raise DatasetContractError(
                "shipment_events contains "
                "orphan shipment"
            )

    for row in dataset["shipments"]:
        if row["part_id"] not in part_ids:
            raise DatasetContractError(
                "shipments contains orphan part"
            )

        if row["plant_id"] not in plant_ids:
            raise DatasetContractError(
                "shipments contains orphan plant"
            )

        if row["shipment_type"] == "INBOUND":
            if (
                row["purchase_order_id"]
                not in po_ids
            ):
                raise DatasetContractError(
                    "inbound shipment contains "
                    "invalid purchase order"
                )

            if (
                row["supplier_id"]
                not in supplier_ids
            ):
                raise DatasetContractError(
                    "inbound shipment contains "
                    "invalid supplier"
                )

            if (
                row["customer_order_id"]
                is not None
            ):
                raise DatasetContractError(
                    "inbound shipment "
                    "unexpectedly references "
                    "customer order"
                )

        elif row["shipment_type"] == "OUTBOUND":
            if (
                row["customer_order_id"]
                not in order_ids
            ):
                raise DatasetContractError(
                    "outbound shipment contains "
                    "invalid customer order"
                )

            if (
                row["customer_id"]
                not in customer_ids
            ):
                raise DatasetContractError(
                    "outbound shipment contains "
                    "invalid customer"
                )

            if (
                row["purchase_order_id"]
                is not None
            ):
                raise DatasetContractError(
                    "outbound shipment "
                    "unexpectedly references "
                    "purchase order"
                )

        else:
            raise DatasetContractError(
                "Unsupported shipment type "
                f"{row['shipment_type']!r}"
            )


def _assert_quantity_contracts(
    dataset: Dataset,
) -> None:
    for row in dataset["purchase_orders"]:
        ordered = int(row["ordered_units"])
        received = int(row["received_units"])

        if ordered <= 0:
            raise DatasetContractError(
                "purchase order quantity "
                "must be positive"
            )

        if received < 0 or received > ordered:
            raise DatasetContractError(
                "purchase order received "
                "quantity is invalid"
            )

    for row in dataset["customer_orders"]:
        ordered = int(row["ordered_units"])
        fulfilled = int(
            row["fulfilled_units"]
        )

        if ordered <= 0:
            raise DatasetContractError(
                "customer order quantity "
                "must be positive"
            )

        if (
            fulfilled < 0
            or fulfilled > ordered
        ):
            raise DatasetContractError(
                "customer order fulfilled "
                "quantity is invalid"
            )

    for row in dataset[
        "inventory_snapshots"
    ]:
        numeric_fields = (
            "on_hand_units",
            "allocated_units",
            "in_transit_units",
            "safety_stock_units",
        )

        if any(
            int(row[field]) < 0
            for field in numeric_fields
        ):
            raise DatasetContractError(
                "inventory quantity "
                "cannot be negative"
            )

        if (
            Decimal(
                str(
                    row[
                        "avg_daily_demand_units"
                    ]
                )
            )
            <= 0
        ):
            raise DatasetContractError(
                "average daily demand "
                "must be positive"
            )


def _assert_monetary_contracts(
    dataset: Dataset,
) -> None:
    money_fields = {
        "parts": (
            "standard_unit_cost_usd",
        ),
        "supplier_parts": (
            "contracted_unit_cost_usd",
        ),
        "purchase_orders": (
            "unit_purchase_cost_usd",
            "freight_cost_usd",
            "duty_cost_usd",
            "handling_cost_usd",
        ),
        "customer_orders": (
            "unit_sale_price_usd",
        ),
    }

    for table_name, fields in (
        money_fields.items()
    ):
        for row in dataset[table_name]:
            for field in fields:
                if (
                    Decimal(str(row[field]))
                    < 0
                ):
                    raise DatasetContractError(
                        f"{table_name}.{field} "
                        "cannot be negative"
                    )


def _assert_shipment_contracts(
    dataset: Dataset,
) -> None:
    purchase_orders = {
        row["purchase_order_id"]: row
        for row in dataset[
            "purchase_orders"
        ]
    }

    customer_orders = {
        row["order_id"]: row
        for row in dataset[
            "customer_orders"
        ]
    }

    for row in dataset["shipments"]:
        ship_date = row["ship_date"]
        actual_delivery_date = row[
            "actual_delivery_date"
        ]

        assert isinstance(
            ship_date,
            date,
        )

        if int(row["shipped_units"]) < 0:
            raise DatasetContractError(
                "shipment quantity "
                "cannot be negative"
            )

        if (
            row["status"] == "DELIVERED"
            and actual_delivery_date is None
        ):
            raise DatasetContractError(
                "delivered shipment must have "
                "actual delivery date"
            )

        if (
            row["status"] != "DELIVERED"
            and actual_delivery_date is not None
        ):
            raise DatasetContractError(
                "undelivered shipment cannot "
                "have actual delivery date"
            )

        if actual_delivery_date is not None:
            assert isinstance(
                actual_delivery_date,
                date,
            )

            if (
                actual_delivery_date
                < ship_date
            ):
                raise DatasetContractError(
                    "shipment actual delivery "
                    "precedes ship date"
                )

        if row["shipment_type"] == "INBOUND":
            purchase_order = purchase_orders[
                row["purchase_order_id"]
            ]

            for field in (
                "supplier_id",
                "plant_id",
                "part_id",
            ):
                if (
                    row[field]
                    != purchase_order[field]
                ):
                    raise DatasetContractError(
                        "inbound shipment "
                        "disagrees with PO "
                        f"on {field}"
                    )

        if row["shipment_type"] == "OUTBOUND":
            customer_order = customer_orders[
                row["customer_order_id"]
            ]

            comparisons = {
                "customer_id": "customer_id",
                "plant_id": "plant_id",
                "part_id": "part_id",
            }

            for (
                shipment_field,
                order_field,
            ) in comparisons.items():
                if (
                    row[shipment_field]
                    != customer_order[
                        order_field
                    ]
                ):
                    raise DatasetContractError(
                        "outbound shipment "
                        "disagrees with "
                        "customer order on "
                        f"{shipment_field}"
                    )


def _assert_event_contracts(
    dataset: Dataset,
) -> None:
    grouped: dict[
        str,
        list[dict[str, Any]],
    ] = {}

    for event in dataset[
        "shipment_events"
    ]:
        grouped.setdefault(
            str(event["shipment_id"]),
            [],
        ).append(event)

    for shipment in dataset["shipments"]:
        shipment_id = str(
            shipment["shipment_id"]
        )

        events = grouped.get(shipment_id)

        if not events:
            raise DatasetContractError(
                f"{shipment_id} has no "
                "shipment events"
            )

        events.sort(
            key=lambda event: int(
                event["event_sequence"]
            )
        )

        sequences = [
            int(event["event_sequence"])
            for event in events
        ]

        expected_sequences = list(
            range(1, len(events) + 1)
        )

        if sequences != expected_sequences:
            raise DatasetContractError(
                f"{shipment_id} contains "
                "invalid event sequence"
            )

        timestamps = [
            event["event_timestamp"]
            for event in events
        ]

        if timestamps != sorted(timestamps):
            raise DatasetContractError(
                f"{shipment_id} contains "
                "out-of-order event "
                "timestamps"
            )

        event_types = [
            str(event["event_type"])
            for event in events
        ]

        if (
            shipment["status"]
            == "DELIVERED"
            and event_types[-1]
            != "DELIVERED"
        ):
            raise DatasetContractError(
                f"{shipment_id} is delivered "
                "without final DELIVERED event"
            )

        if (
            shipment["status"] == "DELAYED"
            and "DELAY_REPORTED"
            not in event_types
        ):
            raise DatasetContractError(
                f"{shipment_id} is delayed "
                "without delay event"
            )


def _assert_controlled_scenarios(
    dataset: Dataset,
) -> None:
    suppliers = {
        row["supplier_id"]: row
        for row in dataset["suppliers"]
    }

    customers = {
        row["customer_id"]: row
        for row in dataset["customers"]
    }

    orders = {
        row["order_id"]: row
        for row in dataset[
            "customer_orders"
        ]
    }

    shipments = {
        row["shipment_id"]: row
        for row in dataset["shipments"]
    }

    purchase_orders = {
        row["purchase_order_id"]: row
        for row in dataset[
            "purchase_orders"
        ]
    }

    disrupted_supplier = suppliers[
        "SUP-003"
    ]

    if (
        disrupted_supplier["status"]
        != "DISRUPTED"
    ):
        raise DatasetContractError(
            "SUP-003 disruption scenario "
            "is missing"
        )

    disrupted_parts = {
        row["part_id"]
        for row in dataset[
            "supplier_parts"
        ]
        if row["supplier_id"] == "SUP-003"
    }

    if len(disrupted_parts) < 2:
        raise DatasetContractError(
            "SUP-003 must supply "
            "multiple parts"
        )

    alternate_exists = any(
        row["part_id"] in disrupted_parts
        and row["supplier_id"]
        != "SUP-003"
        and suppliers[
            row["supplier_id"]
        ]["status"]
        == "ACTIVE"
        for row in dataset[
            "supplier_parts"
        ]
    )

    if not alternate_exists:
        raise DatasetContractError(
            "disrupted supplier requires "
            "an active alternate supplier"
        )

    late_shipment = shipments[
        "SHP-OUT-006"
    ]

    if not (
        late_shipment["status"]
        == "DELIVERED"
        and late_shipment[
            "actual_delivery_date"
        ]
        > late_shipment[
            "promised_delivery_date"
        ]
    ):
        raise DatasetContractError(
            "SHP-OUT-006 late delivery "
            "scenario is missing"
        )

    partial_order = orders["ORD-008"]

    if not (
        0
        < int(
            partial_order[
                "fulfilled_units"
            ]
        )
        < int(
            partial_order[
                "ordered_units"
            ]
        )
    ):
        raise DatasetContractError(
            "ORD-008 partial fulfillment "
            "scenario is missing"
        )

    shortage = next(
        row
        for row in dataset[
            "inventory_snapshots"
        ]
        if (
            row["plant_id"] == "PLT-003"
            and row["part_id"]
            == "PRT-009"
        )
    )

    available_inventory = (
        int(shortage["on_hand_units"])
        - int(shortage["allocated_units"])
    )

    if (
        available_inventory
        >= int(
            shortage[
                "safety_stock_units"
            ]
        )
    ):
        raise DatasetContractError(
            "PLT-003 + PRT-009 shortage "
            "scenario is missing"
        )

    expensive_po = purchase_orders[
        "PO-012"
    ]

    accessory_cost = (
        Decimal(
            str(
                expensive_po[
                    "freight_cost_usd"
                ]
            )
        )
        + Decimal(
            str(
                expensive_po[
                    "duty_cost_usd"
                ]
            )
        )
        + Decimal(
            str(
                expensive_po[
                    "handling_cost_usd"
                ]
            )
        )
    )

    if accessory_cost < Decimal("5000"):
        raise DatasetContractError(
            "PO-012 landed-cost variance "
            "scenario is missing"
        )

    if (
        partial_order["part_id"]
        not in disrupted_parts
    ):
        raise DatasetContractError(
            "ORD-008 is not exposed "
            "to the disrupted supplier"
        )

    if (
        customers[
            partial_order["customer_id"]
        ]["priority_tier"]
        != "STRATEGIC"
    ):
        raise DatasetContractError(
            "disruption must expose "
            "a strategic customer"
        )


def _assert_expected_shape(
    dataset: Dataset,
) -> None:
    if tuple(dataset) != TABLE_ORDER:
        raise DatasetContractError(
            "dataset table set or ordering "
            "differs from contract"
        )

    expected_counts = {
        "suppliers": 8,
        "parts": 12,
        "plants": 4,
        "supplier_parts": 23,
        "purchase_orders": 24,
        "customers": 10,
        "customer_orders": 30,
        "shipments": 32,
        "inventory_snapshots": 48,
    }

    for (
        table_name,
        expected_count,
    ) in expected_counts.items():
        actual_count = len(
            dataset[table_name]
        )

        if actual_count != expected_count:
            raise DatasetContractError(
                f"{table_name} expected "
                f"{expected_count} rows, "
                f"received {actual_count}"
            )


def validate_dataset(
    dataset: Dataset,
) -> None:
    """Validate all data contracts before persistence."""

    _assert_expected_shape(dataset)
    _assert_unique_primary_keys(dataset)
    _assert_foreign_keys(dataset)
    _assert_quantity_contracts(dataset)
    _assert_monetary_contracts(dataset)
    _assert_shipment_contracts(dataset)
    _assert_event_contracts(dataset)
    _assert_controlled_scenarios(dataset)


def _serialize(value: Any) -> str:
    if value is None:
        return ""

    if isinstance(value, bool):
        return (
            "true"
            if value
            else "false"
        )

    if isinstance(value, (date, datetime)):
        return value.isoformat()

    if isinstance(value, Decimal):
        return format(value, "f")

    return str(value)


def write_table(
    table_name: str,
    rows: Table,
    output_dir: Path,
) -> Path:
    """Write one table atomically using stable UTF-8 CSV."""

    if not rows:
        raise DatasetContractError(
            f"cannot write empty table "
            f"{table_name}"
        )

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    target = (
        output_dir / f"{table_name}.csv"
    )

    temporary = (
        output_dir
        / f".{table_name}.csv.tmp"
    )

    fieldnames = list(
        rows[0].keys()
    )

    try:
        with temporary.open(
            "w",
            encoding="utf-8",
            newline="",
        ) as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=fieldnames,
                lineterminator="\n",
                extrasaction="raise",
            )

            writer.writeheader()

            for row in rows:
                writer.writerow(
                    {
                        field: _serialize(
                            row[field]
                        )
                        for field in fieldnames
                    }
                )

        temporary.replace(target)

    finally:
        if temporary.exists():
            temporary.unlink()

    return target


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest for one generated file."""

    digest = hashlib.sha256()

    with path.open("rb") as handle:
        for chunk in iter(
            lambda: handle.read(
                64 * 1024
            ),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def write_dataset(
    dataset: Dataset,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
) -> dict[str, Path]:
    """Persist all dataset tables after validation."""

    validate_dataset(dataset)

    written: dict[str, Path] = {}

    for table_name in TABLE_ORDER:
        written[table_name] = write_table(
            table_name=table_name,
            rows=dataset[table_name],
            output_dir=output_dir,
        )

    return written


def print_summary(
    dataset: Dataset,
    files: Mapping[str, Path],
) -> None:
    """Print concise generation and reproducibility evidence."""

    print(
        "Ontara synthetic dataset "
        f"v{DATASET_VERSION} "
        f"(seed={DATASET_SEED})"
    )

    print(
        f"Output: {DEFAULT_OUTPUT_DIR}"
    )

    print()

    for table_name in TABLE_ORDER:
        file_path = files[table_name]
        digest = sha256_file(file_path)

        print(
            f"{table_name:22} "
            f"rows="
            f"{len(dataset[table_name]):>3} "
            f"sha256={digest[:16]}"
        )

    print()
    print("Dataset contracts: PASS")


def main() -> None:
    """Generate, validate, persist, and summarize the dataset."""

    dataset = build_dataset(
        seed=DATASET_SEED
    )

    files = write_dataset(
        dataset=dataset,
        output_dir=DEFAULT_OUTPUT_DIR,
    )

    print_summary(
        dataset=dataset,
        files=files,
    )


if __name__ == "__main__":
    main()