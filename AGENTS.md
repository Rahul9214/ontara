# Ontara Engineering Contract

Ontara is a Snowflake-native governed supply chain intelligence application.

## Product Principle

One supply chain. Shared definitions. Trusted answers.

## Engineering Priorities

1. Correctness before visual polish.
2. Governed business semantics before raw SQL convenience.
3. Real persisted actions instead of simulated UI behavior.
4. Reproducible data and deployments.
5. Least-privilege access.
6. Deterministic tests for canonical metrics.
7. Explainable answers with lineage to definitions and sources.
8. No fabricated API responses, AI outputs, metrics, or runtime evidence.
9. No unnecessary infrastructure or duplicate sources of truth.
10. Keep Snowflake as the authoritative data and governance platform.

## Core Product Capabilities

- Governed supply chain ontology.
- Canonical metric definitions.
- Cross-persona semantic consistency.
- Ontology blast-radius analysis.
- Governed conversational analytics.
- Human-approved operational actions.
- Persistent supply exception audit trail.
- Snowflake-native deployment.

## Core Ontology

Supplier -> Part -> Plant -> Shipment -> Order -> Customer

Supporting concepts may include:

- Purchase Order
- Inventory Snapshot
- Shipment Event
- Supply Exception

## Canonical Metrics

- On-Time Delivery
- Fill Rate
- Days of Inventory
- Landed Cost

Each metric must have:

- one canonical definition,
- explicit grain,
- dimensions,
- source tables,
- null/edge-case behavior,
- version,
- deterministic validation.

## Architecture Rules

Prefer Snowflake-native capabilities:

- SQL
- Dynamic Tables
- Streams and Tasks when justified
- Semantic Views
- Cortex Analyst
- Cortex Agents
- Snowpark Python
- Streamlit in Snowflake
- Stored procedures
- Snowflake CLI
- Cortex Code / CoCo

Add external infrastructure only when it solves a requirement that Snowflake-native
capabilities cannot reasonably satisfy.

## Security

Never commit:

- passwords,
- OAuth tokens,
- Snowflake credentials,
- private keys,
- API secrets,
- Streamlit secrets.

## Git

Use short-lived branches and pull requests.

Preferred branch prefixes:

- chore/
- feat/
- fix/
- test/
- docs/

Use Conventional Commit-style messages.

Do not commit generated artifacts or unused scaffolding.

## CoCo Evidence

CoCo usage must be genuine.

If CoCo is unavailable because of environment or entitlement issues, document the blocker.
Never claim that CoCo generated, executed, reviewed, or validated work it did not actually perform.
