-- Ontara Snowflake-managed MCP server.
--
-- Intentionally exposes only governed business operations.
--
-- NOT exposed:
-- - arbitrary SQL
-- - exception approval / rejection
-- - arbitrary workflow status transitions
--
-- A caller may investigate governed supply-chain state and submit
-- an approval-gated mitigation request.

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA APP;

CREATE OR REPLACE MCP SERVER ONTARA.APP.ONTARA_MCP
FROM SPECIFICATION $$
tools:

  - name: "get_governed_metric"
    title: "Get Governed Supply Chain Metric"
    type: "GENERIC"
    identifier: "ONTARA.APP.MCP_GET_GOVERNED_METRIC"
    description: >-
      Returns exactly one approved Ontara canonical metric from the governed
      semantic contract. Use only for OTD, Fill Rate, Days of Inventory,
      or Landed Cost. Does not execute arbitrary SQL.
    config:
      type: "procedure"
      warehouse: "ONTARA_WH"
      query_timeout: 60
      input_schema:
        type: "object"
        properties:
          METRIC_NAME:
            type: "string"
            description: >-
              Canonical metric key. Use OTD, FILL_RATE, DOI,
              or LANDED_COST.
        required:
          - "METRIC_NAME"

  - name: "get_supplier_blast_radius"
    title: "Get Supplier Blast Radius"
    type: "GENERIC"
    identifier: "ONTARA.APP.MCP_GET_SUPPLIER_BLAST_RADIUS"
    description: >-
      Returns governed quantitative downstream impact for one supplier across
      parts, plants, orders, customers, inventory, revenue exposure,
      logistics risk, alternate sourcing, and risk scoring.
    config:
      type: "procedure"
      warehouse: "ONTARA_WH"
      query_timeout: 60
      input_schema:
        type: "object"
        properties:
          SUPPLIER_ID:
            type: "string"
            description: "Governed supplier identifier in SUP-### format."
        required:
          - "SUPPLIER_ID"

  - name: "get_operational_health"
    title: "Get Operational Supply Health"
    type: "GENERIC"
    identifier: "ONTARA.APP.MCP_GET_OPERATIONAL_HEALTH"
    description: >-
      Returns the governed operational health state for one exact
      supplier-part-plant-order path, including inventory shortfall,
      DOI, revenue exposure, sourcing resilience, risk score,
      risk band, and recommended response.
    config:
      type: "procedure"
      warehouse: "ONTARA_WH"
      query_timeout: 60
      input_schema:
        type: "object"
        properties:
          SUPPLIER_ID:
            type: "string"
            description: "Supplier identifier in SUP-### format."
          PART_ID:
            type: "string"
            description: "Part identifier in PRT-### format."
          PLANT_ID:
            type: "string"
            description: "Plant identifier in PLT-### format."
          ORDER_ID:
            type: "string"
            description: "Customer order identifier in ORD-### format."
        required:
          - "SUPPLIER_ID"
          - "PART_ID"
          - "PLANT_ID"
          - "ORDER_ID"

  - name: "get_supply_exception"
    title: "Get Governed Supply Exception"
    type: "GENERIC"
    identifier: "ONTARA.APP.MCP_GET_SUPPLY_EXCEPTION"
    description: >-
      Reads the current governed state of one supply exception and its
      approval evidence. This tool is read-only and cannot approve,
      reject, execute, or change workflow status.
    config:
      type: "procedure"
      warehouse: "ONTARA_WH"
      query_timeout: 60
      input_schema:
        type: "object"
        properties:
          EXCEPTION_ID:
            type: "string"
            description: "Existing governed supply exception identifier."
        required:
          - "EXCEPTION_ID"

  - name: "request_supply_exception"
    title: "Request Governed Supply Mitigation"
    type: "GENERIC"
    identifier: "ONTARA.APP.MCP_REQUEST_SUPPLY_EXCEPTION"
    description: >-
      Submits an idempotent mitigation request for a validated
      supplier-part-order path. The request enters Ontara's governed action
      workflow and requires human approval. This tool cannot approve,
      reject, execute, or arbitrarily change the action status.
    config:
      type: "procedure"
      warehouse: "ONTARA_WH"
      query_timeout: 60
      input_schema:
        type: "object"
        properties:
          SUPPLIER_ID:
            type: "string"
            description: "Supplier identifier in SUP-### format."
          PART_ID:
            type: "string"
            description: "Part identifier in PRT-### format."
          ORDER_ID:
            type: "string"
            description: "Customer order identifier in ORD-### format."
          SOURCE_QUESTION:
            type: "string"
            description: >-
              The business question or reasoning context that caused the
              mitigation request. Maximum 1000 characters.
        required:
          - "SUPPLIER_ID"
          - "PART_ID"
          - "ORDER_ID"
          - "SOURCE_QUESTION"
$$;