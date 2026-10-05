# Dataset Manifest

Ontara uses deterministic synthetic supply chain data.

No confidential company, customer, patient, or personally identifiable production data is
required for the hackathon demonstration.

## Planned Source Domains

- suppliers
- parts
- plants
- purchase orders
- customer orders
- shipments
- shipment events
- inventory snapshots

## Data Requirements

Synthetic data must preserve:

- referential integrity,
- realistic cardinality,
- deterministic regeneration,
- valid business dates,
- meaningful edge cases,
- metric-verification scenarios.

## Required Edge Cases

The generator will intentionally include examples of:

- late delivery,
- partial fulfillment,
- stock below safety level,
- delayed supplier shipment,
- high landed cost,
- duplicate operational events where appropriate,
- missing optional attributes,
- multi-order and multi-shipment relationships.

## Reproducibility

The generator must use a fixed configurable random seed.

Generated datasets are build artifacts and are not committed unless a small fixture is
explicitly required for tests.
