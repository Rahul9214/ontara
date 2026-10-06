USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;

-- Canonical semantic contract through the MCP wrapper.
CALL ONTARA.APP.MCP_GET_GOVERNED_METRIC('OTD');

-- Controlled ontology blast radius.
CALL ONTARA.APP.MCP_GET_SUPPLIER_BLAST_RADIUS('SUP-003');

-- Controlled critical operational path.
CALL ONTARA.APP.MCP_GET_OPERATIONAL_HEALTH(
    'SUP-003',
    'PRT-009',
    'PLT-003',
    'ORD-008'
);

-- Guardrail proof: invalid input must fail closed and create no action.
CALL ONTARA.APP.MCP_REQUEST_SUPPLY_EXCEPTION(
    'BAD',
    'PRT-009',
    'ORD-008',
    'Ontara MCP guardrail validation'
);

SHOW MCP SERVERS LIKE 'ONTARA_MCP'
    IN SCHEMA ONTARA.APP;

USE ROLE ACCOUNTADMIN;

SHOW GRANTS TO ROLE ONTARA_MCP_ROLE;