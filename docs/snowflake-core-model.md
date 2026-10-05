# Snowflake Core Model

## Purpose

This document defines the Snowflake object contract for Ontara's governed supply-chain
foundation.

The goal of this feature is to move Ontara's deterministic synthetic supply network from local
reproducible CSV generation into governed Snowflake RAW and CORE layers.

This feature establishes:

- database and schema boundaries,
- warehouse configuration,
- development-role responsibilities,
- deterministic local-file ingestion,
- raw source representations,
- normalized core entities,
- relationship integrity,
- repeatable reload behavior,
- SQL validation contracts.

This feature does not yet implement:

- semantic views,
- Cortex Agent configuration,
- conversational analytics,
- Semantic Contract Verifier,
- Ontology Blast Radius UI,
- governed operational actions,
- Streamlit application behavior.

Those capabilities depend on a stable CORE layer and are implemented in later features.

## Target Snowflake Environment

Current event environment:

- Organization: `OIVNDBA`
- Account: `YL85787`
- Account locator: `KS20773`
- Region: `AWS_AP_NORTHEAST_1`
- Current bootstrap role: `ACCOUNTADMIN`

Application development must move away from `ACCOUNTADMIN` after bootstrap.

## Database

Primary database:

`ONTARA`

The database contains the following schemas:

- `RAW`
- `CORE`
- `SEMANTIC`
- `GOVERNANCE`
- `APP`

Only `RAW` and `CORE` receive application objects in this feature.

`SEMANTIC`, `GOVERNANCE`, and `APP` are created during bootstrap so the application boundary is
stable, but their feature-specific objects are introduced later.

## Warehouse

Development warehouse:

`ONTARA_WH`

Baseline configuration:

- size: `XSMALL`
- auto suspend: `60` seconds
- auto resume: enabled
- initially suspended: enabled

The hackathon dataset is intentionally small. An X-Small warehouse is sufficient and avoids
unnecessary credit consumption.

The architecture must not depend on a larger warehouse size.

## Development Role

Role:

`ONTARA_DEV_ROLE`

Purpose:

- normal Ontara SQL development,
- data loading,
- governed object creation within permitted schemas,
- application execution during development.

`ACCOUNTADMIN` is used only for bootstrap operations that require account-level authority.

After bootstrap, normal feature execution should use `ONTARA_DEV_ROLE` wherever supported.

## Schema Responsibilities

### ONTARA.RAW

Purpose:

Preserve source-oriented synthetic supply-chain representations as loaded from deterministic
CSV files.

Responsibilities:

- ingestion boundary,
- source-compatible columns,
- minimal transformation,
- deterministic reload,
- traceability to generated files.

RAW does not define business metrics.

RAW does not reinterpret source meaning.

### ONTARA.CORE

Purpose:

Provide typed, normalized, governed supply-chain entities and relationships.

Responsibilities:

- canonical data types,
- normalized identifiers,
- validated relationships,
- reusable ontology-ready entities,
- stable downstream contract for semantic analytics.

CORE is the authoritative relational foundation for later semantic views.

### ONTARA.SEMANTIC

Purpose:

Future governed semantic definitions, canonical metrics, dimensions, relationships, and
verified analytical behavior.

No semantic objects are implemented in this feature.

### ONTARA.GOVERNANCE

Purpose:

Future persisted governance and operational-action records, including supply exceptions and
audit state.

No governance workflow tables are implemented in this feature.

### ONTARA.APP

Purpose:

Future application-supporting state required by the Streamlit experience.

No application state objects are implemented in this feature.

## Local Data Source

The authoritative synthetic source generator is:

`scripts/generate_synthetic_data.py`

Generated local files are written to:

`data/synthetic/generated/`

The generator produces:

1. `suppliers.csv`
2. `parts.csv`
3. `plants.csv`
4. `supplier_parts.csv`
5. `purchase_orders.csv`
6. `customers.csv`
7. `customer_orders.csv`
8. `shipments.csv`
9. `shipment_events.csv`
10. `inventory_snapshots.csv`

Generated CSV files remain reproducible build artifacts and are not committed to Git.

## Snowflake File Format

Named file format:

`ONTARA.RAW.ONTARA_CSV_FORMAT`

Required behavior:

- type: CSV,
- one header row skipped,
- comma field delimiter,
- optional double-quoted fields supported,
- empty fields interpreted as SQL `NULL`,
- UTF-8 encoding,
- invalid column counts fail loading,
- invalid UTF-8 fails loading.

The loading contract must favor correctness over silently accepting malformed files.

## Snowflake Internal Stage

Named internal stage:

`ONTARA.RAW.SYNTHETIC_STAGE`

Purpose:

Receive deterministic CSV files generated locally before RAW ingestion.

The stage uses:

`ONTARA.RAW.ONTARA_CSV_FORMAT`

Local files are uploaded using Snowflake's supported local-file staging workflow.

The stage is not a source of truth.

The generator remains the reproducible source of truth.

## RAW Tables

RAW tables intentionally preserve source-compatible field names.

### ONTARA.RAW.SUPPLIERS

Columns:

- `SUPPLIER_ID`
- `SUPPLIER_NAME`
- `COUNTRY_CODE`
- `RISK_TIER`
- `STATUS`

### ONTARA.RAW.PARTS

Columns:

- `PART_ID`
- `PART_NAME`
- `CATEGORY`
- `UNIT_OF_MEASURE`
- `STANDARD_UNIT_COST_USD`

### ONTARA.RAW.PLANTS

Columns:

- `PLANT_ID`
- `PLANT_NAME`
- `COUNTRY_CODE`
- `REGION`
- `CAPACITY_CLASS`

### ONTARA.RAW.SUPPLIER_PARTS

Columns:

- `SUPPLIER_ID`
- `PART_ID`
- `LEAD_TIME_DAYS`
- `CONTRACTED_UNIT_COST_USD`
- `MINIMUM_ORDER_QUANTITY`
- `PRIMARY_SUPPLIER_FLAG`

### ONTARA.RAW.PURCHASE_ORDERS

Columns:

- `PURCHASE_ORDER_ID`
- `SUPPLIER_ID`
- `PLANT_ID`
- `PART_ID`
- `ORDER_DATE`
- `PROMISED_DELIVERY_DATE`
- `ORDERED_UNITS`
- `RECEIVED_UNITS`
- `UNIT_PURCHASE_COST_USD`
- `FREIGHT_COST_USD`
- `DUTY_COST_USD`
- `HANDLING_COST_USD`
- `STATUS`

### ONTARA.RAW.CUSTOMERS

Columns:

- `CUSTOMER_ID`
- `CUSTOMER_NAME`
- `SEGMENT`
- `COUNTRY_CODE`
- `PRIORITY_TIER`

### ONTARA.RAW.CUSTOMER_ORDERS

Columns:

- `ORDER_ID`
- `CUSTOMER_ID`
- `PLANT_ID`
- `PART_ID`
- `ORDER_DATE`
- `PROMISED_SHIP_DATE`
- `ORDERED_UNITS`
- `FULFILLED_UNITS`
- `UNIT_SALE_PRICE_USD`
- `STATUS`

### ONTARA.RAW.SHIPMENTS

Columns:

- `SHIPMENT_ID`
- `SHIPMENT_TYPE`
- `PURCHASE_ORDER_ID`
- `CUSTOMER_ORDER_ID`
- `PART_ID`
- `PLANT_ID`
- `SUPPLIER_ID`
- `CUSTOMER_ID`
- `SHIP_DATE`
- `PROMISED_DELIVERY_DATE`
- `ACTUAL_DELIVERY_DATE`
- `SHIPPED_UNITS`
- `CARRIER`
- `STATUS`

### ONTARA.RAW.SHIPMENT_EVENTS

Columns:

- `SHIPMENT_EVENT_ID`
- `SHIPMENT_ID`
- `EVENT_SEQUENCE`
- `EVENT_TYPE`
- `EVENT_TIMESTAMP`
- `LOCATION_CODE`
- `DELAY_REASON`
- `SOURCE_SYSTEM`

### ONTARA.RAW.INVENTORY_SNAPSHOTS

Columns:

- `SNAPSHOT_DATE`
- `PLANT_ID`
- `PART_ID`
- `ON_HAND_UNITS`
- `ALLOCATED_UNITS`
- `IN_TRANSIT_UNITS`
- `SAFETY_STOCK_UNITS`
- `AVG_DAILY_DEMAND_UNITS`

## RAW Loading Strategy

The load process must be deterministic and repeatable.

For the hackathon dataset, reload behavior is:

1. regenerate source CSV files locally,
2. upload them to the named internal stage,
3. truncate the target RAW tables,
4. execute `COPY INTO`,
5. validate COPY results,
6. verify expected row counts,
7. rebuild CORE from RAW,
8. execute data-quality validations.

The implementation must not silently append duplicate copies of the deterministic dataset.

A failed load must not be represented as successful.

## CORE Model

CORE tables use explicit Snowflake data types and stable business identifiers.

### ONTARA.CORE.SUPPLIERS

Primary business key:

`SUPPLIER_ID`

Important typed fields:

- supplier identity,
- country,
- risk tier,
- operational status.

### ONTARA.CORE.PARTS

Primary business key:

`PART_ID`

Important typed fields:

- part identity,
- category,
- unit of measure,
- standard unit cost.

### ONTARA.CORE.PLANTS

Primary business key:

`PLANT_ID`

Important typed fields:

- plant identity,
- country,
- region,
- capacity classification.

### ONTARA.CORE.SUPPLIER_PARTS

Composite business key:

`SUPPLIER_ID + PART_ID`

Relationships:

- supplier -> supplier master,
- part -> part master.

Purpose:

Defines governed sourcing relationships and alternate-source availability.

### ONTARA.CORE.PURCHASE_ORDERS

Primary business key:

`PURCHASE_ORDER_ID`

Relationships:

- purchase order -> supplier,
- purchase order -> plant,
- purchase order -> part.

Purpose:

Provides inbound procurement demand and landed-cost source inputs.

### ONTARA.CORE.CUSTOMERS

Primary business key:

`CUSTOMER_ID`

Purpose:

Provides customer identity, segmentation, geography, and priority.

### ONTARA.CORE.CUSTOMER_ORDERS

Primary business key:

`ORDER_ID`

Relationships:

- order -> customer,
- order -> plant,
- order -> part.

Purpose:

Provides downstream demand and quantity-weighted Fill Rate inputs.

### ONTARA.CORE.SHIPMENTS

Primary business key:

`SHIPMENT_ID`

Relationships:

Inbound:

`Shipment -> Purchase Order -> Supplier`

Outbound:

`Shipment -> Customer Order -> Customer`

Shared:

`Shipment -> Part`

`Shipment -> Plant`

Purpose:

Provides On-Time Delivery inputs and physical-flow relationships.

### ONTARA.CORE.SHIPMENT_EVENTS

Primary business key:

`SHIPMENT_EVENT_ID`

Relationship:

`Shipment Event -> Shipment`

Purpose:

Provides traceable shipment lifecycle and delay evidence.

### ONTARA.CORE.INVENTORY_SNAPSHOTS

Composite business key:

`SNAPSHOT_DATE + PLANT_ID + PART_ID`

Relationships:

- inventory -> plant,
- inventory -> part.

Purpose:

Provides available-inventory, safety-stock, and Days of Inventory inputs.

## Ontology-Ready Relationship Contract

The CORE model must support this primary governed traversal:

`Supplier -> Part -> Plant -> Shipment -> Order -> Customer`

The physical implementation may traverse intermediary procurement or order relationships, but
the business relationship must remain explainable.

The `SUP-003` controlled disruption must be traversable through CORE into downstream customer
exposure.

At minimum the dataset must preserve a path reaching:

- disrupted supplier `SUP-003`,
- disrupted part `PRT-009`,
- plant `PLT-003`,
- customer order `ORD-008`,
- strategic customer `CUS-003`.

## Canonical Metric Readiness

CORE must expose all fields required later by the governed semantic layer.

### On-Time Delivery

Required shipment fields:

- `STATUS`
- `PROMISED_DELIVERY_DATE`
- `ACTUAL_DELIVERY_DATE`

### Fill Rate

Required customer-order fields:

- `ORDERED_UNITS`
- `FULFILLED_UNITS`

### Days of Inventory

Required inventory fields:

- `ON_HAND_UNITS`
- `ALLOCATED_UNITS`
- `AVG_DAILY_DEMAND_UNITS`

### Landed Cost

Required purchase-order fields:

- `RECEIVED_UNITS`
- `UNIT_PURCHASE_COST_USD`
- `FREIGHT_COST_USD`
- `DUTY_COST_USD`
- `HANDLING_COST_USD`

Metric definitions themselves belong to the semantic feature and must not be duplicated as
competing definitions in RAW or CORE.

## Data-Type Contract

Identifiers:

`VARCHAR`

Names and categorical values:

`VARCHAR`

Dates:

`DATE`

Shipment-event timestamps:

`TIMESTAMP_NTZ`

Whole-unit quantities:

`NUMBER(18,0)`

Monetary values:

`NUMBER(18,2)`

Average daily demand:

`NUMBER(18,2)`

Boolean sourcing flags:

`BOOLEAN`

No floating-point type is used for governed monetary values.

## Integrity Strategy

Snowflake relational constraints can document intended relationships, but application
correctness must not depend only on unenforced constraints.

Integrity is validated explicitly through SQL tests.

Validation must cover:

- duplicate business keys,
- orphan suppliers,
- orphan parts,
- orphan plants,
- orphan customers,
- orphan purchase orders,
- orphan customer orders,
- orphan shipment events,
- invalid inbound shipment relationships,
- invalid outbound shipment relationships,
- quantities outside valid bounds,
- invalid shipment dates,
- invalid event sequencing,
- invalid metric prerequisites.

## Expected Row Counts

The deterministic dataset version `1.0.0` expects:

| Table               | Rows |
| ------------------- | ---: |
| Suppliers           |    8 |
| Parts               |   12 |
| Plants              |    4 |
| Supplier Parts      |   23 |
| Purchase Orders     |   24 |
| Customers           |   10 |
| Customer Orders     |   30 |
| Shipments           |   32 |
| Shipment Events     |  192 |
| Inventory Snapshots |   48 |

Row-count validation is part of the hackathon dataset contract.

## Idempotency Contract

Bootstrap SQL must be safe to rerun without unintentionally duplicating infrastructure.

Data-loading SQL must be safe to rerun for dataset version `1.0.0`.

The deterministic reload sequence must result in the same logical dataset each time.

The implementation must avoid hidden manual cleanup requirements.

## Failure Behavior

The pipeline must fail visibly when:

- expected files are missing,
- a CSV contains malformed rows,
- a required cast fails,
- expected row counts differ,
- integrity validations fail,
- controlled scenario anchors disappear.

No failed validation may be converted into a successful status purely for demo purposes.

## Security

The repository must never contain:

- Snowflake passwords,
- OAuth tokens,
- private keys,
- connection configuration containing credentials,
- temporary authentication artifacts.

Local Snowflake CLI connection configuration remains outside Git.

Normal application development should use `ONTARA_DEV_ROLE` rather than `ACCOUNTADMIN` after
bootstrap.

## Planned SQL Layout

This feature will introduce:

`sql/00_bootstrap.sql`

Creates:

- warehouse,
- database,
- schemas,
- development role,
- grants,
- file format,
- internal stage.

`sql/01_raw_tables.sql`

Creates the ten RAW tables.

`sql/02_core_tables.sql`

Creates the ten typed CORE tables.

`sql/03_core_refresh.sql`

Rebuilds CORE deterministically from RAW.

`sql/04_validate_core.sql`

Runs row-count, integrity, controlled-scenario, and metric-prerequisite validation.

Local file upload and RAW loading commands remain explicit operational steps so their execution
and results can be audited.

## Acceptance Criteria

This feature is complete only when:

1. Snowflake infrastructure is reproducibly created.
2. All ten generated CSV files can be staged.
3. All ten RAW tables load successfully.
4. RAW row counts match the deterministic manifest.
5. CORE contains typed representations of all source entities.
6. CORE row counts match the deterministic manifest.
7. no duplicate business keys exist.
8. no required ontology relationship contains orphan references.
9. controlled disruption scenarios remain queryable.
10. canonical metric input fields remain valid.
11. reload is repeatable.
12. validation SQL returns PASS for every required contract.
13. no secrets are committed.
14. repository CI remains green.
