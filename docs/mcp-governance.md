# Ontara Governed MCP Surface

Ontara exposes a Snowflake-managed MCP server at:

`ONTARA.APP.ONTARA_MCP`

The MCP boundary deliberately exposes governed business capabilities rather
than arbitrary SQL.

## Exposed tools

1. `get_governed_metric`
   - OTD
   - Fill Rate
   - Days of Inventory
   - Landed Cost

2. `get_supplier_blast_radius`
   - Quantitative Supplier -> Part -> Plant -> Shipment -> Order -> Customer impact.

3. `get_operational_health`
   - Exact supplier-part-plant-order operational risk state.

4. `get_supply_exception`
   - Read-only governed action state.

5. `request_supply_exception`
   - Request-only action creation.
   - Human approval remains mandatory.

## Explicitly not exposed

- arbitrary SQL execution
- `SYSTEM_EXECUTE_SQL`
- exception approval
- exception rejection
- arbitrary workflow status transitions

This prevents an external agent or MCP client from approving or executing its
own mitigation request.

## Least-privilege access

`ONTARA_MCP_ROLE` has only the privileges required to:

- use `ONTARA_WH`
- use database `ONTARA`
- use schema `ONTARA.APP`
- use `ONTARA.APP.ONTARA_MCP`
- invoke the five MCP wrapper procedures

The role has no direct access to the RAW, CORE, SEMANTIC, or GOVERNANCE
schemas and no access to the approval/status-transition procedures.

The wrapper procedures execute with owner rights and therefore preserve a
narrow controlled interface over the governed Snowflake objects.

## Live validation

The wrapper procedures have been executed against the live Snowflake account.

Canonical metric results:

- OTD: `89.473684%`
- Fill Rate: `91.954948%`
- Days of Inventory: `16.253551`
- Landed Cost: `$65.66857888/unit`

Controlled supplier blast radius for `SUP-003`:

- supplier: Orion Precision
- affected parts: 3
- affected plants: 3
- affected orders: 12
- affected customers: 6
- outstanding units: 235
- outstanding revenue exposure: `$36,024.90`
- maximum impact risk score: 90
- recommendation: `ESCALATE_AND_EXPEDITE`

Controlled operational path:

`SUP-003 -> PRT-009 -> PLT-003 -> ORD-008 -> CUS-003`

returns:

- operational status: `CRITICAL`
- risk score: 90
- available inventory: 5
- safety stock: 20
- inventory shortfall: 15
- Days of Inventory: 0.42
- outstanding units: 60
- revenue exposure: `$13,187.40`

## Evidence integrity

Ontara does not represent simulated MCP, Cortex, or CoCo output as live
execution.

The Snowflake-managed MCP server, its server specification, least-privilege
role, and all five underlying governed wrapper procedures are deployed and
validated.

External PAT/OAuth protocol invocation is not used as submission evidence.