# Ontara Semantic Contract

## Purpose

Ontara provides one governed definition for each canonical supply-chain
metric so Planning, Procurement, Logistics, and other personas receive the
same business answer for equivalent questions.

The semantic contract separates:

- canonical metric meaning;
- physical Snowflake implementation;
- persona-specific wording and dimensions;
- verified reference results.

A persona may change how a result is explained or sliced, but it must not
change the underlying metric formula.

---

## Contract Version

Semantic contract version: `1.0.0`

Dataset version: `1.0.0`

Reference snapshot date: `2026-09-30`

Status: `LOCKED`

---

# Canonical Metrics

## 1. On-Time Delivery

Contract ID: `OTD_V1`

Canonical name: `On-Time Delivery`

Primary synonym: `OTD`

Additional synonyms:

- on time delivery
- on-time delivery rate
- delivery performance
- on time shipment delivery

### Business meaning

Percentage of completed outbound deliveries that arrived on or before their
promised delivery date.

### Eligibility

A shipment is eligible when:

- `SHIPMENT_TYPE = 'OUTBOUND'`;
- `STATUS = 'DELIVERED'`;
- `ACTUAL_DELIVERY_DATE IS NOT NULL`.

Open, delayed-but-not-delivered, and in-transit shipments are not included in
the denominator until delivery is completed.

### Numerator

Count of eligible shipments where:

`ACTUAL_DELIVERY_DATE <= PROMISED_DELIVERY_DATE`

### Denominator

Count of eligible delivered outbound shipments.

### Formula

`100 * on_time_delivered_outbound_shipments / delivered_outbound_shipments`

### Reference result

- outbound shipments: `20`
- delivered outbound shipments: `19`
- on-time delivered outbound shipments: `17`
- canonical OTD: `89.47%`

### Grain

Shipment.

### Primary source

`ONTARA.CORE.SHIPMENTS`

### Governance rule

Do not use all outbound shipments as the denominator.

An undelivered shipment must not become an OTD failure before the delivery
outcome is known.

---

## 2. Fill Rate

Contract ID: `FILL_RATE_V1`

Canonical name: `Fill Rate`

Synonyms:

- order fill rate
- fulfillment rate
- fulfilled demand
- demand fulfillment

### Business meaning

Percentage of ordered customer units that have been fulfilled.

### Numerator

Sum of:

`FULFILLED_UNITS`

### Denominator

Sum of:

`ORDERED_UNITS`

### Formula

`100 * SUM(FULFILLED_UNITS) / SUM(ORDERED_UNITS)`

### Reference result

- fulfilled units: `3429`
- ordered units: `3729`
- canonical fill rate: `91.95%`

### Grain

Customer order.

### Primary source

`ONTARA.CORE.CUSTOMER_ORDERS`

### Governance rule

Fill rate is quantity weighted.

Do not calculate the canonical metric as an average of individual
order-level percentages.

---

## 3. Days of Inventory

Contract ID: `DOI_V1`

Canonical name: `Days of Inventory`

Primary abbreviation: `DOI`

Synonyms:

- inventory days
- days inventory
- inventory coverage
- days of supply
- inventory days of supply

### Business meaning

Number of demand days covered by currently available physical inventory at
the latest inventory snapshot.

### Snapshot policy

Use only the latest governed snapshot date when no explicit date is supplied.

Reference latest snapshot:

`2026-09-30`

### Available inventory

`ON_HAND_UNITS - ALLOCATED_UNITS`

In-transit inventory is excluded from canonical available inventory because
it is not yet physically available at the plant.

### Demand denominator

Sum of:

`AVG_DAILY_DEMAND_UNITS`

for the same governed snapshot.

### Formula

`SUM(ON_HAND_UNITS - ALLOCATED_UNITS) / SUM(AVG_DAILY_DEMAND_UNITS)`

### Reference result

- available units: `12072`
- average daily demand: `742.73`
- canonical days of inventory: `16.25`

### Grain

Plant + Part + Snapshot Date.

### Primary source

`ONTARA.CORE.INVENTORY_SNAPSHOTS`

### Governance rule

Do not aggregate multiple inventory snapshot dates into the canonical current
DOI result.

Doing so would mix different points in time and double count inventory.

---

## 4. Landed Cost

Contract ID: `LANDED_COST_V1`

Canonical name: `Landed Cost per Unit`

Synonyms:

- landed cost
- landed unit cost
- delivered procurement cost
- total landed cost per unit
- procurement landed cost

### Business meaning

Purchase cost plus freight, duty, and handling allocated across ordered
purchase-order units.

### Total landed cost

For each purchase order:

`ORDERED_UNITS * UNIT_PURCHASE_COST_USD`
`+ FREIGHT_COST_USD`
`+ DUTY_COST_USD`
`+ HANDLING_COST_USD`

### Canonical unit metric

`SUM(total_landed_cost) / SUM(ORDERED_UNITS)`

### Reference result

- total landed cost: `$994419.29`
- total ordered units: `15143`
- canonical landed cost per unit: `$65.67`

### Grain

Purchase order.

### Primary source

`ONTARA.CORE.PURCHASE_ORDERS`

### Scope

Version 1 uses all governed purchase orders unless a user explicitly provides
a purchase-order status filter.

### Governance rule

Do not average individual purchase-order landed-cost-per-unit values.

The canonical aggregate must remain quantity weighted.

---

# Numerical Safety Rules

All ratio metrics must protect against division by zero.

Metric calculations use the unrounded underlying values.

Rounding occurs only for presentation or verified reference output.

Canonical presentation precision:

- On-Time Delivery: 2 decimal places
- Fill Rate: 2 decimal places
- Days of Inventory: 2 decimal places
- Landed Cost per Unit: 2 decimal places

---

# Persona Consistency Contract

Equivalent business questions must resolve to the same canonical metric
regardless of persona.

## Planning

Typical emphasis:

- plant;
- part;
- inventory;
- customer demand;
- shortage exposure.

## Procurement

Typical emphasis:

- supplier;
- part;
- purchase order;
- landed cost;
- alternate sourcing.

## Logistics

Typical emphasis:

- shipment;
- carrier;
- delivery date;
- delay;
- On-Time Delivery.

## Consistency rule

Persona changes:

- available dimensions;
- explanation wording;
- recommended next investigation;
- visualization context.

Persona must not change:

- metric formula;
- eligibility criteria;
- denominator;
- source-of-truth definition;
- contract version.

For example, equivalent questions such as:

- "What is our OTD?"
- "How are deliveries performing on time?"
- "Show the current on-time delivery rate."

must resolve to `OTD_V1`.

---

# Semantic Contract Verifier

Ontara will expose a trust explanation for governed answers.

For a canonical metric answer, the verifier should be able to show:

1. canonical metric name;
2. contract ID;
3. contract version;
4. business definition;
5. governed Snowflake semantic view;
6. source logical table;
7. applied filters;
8. formula;
9. result;
10. verified-query status.

Equivalent persona questions must produce the same canonical metric result
when their filter context is equivalent.

---

# Verified Reference Results

The initial verified-query baseline is:

| Contract         |            Result |
| ---------------- | ----------------: |
| `OTD_V1`         |          `89.47%` |
| `FILL_RATE_V1`   |          `91.95%` |
| `DOI_V1`         |      `16.25 days` |
| `LANDED_COST_V1` | `$65.67 per unit` |

These values are deterministic reference results for dataset version `1.0.0`.

They are validation anchors, not hard-coded application answers.

The deployed system must calculate them from Snowflake data.

---

# Semantic Layer Requirements

The Snowflake semantic implementation must:

- source governed data from `ONTARA.CORE`;
- expose canonical metrics through a native Snowflake Semantic View;
- retain metric synonyms and business descriptions;
- model relevant entity relationships;
- support useful Planning, Procurement, and Logistics dimensions;
- include verified queries for canonical metrics where supported;
- produce the reference values defined above;
- allow deterministic SQL validation independent of natural-language AI;
- provide enough metadata for Ontara's Semantic Contract Verifier;
- avoid duplicating conflicting metric definitions in application code.

The application and future Cortex Agent should consume the governed semantic
contract rather than redefining these metrics independently.
