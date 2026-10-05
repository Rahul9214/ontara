-- Ontara RAW table definitions
--
-- Purpose:
--   Preserve deterministic source-oriented CSV records with minimal
--   interpretation before governed typing in ONTARA.CORE.
--
-- Design:
--   RAW columns remain VARCHAR so ingestion preserves source values exactly.
--   Type enforcement and governed transformation belong to CORE.
--
-- Execution role:
--   ONTARA_DEV_ROLE

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA RAW;


-- ---------------------------------------------------------------------------
-- 1. Suppliers
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.SUPPLIERS (
    SUPPLIER_ID VARCHAR NOT NULL,
    SUPPLIER_NAME VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    RISK_TIER VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'RAW synthetic supplier master';


-- ---------------------------------------------------------------------------
-- 2. Parts
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.PARTS (
    PART_ID VARCHAR NOT NULL,
    PART_NAME VARCHAR NOT NULL,
    CATEGORY VARCHAR NOT NULL,
    UNIT_OF_MEASURE VARCHAR NOT NULL,
    STANDARD_UNIT_COST_USD VARCHAR NOT NULL
)
COMMENT = 'RAW synthetic governed part master';


-- ---------------------------------------------------------------------------
-- 3. Plants
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.PLANTS (
    PLANT_ID VARCHAR NOT NULL,
    PLANT_NAME VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    REGION VARCHAR NOT NULL,
    CAPACITY_CLASS VARCHAR NOT NULL
)
COMMENT = 'RAW synthetic plant master';


-- ---------------------------------------------------------------------------
-- 4. Supplier Parts
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.SUPPLIER_PARTS (
    SUPPLIER_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    LEAD_TIME_DAYS VARCHAR NOT NULL,
    CONTRACTED_UNIT_COST_USD VARCHAR NOT NULL,
    MINIMUM_ORDER_QUANTITY VARCHAR NOT NULL,
    PRIMARY_SUPPLIER_FLAG VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic supplier-to-part sourcing relationships';


-- ---------------------------------------------------------------------------
-- 5. Purchase Orders
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.PURCHASE_ORDERS (
    PURCHASE_ORDER_ID VARCHAR NOT NULL,
    SUPPLIER_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ORDER_DATE VARCHAR NOT NULL,
    PROMISED_DELIVERY_DATE VARCHAR NOT NULL,
    ORDERED_UNITS VARCHAR NOT NULL,
    RECEIVED_UNITS VARCHAR NOT NULL,
    UNIT_PURCHASE_COST_USD VARCHAR NOT NULL,
    FREIGHT_COST_USD VARCHAR NOT NULL,
    DUTY_COST_USD VARCHAR NOT NULL,
    HANDLING_COST_USD VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic inbound purchase-order records';


-- ---------------------------------------------------------------------------
-- 6. Customers
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.CUSTOMERS (
    CUSTOMER_ID VARCHAR NOT NULL,
    CUSTOMER_NAME VARCHAR NOT NULL,
    SEGMENT VARCHAR NOT NULL,
    COUNTRY_CODE VARCHAR NOT NULL,
    PRIORITY_TIER VARCHAR NOT NULL
)
COMMENT = 'RAW synthetic customer master';


-- ---------------------------------------------------------------------------
-- 7. Customer Orders
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.CUSTOMER_ORDERS (
    ORDER_ID VARCHAR NOT NULL,
    CUSTOMER_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ORDER_DATE VARCHAR NOT NULL,
    PROMISED_SHIP_DATE VARCHAR NOT NULL,
    ORDERED_UNITS VARCHAR NOT NULL,
    FULFILLED_UNITS VARCHAR NOT NULL,
    UNIT_SALE_PRICE_USD VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic downstream customer demand';


-- ---------------------------------------------------------------------------
-- 8. Shipments
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.SHIPMENTS (
    SHIPMENT_ID VARCHAR NOT NULL,
    SHIPMENT_TYPE VARCHAR NOT NULL,
    PURCHASE_ORDER_ID VARCHAR,
    CUSTOMER_ORDER_ID VARCHAR,
    PART_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    SUPPLIER_ID VARCHAR,
    CUSTOMER_ID VARCHAR,
    SHIP_DATE VARCHAR NOT NULL,
    PROMISED_DELIVERY_DATE VARCHAR NOT NULL,
    ACTUAL_DELIVERY_DATE VARCHAR,
    SHIPPED_UNITS VARCHAR NOT NULL,
    CARRIER VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic inbound and outbound shipment records';


-- ---------------------------------------------------------------------------
-- 9. Shipment Events
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.SHIPMENT_EVENTS (
    SHIPMENT_EVENT_ID VARCHAR NOT NULL,
    SHIPMENT_ID VARCHAR NOT NULL,
    EVENT_SEQUENCE VARCHAR NOT NULL,
    EVENT_TYPE VARCHAR NOT NULL,
    EVENT_TIMESTAMP VARCHAR NOT NULL,
    LOCATION_CODE VARCHAR NOT NULL,
    DELAY_REASON VARCHAR,
    SOURCE_SYSTEM VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic shipment lifecycle events';


-- ---------------------------------------------------------------------------
-- 10. Inventory Snapshots
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ONTARA.RAW.INVENTORY_SNAPSHOTS (
    SNAPSHOT_DATE VARCHAR NOT NULL,
    PLANT_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    ON_HAND_UNITS VARCHAR NOT NULL,
    ALLOCATED_UNITS VARCHAR NOT NULL,
    IN_TRANSIT_UNITS VARCHAR NOT NULL,
    SAFETY_STOCK_UNITS VARCHAR NOT NULL,
    AVG_DAILY_DEMAND_UNITS VARCHAR NOT NULL
)
COMMENT = 'RAW deterministic plant-part inventory snapshots';


-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------

SHOW TABLES
    IN SCHEMA ONTARA.RAW;