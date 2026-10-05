-- Ontara governed CORE validation contract
--
-- Purpose:
--   Validate deterministic row counts, uniqueness, referential integrity,
--   business invariants, metric prerequisites, and controlled disruption
--   scenarios before the semantic layer is allowed to depend on CORE.
--
-- Result:
--   Every validation produces PASS or FAIL.
--   The final summary must report:
--
--       FAILED_CHECKS = 0
--       OVERALL_STATUS = PASS
--
-- Execution role:
--   ONTARA_DEV_ROLE


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA CORE;


CREATE OR REPLACE TEMPORARY TABLE VALIDATION_RESULTS (
    CHECK_CATEGORY VARCHAR NOT NULL,
    CHECK_NAME VARCHAR NOT NULL,
    EXPECTATION VARCHAR NOT NULL,
    ACTUAL_VALUE VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL,
    DETAIL VARCHAR
);


-- ===========================================================================
-- 1. DETERMINISTIC ROW COUNTS
-- ===========================================================================

INSERT INTO VALIDATION_RESULTS
SELECT
    'ROW_COUNT',
    'SUPPLIERS',
    '8 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 8, 'PASS', 'FAIL'),
    'Deterministic supplier master'
FROM ONTARA.CORE.SUPPLIERS

UNION ALL

SELECT
    'ROW_COUNT',
    'PARTS',
    '12 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 12, 'PASS', 'FAIL'),
    'Deterministic part master'
FROM ONTARA.CORE.PARTS

UNION ALL

SELECT
    'ROW_COUNT',
    'PLANTS',
    '4 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 4, 'PASS', 'FAIL'),
    'Deterministic plant master'
FROM ONTARA.CORE.PLANTS

UNION ALL

SELECT
    'ROW_COUNT',
    'SUPPLIER_PARTS',
    '23 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 23, 'PASS', 'FAIL'),
    'Deterministic supplier-to-part relationships'
FROM ONTARA.CORE.SUPPLIER_PARTS

UNION ALL

SELECT
    'ROW_COUNT',
    'PURCHASE_ORDERS',
    '24 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 24, 'PASS', 'FAIL'),
    'Deterministic inbound purchase orders'
FROM ONTARA.CORE.PURCHASE_ORDERS

UNION ALL

SELECT
    'ROW_COUNT',
    'CUSTOMERS',
    '10 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 10, 'PASS', 'FAIL'),
    'Deterministic customer master'
FROM ONTARA.CORE.CUSTOMERS

UNION ALL

SELECT
    'ROW_COUNT',
    'CUSTOMER_ORDERS',
    '30 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 30, 'PASS', 'FAIL'),
    'Deterministic downstream demand'
FROM ONTARA.CORE.CUSTOMER_ORDERS

UNION ALL

SELECT
    'ROW_COUNT',
    'SHIPMENTS',
    '32 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 32, 'PASS', 'FAIL'),
    'Deterministic inbound and outbound shipments'
FROM ONTARA.CORE.SHIPMENTS

UNION ALL

SELECT
    'ROW_COUNT',
    'SHIPMENT_EVENTS',
    '192 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 192, 'PASS', 'FAIL'),
    'Deterministic shipment lifecycle'
FROM ONTARA.CORE.SHIPMENT_EVENTS

UNION ALL

SELECT
    'ROW_COUNT',
    'INVENTORY_SNAPSHOTS',
    '48 rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 48, 'PASS', 'FAIL'),
    'Deterministic inventory snapshots'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS;


-- ===========================================================================
-- 2. KEY UNIQUENESS
-- ===========================================================================

INSERT INTO VALIDATION_RESULTS
SELECT
    'UNIQUENESS',
    'SUPPLIER_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'SUPPLIERS.SUPPLIER_ID'
FROM (
    SELECT SUPPLIER_ID
    FROM ONTARA.CORE.SUPPLIERS
    GROUP BY SUPPLIER_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'PART_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'PARTS.PART_ID'
FROM (
    SELECT PART_ID
    FROM ONTARA.CORE.PARTS
    GROUP BY PART_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'PLANT_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'PLANTS.PLANT_ID'
FROM (
    SELECT PLANT_ID
    FROM ONTARA.CORE.PLANTS
    GROUP BY PLANT_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'CUSTOMER_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'CUSTOMERS.CUSTOMER_ID'
FROM (
    SELECT CUSTOMER_ID
    FROM ONTARA.CORE.CUSTOMERS
    GROUP BY CUSTOMER_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'PURCHASE_ORDER_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'PURCHASE_ORDERS.PURCHASE_ORDER_ID'
FROM (
    SELECT PURCHASE_ORDER_ID
    FROM ONTARA.CORE.PURCHASE_ORDERS
    GROUP BY PURCHASE_ORDER_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'ORDER_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'CUSTOMER_ORDERS.ORDER_ID'
FROM (
    SELECT ORDER_ID
    FROM ONTARA.CORE.CUSTOMER_ORDERS
    GROUP BY ORDER_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'SHIPMENT_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'SHIPMENTS.SHIPMENT_ID'
FROM (
    SELECT SHIPMENT_ID
    FROM ONTARA.CORE.SHIPMENTS
    GROUP BY SHIPMENT_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'SHIPMENT_EVENT_ID',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'SHIPMENT_EVENTS.SHIPMENT_EVENT_ID'
FROM (
    SELECT SHIPMENT_EVENT_ID
    FROM ONTARA.CORE.SHIPMENT_EVENTS
    GROUP BY SHIPMENT_EVENT_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'SUPPLIER_PART_PAIR',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'SUPPLIER_PARTS composite supplier-part key'
FROM (
    SELECT SUPPLIER_ID, PART_ID
    FROM ONTARA.CORE.SUPPLIER_PARTS
    GROUP BY SUPPLIER_ID, PART_ID
    HAVING COUNT(*) > 1
)

UNION ALL

SELECT
    'UNIQUENESS',
    'INVENTORY_SNAPSHOT_KEY',
    '0 duplicate keys',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'INVENTORY_SNAPSHOTS snapshot-date plant-part key'
FROM (
    SELECT SNAPSHOT_DATE, PLANT_ID, PART_ID
    FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
    GROUP BY SNAPSHOT_DATE, PLANT_ID, PART_ID
    HAVING COUNT(*) > 1
);


-- ===========================================================================
-- 3. REFERENTIAL INTEGRITY
-- ===========================================================================

INSERT INTO VALIDATION_RESULTS
SELECT
    'REFERENTIAL',
    'SUPPLIER_PARTS_TO_SUPPLIER',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every sourcing relationship resolves to a supplier'
FROM ONTARA.CORE.SUPPLIER_PARTS sp
LEFT JOIN ONTARA.CORE.SUPPLIERS s
    ON s.SUPPLIER_ID = sp.SUPPLIER_ID
WHERE s.SUPPLIER_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SUPPLIER_PARTS_TO_PART',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every sourcing relationship resolves to a part'
FROM ONTARA.CORE.SUPPLIER_PARTS sp
LEFT JOIN ONTARA.CORE.PARTS p
    ON p.PART_ID = sp.PART_ID
WHERE p.PART_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'PURCHASE_ORDER_TO_SUPPLIER',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every purchase order resolves to a supplier'
FROM ONTARA.CORE.PURCHASE_ORDERS po
LEFT JOIN ONTARA.CORE.SUPPLIERS s
    ON s.SUPPLIER_ID = po.SUPPLIER_ID
WHERE s.SUPPLIER_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'PURCHASE_ORDER_TO_PLANT',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every purchase order resolves to a plant'
FROM ONTARA.CORE.PURCHASE_ORDERS po
LEFT JOIN ONTARA.CORE.PLANTS p
    ON p.PLANT_ID = po.PLANT_ID
WHERE p.PLANT_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'PURCHASE_ORDER_TO_PART',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every purchase order resolves to a part'
FROM ONTARA.CORE.PURCHASE_ORDERS po
LEFT JOIN ONTARA.CORE.PARTS p
    ON p.PART_ID = po.PART_ID
WHERE p.PART_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'CUSTOMER_ORDER_TO_CUSTOMER',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every customer order resolves to a customer'
FROM ONTARA.CORE.CUSTOMER_ORDERS co
LEFT JOIN ONTARA.CORE.CUSTOMERS c
    ON c.CUSTOMER_ID = co.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'CUSTOMER_ORDER_TO_PLANT',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every customer order resolves to a plant'
FROM ONTARA.CORE.CUSTOMER_ORDERS co
LEFT JOIN ONTARA.CORE.PLANTS p
    ON p.PLANT_ID = co.PLANT_ID
WHERE p.PLANT_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'CUSTOMER_ORDER_TO_PART',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every customer order resolves to a part'
FROM ONTARA.CORE.CUSTOMER_ORDERS co
LEFT JOIN ONTARA.CORE.PARTS p
    ON p.PART_ID = co.PART_ID
WHERE p.PART_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SHIPMENT_TO_PART',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every shipment resolves to a part'
FROM ONTARA.CORE.SHIPMENTS sh
LEFT JOIN ONTARA.CORE.PARTS p
    ON p.PART_ID = sh.PART_ID
WHERE p.PART_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SHIPMENT_TO_PLANT',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every shipment resolves to a plant'
FROM ONTARA.CORE.SHIPMENTS sh
LEFT JOIN ONTARA.CORE.PLANTS p
    ON p.PLANT_ID = sh.PLANT_ID
WHERE p.PLANT_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SHIPMENT_TO_PURCHASE_ORDER',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every populated inbound purchase-order reference resolves'
FROM ONTARA.CORE.SHIPMENTS sh
LEFT JOIN ONTARA.CORE.PURCHASE_ORDERS po
    ON po.PURCHASE_ORDER_ID = sh.PURCHASE_ORDER_ID
WHERE sh.PURCHASE_ORDER_ID IS NOT NULL
  AND po.PURCHASE_ORDER_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SHIPMENT_TO_CUSTOMER_ORDER',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every populated customer-order reference resolves'
FROM ONTARA.CORE.SHIPMENTS sh
LEFT JOIN ONTARA.CORE.CUSTOMER_ORDERS co
    ON co.ORDER_ID = sh.CUSTOMER_ORDER_ID
WHERE sh.CUSTOMER_ORDER_ID IS NOT NULL
  AND co.ORDER_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'SHIPMENT_EVENT_TO_SHIPMENT',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every shipment event resolves to a shipment'
FROM ONTARA.CORE.SHIPMENT_EVENTS se
LEFT JOIN ONTARA.CORE.SHIPMENTS sh
    ON sh.SHIPMENT_ID = se.SHIPMENT_ID
WHERE sh.SHIPMENT_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'INVENTORY_TO_PLANT',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every inventory snapshot resolves to a plant'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS i
LEFT JOIN ONTARA.CORE.PLANTS p
    ON p.PLANT_ID = i.PLANT_ID
WHERE p.PLANT_ID IS NULL

UNION ALL

SELECT
    'REFERENTIAL',
    'INVENTORY_TO_PART',
    '0 orphan rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Every inventory snapshot resolves to a part'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS i
LEFT JOIN ONTARA.CORE.PARTS p
    ON p.PART_ID = i.PART_ID
WHERE p.PART_ID IS NULL;


-- ===========================================================================
-- 4. BUSINESS AND METRIC INVARIANTS
-- ===========================================================================

INSERT INTO VALIDATION_RESULTS
SELECT
    'BUSINESS_RULE',
    'CUSTOMER_ORDER_QUANTITIES',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Ordered units must be positive and fulfilled units within order quantity'
FROM ONTARA.CORE.CUSTOMER_ORDERS
WHERE ORDERED_UNITS <= 0
   OR FULFILLED_UNITS < 0
   OR FULFILLED_UNITS > ORDERED_UNITS

UNION ALL

SELECT
    'BUSINESS_RULE',
    'PURCHASE_ORDER_QUANTITIES',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Ordered units must be positive and received units within order quantity'
FROM ONTARA.CORE.PURCHASE_ORDERS
WHERE ORDERED_UNITS <= 0
   OR RECEIVED_UNITS < 0
   OR RECEIVED_UNITS > ORDERED_UNITS

UNION ALL

SELECT
    'BUSINESS_RULE',
    'PURCHASE_ORDER_COSTS',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Landed-cost inputs cannot be negative'
FROM ONTARA.CORE.PURCHASE_ORDERS
WHERE UNIT_PURCHASE_COST_USD < 0
   OR FREIGHT_COST_USD < 0
   OR DUTY_COST_USD < 0
   OR HANDLING_COST_USD < 0

UNION ALL

SELECT
    'BUSINESS_RULE',
    'INVENTORY_VALUES',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Inventory quantities cannot be negative'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
WHERE ON_HAND_UNITS < 0
   OR ALLOCATED_UNITS < 0
   OR IN_TRANSIT_UNITS < 0
   OR SAFETY_STOCK_UNITS < 0

UNION ALL

SELECT
    'METRIC_PREREQUISITE',
    'DAYS_OF_INVENTORY_DENOMINATOR',
    '0 zero-or-negative demand rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Average daily demand must support deterministic DOI calculation'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
WHERE AVG_DAILY_DEMAND_UNITS <= 0

UNION ALL

SELECT
    'METRIC_PREREQUISITE',
    'FILL_RATE_DENOMINATOR',
    '0 zero-or-negative ordered-unit rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Customer order quantity must support governed fill-rate calculation'
FROM ONTARA.CORE.CUSTOMER_ORDERS
WHERE ORDERED_UNITS <= 0

UNION ALL

SELECT
    'METRIC_PREREQUISITE',
    'LANDED_COST_DENOMINATOR',
    '0 zero-or-negative ordered-unit rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Purchase-order quantity must support governed landed-cost-per-unit calculation'
FROM ONTARA.CORE.PURCHASE_ORDERS
WHERE ORDERED_UNITS <= 0

UNION ALL

SELECT
    'BUSINESS_RULE',
    'SHIPMENT_QUANTITIES',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Shipped units must be positive'
FROM ONTARA.CORE.SHIPMENTS
WHERE SHIPPED_UNITS <= 0

UNION ALL

SELECT
    'BUSINESS_RULE',
    'SHIPMENT_DATE_ORDERING',
    '0 invalid rows',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 0, 'PASS', 'FAIL'),
    'Actual delivery cannot precede ship date'
FROM ONTARA.CORE.SHIPMENTS
WHERE ACTUAL_DELIVERY_DATE IS NOT NULL
  AND ACTUAL_DELIVERY_DATE < SHIP_DATE;


-- ===========================================================================
-- 5. CONTROLLED SCENARIOS
-- ===========================================================================

INSERT INTO VALIDATION_RESULTS
SELECT
    'CONTROLLED_SCENARIO',
    'DISRUPTED_SUPPLIER',
    'exactly 1 matching row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'SUP-003 must remain HIGH risk and DISRUPTED'
FROM ONTARA.CORE.SUPPLIERS
WHERE SUPPLIER_ID = 'SUP-003'
  AND RISK_TIER = 'HIGH'
  AND STATUS = 'DISRUPTED'

UNION ALL

SELECT
    'CONTROLLED_SCENARIO',
    'PARTIAL_STRATEGIC_ORDER',
    'exactly 1 matching row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'ORD-008 is the governed partial strategic-customer exposure scenario'
FROM ONTARA.CORE.CUSTOMER_ORDERS co
JOIN ONTARA.CORE.CUSTOMERS c
    ON c.CUSTOMER_ID = co.CUSTOMER_ID
WHERE co.ORDER_ID = 'ORD-008'
  AND co.CUSTOMER_ID = 'CUS-003'
  AND co.PLANT_ID = 'PLT-003'
  AND co.PART_ID = 'PRT-009'
  AND co.ORDERED_UNITS = 100
  AND co.FULFILLED_UNITS = 40
  AND co.STATUS = 'PARTIAL'
  AND c.PRIORITY_TIER = 'STRATEGIC'

UNION ALL

SELECT
    'CONTROLLED_SCENARIO',
    'LATE_OUTBOUND_SHIPMENT',
    'exactly 1 matching row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'SHP-OUT-006 must remain a late delivered shipment for OTD testing'
FROM ONTARA.CORE.SHIPMENTS
WHERE SHIPMENT_ID = 'SHP-OUT-006'
  AND ACTUAL_DELIVERY_DATE IS NOT NULL
  AND ACTUAL_DELIVERY_DATE > PROMISED_DELIVERY_DATE

UNION ALL

SELECT
    'CONTROLLED_SCENARIO',
    'LOW_INVENTORY_EXPOSURE',
    'exactly 1 matching row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'PLT-003 and PRT-009 must preserve the shortage-risk snapshot'
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
WHERE PLANT_ID = 'PLT-003'
  AND PART_ID = 'PRT-009'
  AND ON_HAND_UNITS = 30
  AND ALLOCATED_UNITS = 25
  AND IN_TRANSIT_UNITS = 40
  AND SAFETY_STOCK_UNITS = 20
  AND AVG_DAILY_DEMAND_UNITS = 12.00

UNION ALL

SELECT
    'CONTROLLED_SCENARIO',
    'ONTOLOGY_DISRUPTION_PATH',
    'exactly 1 matching row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'SUP-003 -> PRT-009 -> PLT-003 -> ORD-008 -> CUS-003'
FROM ONTARA.CORE.SUPPLIERS s
JOIN ONTARA.CORE.SUPPLIER_PARTS sp
    ON sp.SUPPLIER_ID = s.SUPPLIER_ID
JOIN ONTARA.CORE.CUSTOMER_ORDERS co
    ON co.PART_ID = sp.PART_ID
JOIN ONTARA.CORE.CUSTOMERS c
    ON c.CUSTOMER_ID = co.CUSTOMER_ID
WHERE s.SUPPLIER_ID = 'SUP-003'
  AND sp.PART_ID = 'PRT-009'
  AND co.PLANT_ID = 'PLT-003'
  AND co.ORDER_ID = 'ORD-008'
  AND c.CUSTOMER_ID = 'CUS-003';


-- ===========================================================================
-- 6. FULL VALIDATION REPORT
-- ===========================================================================

SELECT
    CHECK_CATEGORY,
    CHECK_NAME,
    EXPECTATION,
    ACTUAL_VALUE,
    STATUS,
    DETAIL
FROM VALIDATION_RESULTS
ORDER BY
    CHECK_CATEGORY,
    CHECK_NAME;


-- ===========================================================================
-- 7. RELEASE GATE
-- ===========================================================================

SELECT
    COUNT(*) AS TOTAL_CHECKS,
    COUNT_IF(STATUS = 'PASS') AS PASSED_CHECKS,
    COUNT_IF(STATUS = 'FAIL') AS FAILED_CHECKS,
    IFF(
        COUNT_IF(STATUS = 'FAIL') = 0,
        'PASS',
        'FAIL'
    ) AS OVERALL_STATUS
FROM VALIDATION_RESULTS;