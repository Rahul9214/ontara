# Ontara Synthetic Supply Network Dataset Manifest

## Purpose

Ontara uses a deterministic synthetic supply-chain dataset to demonstrate governed analytics,
ontology traversal, metric consistency, disruption analysis, and persisted operational actions.

The dataset is intentionally designed rather than randomly fabricated.

Every entity, relationship, metric input, and controlled exception exists to support one or more
product capabilities, automated tests, or hackathon demonstrations.

## Design Principles

The synthetic dataset must be:

- deterministic,
- reproducible,
- referentially valid,
- explainable,
- small enough for rapid local and Snowflake execution,
- rich enough to exercise meaningful supply-chain scenarios,
- suitable for canonical metric validation,
- suitable for ontology traversal,
- free of real customer, supplier, or personally identifiable data.

Random generation may be used only where it does not affect controlled business scenarios.

The generator must always produce identical outputs for the same dataset version and seed.

## Dataset Version

- Dataset version: `1.0.0`
- Generator seed: `20261005`
- Currency: `USD`
- Quantity unit: `EA`
- Synthetic operational window: `2026-07-01` through `2026-09-30`
- Canonical snapshot date: `2026-09-30`

## Output Location

Generated files are written to:

`data/synthetic/generated/`

Generated CSV files are reproducible build artifacts and are not treated as manually maintained
source files.

The authoritative source is the generator implementation and its tests.

## Core Ontology

Ontara's primary governed supply-chain path is:

`Supplier -> Part -> Plant -> Shipment -> Order -> Customer`

Supporting operational entities are:

- Purchase Order
- Inventory Snapshot
- Shipment Event
- Supply Exception

`Supply Exception` is created later by Ontara's governed action workflow and is not generated as
a source-system dataset in this feature.

## Dataset Tables

### suppliers.csv

Represents the supplier master.

Fields:

| Field           | Type   | Description                |
| --------------- | ------ | -------------------------- |
| `supplier_id`   | string | Stable supplier identifier |
| `supplier_name` | string | Synthetic supplier name    |
| `country_code`  | string | ISO-style country code     |
| `risk_tier`     | string | `LOW`, `MEDIUM`, or `HIGH` |
| `status`        | string | `ACTIVE` or `DISRUPTED`    |

Identifier format:

`SUP-001`

Target size:

`8` suppliers.

---

### parts.csv

Represents the governed part master.

Fields:

| Field                    | Type    | Description                  |
| ------------------------ | ------- | ---------------------------- |
| `part_id`                | string  | Stable part identifier       |
| `part_name`              | string  | Synthetic part name          |
| `category`               | string  | Part category                |
| `unit_of_measure`        | string  | `EA`                         |
| `standard_unit_cost_usd` | decimal | Standard reference unit cost |

Identifier format:

`PRT-001`

Target size:

`12` parts.

---

### plants.csv

Represents manufacturing or distribution plants.

Fields:

| Field            | Type   | Description                   |
| ---------------- | ------ | ----------------------------- |
| `plant_id`       | string | Stable plant identifier       |
| `plant_name`     | string | Synthetic plant name          |
| `country_code`   | string | Plant country                 |
| `region`         | string | Operating region              |
| `capacity_class` | string | `SMALL`, `MEDIUM`, or `LARGE` |

Identifier format:

`PLT-001`

Target size:

`4` plants.

---

### supplier_parts.csv

Defines which suppliers can provide which parts to the network.

Fields:

| Field                      | Type    | Description                                   |
| -------------------------- | ------- | --------------------------------------------- |
| `supplier_id`              | string  | Supplier foreign key                          |
| `part_id`                  | string  | Part foreign key                              |
| `lead_time_days`           | integer | Contracted lead time                          |
| `contracted_unit_cost_usd` | decimal | Contracted purchase cost                      |
| `minimum_order_quantity`   | integer | Minimum order quantity                        |
| `primary_supplier_flag`    | boolean | Whether this supplier is primary for the part |

Expected relationships:

- some parts have one supplier,
- some parts have multiple suppliers,
- at least one disrupted supplier supplies multiple parts.

This is essential for blast-radius and alternative-supplier analysis.

Target size:

Approximately `20` mappings.

---

### purchase_orders.csv

Represents inbound procurement demand.

Fields:

| Field                    | Type    | Description                      |
| ------------------------ | ------- | -------------------------------- |
| `purchase_order_id`      | string  | Stable purchase order identifier |
| `supplier_id`            | string  | Supplier foreign key             |
| `plant_id`               | string  | Receiving plant foreign key      |
| `part_id`                | string  | Ordered part foreign key         |
| `order_date`             | date    | PO creation date                 |
| `promised_delivery_date` | date    | Contracted delivery date         |
| `ordered_units`          | integer | Ordered quantity                 |
| `received_units`         | integer | Quantity received                |
| `unit_purchase_cost_usd` | decimal | Actual purchase cost per unit    |
| `freight_cost_usd`       | decimal | Shipment freight cost            |
| `duty_cost_usd`          | decimal | Import or customs cost           |
| `handling_cost_usd`      | decimal | Handling cost                    |
| `status`                 | string  | `OPEN`, `PARTIAL`, or `RECEIVED` |

Identifier format:

`PO-001`

Target size:

Approximately `24` purchase orders.

---

### customers.csv

Represents synthetic customer accounts.

Fields:

| Field           | Type   | Description                            |
| --------------- | ------ | -------------------------------------- |
| `customer_id`   | string | Stable customer identifier             |
| `customer_name` | string | Synthetic customer name                |
| `segment`       | string | Customer segment                       |
| `country_code`  | string | Customer country                       |
| `priority_tier` | string | `STANDARD`, `PRIORITY`, or `STRATEGIC` |

Identifier format:

`CUS-001`

Target size:

`10` customers.

---

### customer_orders.csv

Represents customer demand fulfilled from Ontara plants.

Fields:

| Field                 | Type    | Description                                    |
| --------------------- | ------- | ---------------------------------------------- |
| `order_id`            | string  | Stable customer order identifier               |
| `customer_id`         | string  | Customer foreign key                           |
| `plant_id`            | string  | Fulfilling plant foreign key                   |
| `part_id`             | string  | Requested part foreign key                     |
| `order_date`          | date    | Order creation date                            |
| `promised_ship_date`  | date    | Promised shipment date                         |
| `ordered_units`       | integer | Requested quantity                             |
| `fulfilled_units`     | integer | Fulfilled quantity                             |
| `unit_sale_price_usd` | decimal | Revenue per unit                               |
| `status`              | string  | `OPEN`, `PARTIAL`, `FULFILLED`, or `CANCELLED` |

Identifier format:

`ORD-001`

Target size:

Approximately `30` customer orders.

---

### shipments.csv

Represents both inbound and outbound physical movements.

Fields:

| Field                    | Type        | Description                                          |
| ------------------------ | ----------- | ---------------------------------------------------- |
| `shipment_id`            | string      | Stable shipment identifier                           |
| `shipment_type`          | string      | `INBOUND` or `OUTBOUND`                              |
| `purchase_order_id`      | string/null | Inbound PO foreign key                               |
| `customer_order_id`      | string/null | Outbound order foreign key                           |
| `part_id`                | string      | Part foreign key                                     |
| `plant_id`               | string      | Relevant plant foreign key                           |
| `supplier_id`            | string/null | Supplier for inbound shipment                        |
| `customer_id`            | string/null | Customer for outbound shipment                       |
| `ship_date`              | date        | Shipment departure date                              |
| `promised_delivery_date` | date        | Promised delivery date                               |
| `actual_delivery_date`   | date/null   | Actual delivery date                                 |
| `shipped_units`          | integer     | Quantity shipped                                     |
| `carrier`                | string      | Synthetic carrier                                    |
| `status`                 | string      | `IN_TRANSIT`, `DELIVERED`, `DELAYED`, or `CANCELLED` |

Identifier formats:

`SHP-IN-001`

`SHP-OUT-001`

Target size:

Approximately `32` shipments.

---

### shipment_events.csv

Represents shipment lifecycle events.

Fields:

| Field               | Type        | Description                        |
| ------------------- | ----------- | ---------------------------------- |
| `shipment_event_id` | string      | Stable event identifier            |
| `shipment_id`       | string      | Shipment foreign key               |
| `event_sequence`    | integer     | Ordered sequence within shipment   |
| `event_type`        | string      | Lifecycle event                    |
| `event_timestamp`   | timestamp   | Event occurrence time              |
| `location_code`     | string      | Synthetic operational location     |
| `delay_reason`      | string/null | Governed delay reason              |
| `source_system`     | string      | Synthetic source-system identifier |

Typical event types:

- `CREATED`
- `PICKED_UP`
- `DEPARTED`
- `IN_TRANSIT`
- `DELAY_REPORTED`
- `ARRIVED`
- `DELIVERED`

Every shipment must have an ordered event history consistent with its current status.

---

### inventory_snapshots.csv

Represents plant and part inventory positions.

Fields:

| Field                    | Type    | Description                       |
| ------------------------ | ------- | --------------------------------- |
| `snapshot_date`          | date    | Inventory snapshot date           |
| `plant_id`               | string  | Plant foreign key                 |
| `part_id`                | string  | Part foreign key                  |
| `on_hand_units`          | integer | Physical stock                    |
| `allocated_units`        | integer | Stock already allocated           |
| `in_transit_units`       | integer | Confirmed inbound inventory       |
| `safety_stock_units`     | integer | Minimum safety-stock level        |
| `avg_daily_demand_units` | decimal | Governed trailing demand baseline |

The dataset must contain both healthy and constrained inventory positions.

## Canonical Metric Inputs

The dataset must support the four challenge metrics without hidden constants or manually
overridden answers.

### On-Time Delivery

Shipment-level definition:

`on_time_delivery = delivered_on_or_before_promised_date / delivered_shipments`

Required fields:

- `promised_delivery_date`
- `actual_delivery_date`
- `status`

Both on-time and late delivered shipments must exist.

### Fill Rate

Quantity-weighted order definition:

`fill_rate = total_fulfilled_units / total_ordered_units`

Required fields:

- `ordered_units`
- `fulfilled_units`

The dataset must contain:

- fully fulfilled orders,
- partially fulfilled orders,
- open orders.

### Days of Inventory

Definition:

`days_of_inventory = available_inventory_units / avg_daily_demand_units`

Where:

`available_inventory_units = on_hand_units - allocated_units`

Required fields:

- `on_hand_units`
- `allocated_units`
- `avg_daily_demand_units`

The generator must prevent division by zero.

### Landed Cost

Purchase-order definition:

`landed_cost = purchase_cost + freight_cost + duty_cost + handling_cost`

Where:

`purchase_cost = received_units * unit_purchase_cost_usd`

Required fields:

- `received_units`
- `unit_purchase_cost_usd`
- `freight_cost_usd`
- `duty_cost_usd`
- `handling_cost_usd`

At least one PO must intentionally have a materially higher landed cost than its comparable
baseline.

## Controlled Business Scenarios

The following scenarios must be created deliberately and remain stable between runs.

### Scenario A — Supplier Disruption

Supplier:

`SUP-003`

Requirements:

- status is `DISRUPTED`,
- supplies more than one part,
- supplies at least one part used at more than one plant,
- has open or delayed inbound supply,
- links through affected inventory to downstream customer demand.

Purpose:

Supports Ontology Blast Radius.

Expected traversal:

`Supplier -> Part -> Plant -> Shipment -> Order -> Customer`

---

### Scenario B — Late Delivery

At least one delivered outbound shipment must have:

`actual_delivery_date > promised_delivery_date`

A stable shipment identifier must be reserved for this scenario.

Preferred identifier:

`SHP-OUT-006`

Purpose:

Supports On-Time Delivery validation and conversational explanation.

---

### Scenario C — Partial Fulfillment

At least one customer order must have:

`0 < fulfilled_units < ordered_units`

Preferred identifier:

`ORD-008`

Purpose:

Supports Fill Rate validation and shortage explanation.

---

### Scenario D — Inventory Shortage

The combination:

`PLT-003 + PRT-009`

must have available inventory below safety stock.

That means:

`on_hand_units - allocated_units < safety_stock_units`

Purpose:

Supports inventory-risk analysis and Days of Inventory reasoning.

---

### Scenario E — Landed Cost Variance

Preferred purchase order:

`PO-012`

must have materially higher freight, duty, or handling cost than comparable purchase orders.

Purpose:

Supports Landed Cost reasoning and explainability.

---

### Scenario F — Alternate Supplier

At least one disrupted part supplied by `SUP-003` must also have an alternate active supplier.

Purpose:

Allows Ontara to later recommend a governed alternative rather than merely reporting the
disruption.

---

### Scenario G — Strategic Customer Exposure

At least one downstream customer affected by the `SUP-003` disruption must have:

`priority_tier = STRATEGIC`

Purpose:

Allows blast-radius analysis to rank business impact rather than only counting records.

## Referential Integrity Contracts

The generator and automated tests must guarantee:

1. every `supplier_parts.supplier_id` exists in `suppliers`,
2. every `supplier_parts.part_id` exists in `parts`,
3. every purchase order references a valid supplier, plant, and part,
4. every customer order references a valid customer, plant, and part,
5. every shipment references valid business entities,
6. every shipment event references an existing shipment,
7. every inventory snapshot references an existing plant and part,
8. inbound shipments reference purchase orders,
9. outbound shipments reference customer orders,
10. inbound shipment supplier and part values agree with their purchase order,
11. outbound shipment customer, plant, and part values agree with their customer order,
12. fulfilled quantities never exceed ordered quantities,
13. received quantities never exceed ordered purchase quantities,
14. delivered shipments contain an actual delivery date,
15. undelivered shipments do not fabricate an actual delivery date.

## Determinism Contracts

Running the generator repeatedly with the same dataset version and seed must produce:

- identical row counts,
- identical identifiers,
- identical controlled scenarios,
- identical canonical metric inputs,
- identical CSV ordering,
- identical file contents.

The generator must not use current wall-clock time.

Dates must derive from fixed dataset configuration.

## Data Quality Contracts

The following must never occur:

- duplicate primary identifiers,
- orphan foreign keys,
- negative quantities,
- negative monetary values,
- zero or negative average daily demand,
- fulfilled quantity greater than ordered quantity,
- received quantity greater than PO quantity,
- delivered shipment without actual delivery date,
- actual delivery date before ship date,
- impossible shipment-event ordering.

## Privacy and Safety

All records are synthetic.

The dataset must not contain:

- real people,
- real customer information,
- real supplier confidential information,
- credentials,
- API keys,
- production identifiers,
- copied proprietary datasets.

## Generator Contract

The dataset generator will live at:

`scripts/generate_synthetic_data.py`

It must:

1. create all required output directories,
2. generate every dataset deterministically,
3. validate referential integrity before writing output,
4. write stable UTF-8 CSV files,
5. preserve deterministic row ordering,
6. fail loudly if a contract is violated,
7. print a concise generation summary,
8. support repeatable execution from the repository root.

Planned command:

```bash
uv run python scripts/generate_synthetic_data.py
```
