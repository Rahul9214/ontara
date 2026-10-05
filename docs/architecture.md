# Architecture

## Design Goal

Keep Snowflake as the authoritative platform for data, business meaning, AI interaction,
governance, and operational actions.

## Logical Flow

Enterprise source simulations
-> RAW
-> governed transformation
-> CORE
-> SEMANTIC
-> Cortex Analyst / Cortex Agent
-> Streamlit
-> governed operational action
-> audit trail

## Snowflake Domains

### ONTARA.RAW

Source-shaped synthetic enterprise data representing ERP, supplier, logistics, inventory,
and operational events.

### ONTARA.CORE

Clean, validated, business-grain entities and facts.

### ONTARA.SEMANTIC

Semantic views, governed dimensions, canonical measures, relationships, and verified queries.

### ONTARA.GOVERNANCE

Metric contracts, supply exceptions, action history, and audit records.

### ONTARA.APP

Application-facing objects where required.

## Primary Runtime

- Snowflake AI Data Cloud
- Snowflake SQL
- Dynamic Tables
- Semantic Views
- Cortex Analyst
- Cortex Agents
- Snowpark Python
- Streamlit in Snowflake
- Snowflake CLI
- Cortex Code

## Optional Integration Boundary

A TypeScript MCP connector may be added for a real external disruption signal if the core
submission is stable.

It must not become a second source of truth.

## Architectural Constraint

No technology is introduced only for appearance or résumé value.

Every component must have an explicit responsibility and measurable contribution to the
challenge requirements.
