-- ============================================================================
-- Ontara — Ontology Blast Radius Release Validation
-- ============================================================================
--
-- Validates the controlled SUP-003 disruption scenario against deterministic
-- governed outcomes produced by the Snowflake blast-radius model.
-- ============================================================================

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA SEMANTIC;


CREATE OR REPLACE TEMP TABLE BLAST_RADIUS_VALIDATION_RESULTS (
    CHECK_NAME VARCHAR,
    EXPECTED_VALUE VARCHAR,
    ACTUAL_VALUE VARCHAR,
    PASSED BOOLEAN
);


-- ============================================================================
-- 1. Disrupted supplier identity and state
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 disruption state',
    'Orion Precision | HIGH | DISRUPTED',
    CONCAT(
        SUPPLIER_NAME,
        ' | ',
        RISK_TIER,
        ' | ',
        SUPPLIER_STATUS
    ),
    SUPPLIER_NAME = 'Orion Precision'
        AND RISK_TIER = 'HIGH'
        AND SUPPLIER_STATUS = 'DISRUPTED'
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 2. Governed blast-radius footprint
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 downstream footprint',
    '3 parts | 3 plants | 12 orders | 6 customers | 2 strategic',
    CONCAT(
        AFFECTED_PARTS,
        ' parts | ',
        AFFECTED_PLANTS,
        ' plants | ',
        AFFECTED_ORDERS,
        ' orders | ',
        AFFECTED_CUSTOMERS,
        ' customers | ',
        STRATEGIC_CUSTOMERS_AFFECTED,
        ' strategic'
    ),
    AFFECTED_PARTS = 3
        AND AFFECTED_PLANTS = 3
        AND AFFECTED_ORDERS = 12
        AND AFFECTED_CUSTOMERS = 6
        AND STRATEGIC_CUSTOMERS_AFFECTED = 2
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 3. Commercial exposure
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 commercial exposure',
    '1410 affected | 235 outstanding | 231453.99 total | 36024.90 outstanding revenue',
    CONCAT(
        AFFECTED_ORDER_UNITS,
        ' affected | ',
        OUTSTANDING_ORDER_UNITS,
        ' outstanding | ',
        ROUND(TOTAL_ORDER_VALUE_EXPOSED_USD, 2),
        ' total | ',
        ROUND(OUTSTANDING_REVENUE_EXPOSURE_USD, 2),
        ' outstanding revenue'
    ),
    AFFECTED_ORDER_UNITS = 1410
        AND OUTSTANDING_ORDER_UNITS = 235
        AND ROUND(
            TOTAL_ORDER_VALUE_EXPOSED_USD,
            2
        ) = 231453.99
        AND ROUND(
            OUTSTANDING_REVENUE_EXPOSURE_USD,
            2
        ) = 36024.90
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 4. Inventory exposure
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 inventory exposure',
    '15 shortfall | 1 constrained part-plant | 0.42 lowest DOI',
    CONCAT(
        INVENTORY_SHORTFALL_UNITS,
        ' shortfall | ',
        PART_PLANT_SHORTFALLS,
        ' constrained part-plant | ',
        LOWEST_DAYS_OF_INVENTORY,
        ' lowest DOI'
    ),
    INVENTORY_SHORTFALL_UNITS = 15
        AND PART_PLANT_SHORTFALLS = 1
        AND ROUND(
            LOWEST_DAYS_OF_INVENTORY,
            2
        ) = 0.42
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 5. Sourcing resilience
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 sourcing resilience',
    '0 parts without active alternate | 16 day fastest alternate',
    CONCAT(
        PARTS_WITHOUT_ACTIVE_ALTERNATE,
        ' parts without active alternate | ',
        FASTEST_AVAILABLE_ALTERNATE_LEAD_TIME_DAYS,
        ' day fastest alternate'
    ),
    PARTS_WITHOUT_ACTIVE_ALTERNATE = 0
        AND FASTEST_AVAILABLE_ALTERNATE_LEAD_TIME_DAYS = 16
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 6. Risk and deterministic response
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'SUP-003 risk response',
    '1 logistics risk | max 90 | avg 63.33 | ESCALATE_AND_EXPEDITE',
    CONCAT(
        ORDERS_WITH_LOGISTICS_RISK,
        ' logistics risk | max ',
        MAX_IMPACT_RISK_SCORE,
        ' | avg ',
        AVG_IMPACT_RISK_SCORE,
        ' | ',
        RECOMMENDED_RESPONSE
    ),
    ORDERS_WITH_LOGISTICS_RISK = 1
        AND MAX_IMPACT_RISK_SCORE = 90
        AND ROUND(
            AVG_IMPACT_RISK_SCORE,
            2
        ) = 63.33
        AND RECOMMENDED_RESPONSE = 'ESCALATE_AND_EXPEDITE'
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
WHERE SUPPLIER_ID = 'SUP-003';


-- ============================================================================
-- 7. Controlled ontology path
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'Controlled SUP-003 to CUS-003 ontology path',
    'SUP-003 -> PRT-009 -> PLT-003 -> ORD-008 -> CUS-003',
    CONCAT(
        SUPPLIER_ID,
        ' -> ',
        PART_ID,
        ' -> ',
        PLANT_ID,
        ' -> ',
        ORDER_ID,
        ' -> ',
        CUSTOMER_ID
    ),
    SUPPLIER_ID = 'SUP-003'
        AND PART_ID = 'PRT-009'
        AND PLANT_ID = 'PLT-003'
        AND ORDER_ID = 'ORD-008'
        AND CUSTOMER_ID = 'CUS-003'
        AND CUSTOMER_NAME = 'Asterion Aerospace'
        AND CUSTOMER_PRIORITY_TIER = 'STRATEGIC'
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
WHERE SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND ORDER_ID = 'ORD-008';


-- ============================================================================
-- 8. Controlled commercial and inventory exposure
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'PRT-009 controlled order exposure',
    '100 ordered | 40 fulfilled | 60 outstanding | 13187.40 revenue | 15 inventory shortfall',
    CONCAT(
        ORDERED_UNITS,
        ' ordered | ',
        FULFILLED_UNITS,
        ' fulfilled | ',
        OUTSTANDING_ORDER_UNITS,
        ' outstanding | ',
        ROUND(
            OUTSTANDING_REVENUE_EXPOSURE_USD,
            2
        ),
        ' revenue | ',
        INVENTORY_SHORTFALL_TO_SAFETY_UNITS,
        ' inventory shortfall'
    ),
    ORDERED_UNITS = 100
        AND FULFILLED_UNITS = 40
        AND OUTSTANDING_ORDER_UNITS = 60
        AND ROUND(
            OUTSTANDING_REVENUE_EXPOSURE_USD,
            2
        ) = 13187.40
        AND AVAILABLE_INVENTORY_UNITS = 5
        AND SAFETY_STOCK_UNITS = 20
        AND INVENTORY_SHORTFALL_TO_SAFETY_UNITS = 15
        AND ROUND(
            DAYS_OF_INVENTORY,
            2
        ) = 0.42
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
WHERE SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND ORDER_ID = 'ORD-008';


-- ============================================================================
-- 9. Controlled risk classification
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'PRT-009 controlled risk classification',
    '90 | CRITICAL | 1 alternate | 17 day alternate',
    CONCAT(
        IMPACT_RISK_SCORE,
        ' | ',
        IMPACT_RISK_BAND,
        ' | ',
        ACTIVE_ALTERNATE_SUPPLIER_COUNT,
        ' alternate | ',
        FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        ' day alternate'
    ),
    IMPACT_RISK_SCORE = 90
        AND IMPACT_RISK_BAND = 'CRITICAL'
        AND ACTIVE_ALTERNATE_SUPPLIER_COUNT = 1
        AND FASTEST_ALTERNATE_LEAD_TIME_DAYS = 17
FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
WHERE SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND ORDER_ID = 'ORD-008';


-- ============================================================================
-- 10. Governed alternate supplier
-- ============================================================================

INSERT INTO BLAST_RADIUS_VALIDATION_RESULTS
SELECT
    'PRT-009 ranked alternate source',
    'SUP-006 Vertex Supply | ACTIVE | MEDIUM | 17 days | 116.50 USD | rank 1',
    CONCAT(
        ALTERNATE_SUPPLIER_ID,
        ' ',
        ALTERNATE_SUPPLIER_NAME,
        ' | ',
        ALTERNATE_SUPPLIER_STATUS,
        ' | ',
        ALTERNATE_SUPPLIER_RISK_TIER,
        ' | ',
        ALTERNATE_LEAD_TIME_DAYS,
        ' days | ',
        ALTERNATE_UNIT_COST_USD,
        ' USD | rank ',
        ALTERNATE_RANK
    ),
    ALTERNATE_SUPPLIER_ID = 'SUP-006'
        AND ALTERNATE_SUPPLIER_NAME = 'Vertex Supply'
        AND ALTERNATE_SUPPLIER_STATUS = 'ACTIVE'
        AND ALTERNATE_SUPPLIER_RISK_TIER = 'MEDIUM'
        AND ALTERNATE_LEAD_TIME_DAYS = 17
        AND ROUND(
            ALTERNATE_UNIT_COST_USD,
            2
        ) = 116.50
        AND LEAD_TIME_DELTA_DAYS = -4
        AND ROUND(
            UNIT_COST_DELTA_USD,
            2
        ) = 4.50
        AND ALTERNATE_RANK = 1
FROM ONTARA.SEMANTIC.SUPPLY_ALTERNATE_SOURCES
WHERE ORIGIN_SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND ALTERNATE_RANK = 1;


-- ============================================================================
-- Release-gate output
-- ============================================================================

SELECT
    CHECK_NAME,
    EXPECTED_VALUE,
    ACTUAL_VALUE,
    IFF(
        PASSED,
        'PASS',
        'FAIL'
    ) AS STATUS
FROM BLAST_RADIUS_VALIDATION_RESULTS
ORDER BY CHECK_NAME;


SELECT
    COUNT(*) AS TOTAL_CHECKS,
    COUNT_IF(PASSED) AS PASSED_CHECKS,
    COUNT_IF(NOT PASSED) AS FAILED_CHECKS,
    IFF(
        COUNT_IF(NOT PASSED) = 0
            AND COUNT(*) = 10,
        'PASS',
        'FAIL'
    ) AS OVERALL_STATUS
FROM BLAST_RADIUS_VALIDATION_RESULTS;