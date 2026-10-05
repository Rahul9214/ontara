# Testing Strategy

Ontara treats business semantics as executable contracts.

## Test Layers

### Data Quality

Validate required fields, accepted values, date relationships, quantities, and uniqueness.

### Referential Integrity

Validate all ontology relationships.

### Metric Contracts

Validate canonical formulas against deterministic fixtures.

### Persona Consistency

Equivalent Planning, Procurement, and Logistics questions must resolve to the same governed
metric and result.

### Governed Actions

Validate that approved supply exceptions persist exactly once and remain auditable.

### Deployment

Validate Snowflake objects and Streamlit deployment from a clean environment.

## Critical Acceptance Test

For a fixed date range and scope:

canonical OTD
=
Planning OTD
=
Procurement OTD
=
Logistics OTD

Any mismatch fails the semantic contract.
