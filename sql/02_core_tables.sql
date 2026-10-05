-- Ontara CORE governed table definitions
--
-- Purpose:
--   Define the typed relational supply-chain model used by semantic views,
--   canonical metrics, ontology traversal, governed analytics, and actions.
--
-- Data flow:
--   deterministic CSV -> RAW VARCHAR tables -> typed CORE tables
--
-- Important:
--   Standard Snowflake primary/foreign-key constraints are informational
--   rather than enforced for ordinary tables. Ontara therefore validates
--   key uniqueness and referential integrity explicitly in 04_validate_core.sql.
--
-- Execution role:
--   ONTARA_DEV_ROLE


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA CORE;


-- ---------------------------------------------------------------------------
-- 1. Suppliers
-- Ontology entity: Supplier
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.SUPPLIERS (
    SUPPLIER_ID VARCHAR NOT NULL,
    SUPPLIER_NAME VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    RISK_TIER VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'Governed supplier master used by the Ontara supply-chain ontology';


-- ---------------------------------------------------------------------------
-- 2. Parts
-- Ontology entity: Part
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.PARTS (
    PART_ID VARCHAR NOT NULL,
    PART_NAME VARCHAR NOT NULL,
    CATEGORY VARCHAR NOT NULL,
    UNIT_OF_MEASURE VARCHAR NOT NULL,
    STANDARD_UNIT_COST_USD NUMBER(18, 2) NOT NULL
)
COMMENT = 'Governed part master with typed standard unit cost';


-- ---------------------------------------------------------------------------
-- 3. Plants
-- Ontology entity: Plant
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.PLANTS (
    PLANT_ID VARCHAR NOT NULL,
    PLANT_NAME VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    REGION VARCHAR NOT NULL,
    CAPACITY_CLASS VARCHAR NOT NULL
)
COMMENT = 'Governed manufacturing and distribution plant master';


-- ---------------------------------------------------------------------------
-- 4. Supplier Parts
-- Relationship: Supplier -> Part
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.SUPPLIER_PARTS (
    SUPPLIER_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    LEAD_TIME_DAYS NUMBER(18, 0) NOT NULL,
    CONTRACTED_UNIT_COST_USD NUMBER(18, 2) NOT NULL,
    MINIMUM_ORDER_QUANTITY NUMBER(18, 0) NOT NULL,
    PRIMARY_SUPPLIER_FLAG BOOLEAN NOT NULL
)
COMMENT = 'Governed supplier-to-part sourcing relationship';


-- ---------------------------------------------------------------------------
-- 5. Purchase Orders
-- Supporting entity: Purchase Order
-- Provides inbound sourcing and landed-cost inputs.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.PURCHASE_ORDERS (
    PURCHASE_ORDER_ID VARCHAR NOT NULL,
    SUPPLIER_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ORDER_DATE DATE NOT NULL,
    PROMISED_DELIVERY_DATE DATE NOT NULL,
    ORDERED_UNITS NUMBER(18, 0) NOT NULL,
    RECEIVED_UNITS NUMBER(18, 0) NOT NULL,
    UNIT_PURCHASE_COST_USD NUMBER(18, 2) NOT NULL,
    FREIGHT_COST_USD NUMBER(18, 2) NOT NULL,
    DUTY_COST_USD NUMBER(18, 2) NOT NULL,
    HANDLING_COST_USD NUMBER(18, 2) NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'Governed inbound purchase orders and landed-cost components';


-- ---------------------------------------------------------------------------
-- 6. Customers
-- Ontology entity: Customer
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.CUSTOMERS (
    CUSTOMER_ID VARCHAR NOT NULL,
    CUSTOMER_NAME VARCHAR NOT NULL,
    SEGMENT VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    PRIORITY_TIER VARCHAR NOT NULL
)
COMMENT = 'Governed customer master';


-- ---------------------------------------------------------------------------
-- 7. Customer Orders
-- Ontology entity: Order
-- Relationship path:
--   Part -> Plant -> Order -> Customer
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.CUSTOMER_ORDERS (
    ORDER_ID VARCHAR NOT NULL,
    CUSTOMER_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ORDER_DATE DATE NOT NULL,
    PROMISED_SHIP_DATE DATE NOT NULL,
    ORDERED_UNITS NUMBER(18, 0) NOT NULL,
    FULFILLED_UNITS NUMBER(18, 0) NOT NULL,
    UNIT_SALE_PRICE_USD NUMBER(18, 2) NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'Governed downstream customer orders used for fulfillment and exposure analytics';


-- ---------------------------------------------------------------------------
-- 8. Shipments
-- Ontology entity: Shipment
-- Supports inbound and outbound delivery analysis.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.SHIPMENTS (
    SHIPMENT_ID VARCHAR NOT NULL,
    SHIPMENT_TYPE VARCHAR NOT NULL,
    PURCHASE_ORDER_ID VARCHAR,
    CUSTOMER_ORDER_ID VARCHAR,
    PART_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    SUPPLIER_ID VARCHAR,
    CUSTOMER_ID VARCHAR,
    SHIP_DATE DATE NOT NULL,
    PROMISED_DELIVERY_DATE DATE NOT NULL,
    ACTUAL_DELIVERY_DATE DATE,
    SHIPPED_UNITS NUMBER(18, 0) NOT NULL,
    CARRIER VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'Governed inbound and outbound shipment facts';


-- ---------------------------------------------------------------------------
-- 9. Shipment Events
-- Supporting entity: Shipment Event
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.SHIPMENT_EVENTS (
    SHIPMENT_EVENT_ID VARCHAR NOT NULL,
    SHIPMENT_ID VARCHAR NOT NULL,
    EVENT_SEQUENCE NUMBER(18, 0) NOT NULL,
    EVENT_TYPE VARCHAR NOT NULL,
    EVENT_TIMESTAMP TIMESTAMP_NTZ NOT NULL,
    LOCATION_CODE VARCHAR NOT NULL,
    DELAY_REASON VARCHAR,
    SOURCE_SYSTEM VARCHAR NOT NULL
)
COMMENT = 'Governed ordered shipment lifecycle events';


-- ---------------------------------------------------------------------------
-- 10. Inventory Snapshots
-- Supporting entity: Inventory Snapshot
-- Supports Days of Inventory and shortage-risk analysis.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.CORE.INVENTORY_SNAPSHOTS (
    SNAPSHOT_DATE DATE NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ON_HAND_UNITS NUMBER(18, 0) NOT NULL,
    ALLOCATED_UNITS NUMBER(18, 0) NOT NULL,
    IN_TRANSIT_UNITS NUMBER(18, 0) NOT NULL,
    SAFETY_STOCK_UNITS NUMBER(18, 0) NOT NULL,
    AVG_DAILY_DEMAND_UNITS NUMBER(18, 2) NOT NULL
)
COMMENT = 'Governed typed plant-part inventory snapshots';


-- ---------------------------------------------------------------------------
-- Object verification
-- ---------------------------------------------------------------------------

SELECT
    COUNT(*) AS CORE_TABLE_COUNT,
    LISTAGG(TABLE_NAME, ', ')
        WITHIN GROUP (ORDER BY TABLE_NAME) AS CORE_TABLES
FROM ONTARA.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORE'
  AND TABLE_TYPE = 'BASE TABLE';