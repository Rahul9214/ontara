# Cortex / CoCo Integration and Deterministic Fallback

## Status

Ontara was designed with Snowflake Cortex / CoCo as an intelligence layer on top of the governed Snowflake data and semantic architecture.

During the hackathon, Cortex / CoCo remained unavailable on the provided replacement Snowflake account because of an account-level entitlement limitation despite:

- successful Snowflake CLI authentication
- required Cortex-related roles being assigned
- account and user configuration checks
- cross-region configuration
- replacement-account setup
- multiple entitlement request IDs being reported to support

The Hack2Skill team advised proceeding with the Snowflake capabilities currently available rather than blocking the submission on Cortex / CoCo enablement.

Ontara therefore keeps the AI integration isolated and runs through a fully functional governed deterministic path.

## Runtime architecture

```text
Streamlit UI
     |
     v
Governed Application Layer
     |
     +-- Deterministic / Verified Query Path
     |      |
     |      +-- ONTARA.SEMANTIC.SUPPLY_CHAIN
     |      +-- canonical semantic metrics
     |      +-- ontology blast-radius views
     |      +-- governed Snowflake procedures
     |      +-- Action Center
     |
     +-- Cortex / CoCo Integration
            |
            +-- optional adapter
            +-- unavailable because of account entitlement
```

## Deterministic fallback

The fallback is not simulated AI output.

Supported conversational questions resolve only to governed Snowflake objects and approved semantic contracts.

Current supported analytical intents include:

- On-Time Delivery
- Fill Rate
- Days of Inventory
- Landed Cost per Unit
- governed supplier blast-radius analysis

If Ontara cannot map a question to an approved governed metric or impact path, it fails closed and does not fabricate an analytical answer.

## Why this architecture matters

The application remains operational even when the optional intelligence layer is unavailable.

The business truth remains in Snowflake rather than in an LLM response.

This preserves:

- metric consistency
- semantic governance
- deterministic validation
- auditability
- human approval
- operational continuity
- safe fallback behavior

## Cortex / CoCo restoration path

When the entitlement becomes available, Cortex / CoCo can be connected as an additional intelligence surface without replacing the governed Snowflake truth layer.

The intended path is:

```text
Natural-language question
        |
        v
Cortex / CoCo
        |
        v
Governed semantic / tool resolution
        |
        v
Snowflake semantic metrics,
blast-radius evidence,
or governed actions
```

Cortex / CoCo is therefore an intelligence interface over the governed system, not the system of record itself.

## Submission integrity

Ontara does not claim that unavailable Cortex / CoCo functionality was executed.

No simulated Cortex response is represented as a live Cortex response.

All demonstrated Snowflake metrics, ontology impact, action state, approval transitions, and audit history are backed by live Snowflake objects.
