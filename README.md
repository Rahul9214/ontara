# Ontara

**Governed Supply Chain Intelligence**

> One supply chain. Shared definitions. Trusted answers.

Ontara is a Snowflake-native governed intelligence layer for supply chain teams.

It addresses a common enterprise problem: planning, procurement, logistics, and operations
often use the same business terms while calculating them differently.

Ontara combines a shared supply-chain ontology, governed semantic metrics, conversational
analytics, explainable metric resolution, operational impact analysis, and human-approved
actions.

## Challenge

Supply-chain data is fragmented across ERP, logistics, supplier, inventory, and operational
systems.

Without a shared semantic layer:

- teams calculate metrics differently,
- natural-language analytics return inconsistent answers,
- lineage is difficult to explain,
- operational decisions become harder to trust.

## Core Ontology

Supplier -> Part -> Plant -> Shipment -> Order -> Customer

## Canonical Metrics

- On-Time Delivery
- Fill Rate
- Days of Inventory
- Landed Cost

## Judge-Facing Differentiators

### Semantic Contract Verifier

Equivalent questions from Planning, Procurement, and Logistics must resolve to the same
canonical metric definition and result.

### Ontology Blast Radius

Operational disruptions can be traced through supplier, part, plant, shipment, order, and
customer relationships to quantify business exposure.

### Governed Action Loop

Recommendations do not silently mutate operational data.

Ontara requires human approval before persisting supply exceptions and records the resulting
action in an auditable governance layer.

## Architecture

Ontara is intentionally Snowflake-native:

- Snowflake AI Data Cloud
- Snowflake SQL
- Dynamic Tables
- Semantic Views
- Cortex Analyst
- Cortex Agents
- Snowpark Python
- Streamlit in Snowflake
- Snowflake CLI
- Cortex Code / CoCo

A TypeScript MCP integration may be added for a real external disruption signal after the
core governed workflow is stable.

See [Architecture](docs/architecture.md).

## Engineering Principles

- real behavior over simulated demos,
- governed definitions over duplicated formulas,
- deterministic data and tests,
- auditable operational actions,
- least privilege,
- minimal infrastructure,
- reproducible deployment,
- no fabricated CoCo or AI evidence.

## Current Status

The repository foundation is established and executable product development is underway.

Snowflake CLI and Cortex Code tooling are configured locally. Hack2Skill provided a
replacement $400 event account after the original account exposed a Cortex entitlement
restriction.

The replacement account has valid Cortex roles, unrestricted CoCo usage parameters, and
cross-region inference enabled, but Cortex AI execution remains restricted at the account
entitlement level. Hackathon support has been notified.

Deterministic engineering continues locally while the entitlement issue is being resolved.
CoCo-generated work will only be claimed after CoCo successfully executes it.

See [CoCo Evidence](docs/coco-evidence.md) for the complete audit trail.

## Documentation

- [Problem Statement](docs/problem-statement.md)
- [Architecture](docs/architecture.md)
- [Dataset Manifest](docs/dataset-manifest.md)
- [Security](docs/security.md)
- [Testing Strategy](docs/testing-strategy.md)
- [CoCo Evidence](docs/coco-evidence.md)

## License

MIT License. See [LICENSE](LICENSE).
