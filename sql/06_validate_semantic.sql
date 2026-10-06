-- Ontara governed semantic-layer validation
--
-- Semantic contract version: 1.0.0
--
-- Validates:
--   1. canonical metric values through the native Semantic View;
--   2. governed Supplier -> Part sourcing traversal;
--   3. deterministic blast-radius traversal.
--
-- Release condition:
--   FAILED_CHECKS = 0
--   OVERALL_STATUS = PASS


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;


CREATE OR REPLACE TEMPORARY TABLE SEMANTIC_VALIDATION_RESULTS (
    CHECK_CATEGORY VARCHAR NOT NULL,
    CHECK_NAME VARCHAR NOT NULL,
    EXPECTATION VARCHAR NOT NULL,
    ACTUAL_VALUE VARCHAR NOT NULL,
    STATUS VARCHAR NOT NULL,
    DETAIL VARCHAR
);


-- ===========================================================================
-- 1. CANONICAL METRIC CONTRACTS
-- ===========================================================================

INSERT INTO SEMANTIC_VALIDATION_RESULTS
SELECT
    'CANONICAL_METRIC',
    'OTD_V1',
    '89.47',
    TO_VARCHAR(ON_TIME_DELIVERY_PCT),
    IFF(ON_TIME_DELIVERY_PCT = 89.47, 'PASS', 'FAIL'),
    'Native Semantic View On-Time Delivery contract'
FROM (
    SELECT
        ROUND(ON_TIME_DELIVERY_PCT, 2) AS ON_TIME_DELIVERY_PCT
    FROM SEMANTIC_VIEW(
        ONTARA.SEMANTIC.SUPPLY_CHAIN
        METRICS shipments.on_time_delivery_pct
    )
)

UNION ALL

SELECT
    'CANONICAL_METRIC',
    'FILL_RATE_V1',
    '91.95',
    TO_VARCHAR(FILL_RATE_PCT),
    IFF(FILL_RATE_PCT = 91.95, 'PASS', 'FAIL'),
    'Native Semantic View quantity-weighted Fill Rate contract'
FROM (
    SELECT
        ROUND(FILL_RATE_PCT, 2) AS FILL_RATE_PCT
    FROM SEMANTIC_VIEW(
        ONTARA.SEMANTIC.SUPPLY_CHAIN
        METRICS customer_orders.fill_rate_pct
    )
)

UNION ALL

SELECT
    'CANONICAL_METRIC',
    'DOI_V1',
    '16.25',
    TO_VARCHAR(DAYS_OF_INVENTORY),
    IFF(DAYS_OF_INVENTORY = 16.25, 'PASS', 'FAIL'),
    'Native Semantic View latest-snapshot Days of Inventory contract'
FROM (
    SELECT
        ROUND(DAYS_OF_INVENTORY, 2) AS DAYS_OF_INVENTORY
    FROM SEMANTIC_VIEW(
        ONTARA.SEMANTIC.SUPPLY_CHAIN
        METRICS inventory_current.days_of_inventory
    )
)

UNION ALL

SELECT
    'CANONICAL_METRIC',
    'LANDED_COST_V1',
    '65.67',
    TO_VARCHAR(LANDED_COST_PER_UNIT_USD),
    IFF(LANDED_COST_PER_UNIT_USD = 65.67, 'PASS', 'FAIL'),
    'Native Semantic View quantity-weighted Landed Cost contract'
FROM (
    SELECT
        ROUND(LANDED_COST_PER_UNIT_USD, 2)
            AS LANDED_COST_PER_UNIT_USD
    FROM SEMANTIC_VIEW(
        ONTARA.SEMANTIC.SUPPLY_CHAIN
        METRICS purchase_orders.landed_cost_per_unit_usd
    )
);


-- ===========================================================================
-- 2. GOVERNED SUPPLIER -> PART SOURCING BRIDGE
-- ===========================================================================

INSERT INTO SEMANTIC_VALIDATION_RESULTS
SELECT
    'ONTOLOGY',
    'SUPPLIER_PART_BRIDGE',
    'exactly 1 governed row',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'SUP-003 -> PRT-009 must resolve through SUPPLIER_PARTS'
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    DIMENSIONS
        suppliers.supplier_id,
        suppliers.supplier_name,
        suppliers.risk_tier,
        suppliers.supplier_status,
        supplier_parts.part_id,
        parts.part_name,
        supplier_parts.primary_supplier_flag,
        supplier_parts.lead_time_days
    WHERE suppliers.supplier_id = 'SUP-003'
      AND suppliers.supplier_name = 'Orion Precision'
      AND suppliers.risk_tier = 'HIGH'
      AND suppliers.supplier_status = 'DISRUPTED'
      AND supplier_parts.part_id = 'PRT-009'
      AND parts.part_name = 'Servo Controller'
      AND supplier_parts.primary_supplier_flag = TRUE
      AND supplier_parts.lead_time_days = 21
);


-- ===========================================================================
-- 3. GOVERNED BLAST-RADIUS PATH
-- ===========================================================================

INSERT INTO SEMANTIC_VALIDATION_RESULTS
SELECT
    'ONTOLOGY',
    'CONTROLLED_BLAST_RADIUS',
    'exactly 1 governed path',
    TO_VARCHAR(COUNT(*)),
    IFF(COUNT(*) = 1, 'PASS', 'FAIL'),
    'SUP-003 -> PRT-009 -> PLT-003 -> SHP-OUT-008 -> ORD-008 -> CUS-003'
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    DIMENSIONS
        blast_radius_paths.supplier_id,
        blast_radius_paths.supplier_name,
        blast_radius_paths.risk_tier,
        blast_radius_paths.supplier_status,
        blast_radius_paths.part_id,
        blast_radius_paths.part_name,
        blast_radius_paths.plant_id,
        blast_radius_paths.plant_name,
        blast_radius_paths.shipment_id,
        blast_radius_paths.shipment_status,
        blast_radius_paths.order_id,
        blast_radius_paths.order_status,
        blast_radius_paths.customer_id,
        blast_radius_paths.customer_name,
        blast_radius_paths.priority_tier
    WHERE blast_radius_paths.supplier_id = 'SUP-003'
      AND blast_radius_paths.supplier_name = 'Orion Precision'
      AND blast_radius_paths.risk_tier = 'HIGH'
      AND blast_radius_paths.supplier_status = 'DISRUPTED'
      AND blast_radius_paths.part_id = 'PRT-009'
      AND blast_radius_paths.part_name = 'Servo Controller'
      AND blast_radius_paths.plant_id = 'PLT-003'
      AND blast_radius_paths.plant_name = 'Pune Manufacturing'
      AND blast_radius_paths.shipment_id = 'SHP-OUT-008'
      AND blast_radius_paths.shipment_status = 'DELIVERED'
      AND blast_radius_paths.order_id = 'ORD-008'
      AND blast_radius_paths.order_status = 'PARTIAL'
      AND blast_radius_paths.customer_id = 'CUS-003'
      AND blast_radius_paths.customer_name = 'Asterion Aerospace'
      AND blast_radius_paths.priority_tier = 'STRATEGIC'
);


-- ===========================================================================
-- 4. VALIDATION REPORT
-- ===========================================================================

SELECT
    CHECK_CATEGORY,
    CHECK_NAME,
    EXPECTATION,
    ACTUAL_VALUE,
    STATUS,
    DETAIL
FROM SEMANTIC_VALIDATION_RESULTS
ORDER BY
    CHECK_CATEGORY,
    CHECK_NAME;


-- ===========================================================================
-- 5. SEMANTIC RELEASE GATE
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
FROM SEMANTIC_VALIDATION_RESULTS;