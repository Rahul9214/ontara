-- ============================================================================
-- Ontara — Governed Action Loop Release Validation
-- ============================================================================
--
-- Validates:
--   1. Governed evidence hydration
--   2. Pending human approval
--   3. Pre-approval execution blocking
--   4. Idempotent request handling
--   5. Human approval
--   6. Controlled execution transition
--   7. Resolution transition
--   8. Complete append-only event sequence
--   9. Action Center enrichment
--  10. Rejection path and execution blocking
--
-- Validation uses dedicated request keys and removes only validation fixtures.
-- ============================================================================

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA GOVERNANCE;


CREATE OR REPLACE TEMP TABLE GOVERNED_ACTION_VALIDATION_RESULTS (
    CHECK_NAME VARCHAR,
    EXPECTED_VALUE VARCHAR,
    ACTUAL_VALUE VARCHAR,
    PASSED BOOLEAN
);


-- ============================================================================
-- Validation fixtures
-- ============================================================================

SET APPROVE_REQUEST_KEY = 'ONTARA-VALIDATION-ACTION-APPROVE-V1';
SET REJECT_REQUEST_KEY = 'ONTARA-VALIDATION-ACTION-REJECT-V1';


-- Remove only previous dedicated validation fixtures so this release gate
-- remains rerunnable. Production/demo actions are never touched.

DELETE FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS
WHERE EXCEPTION_ID IN (
    SELECT EXCEPTION_ID
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE REQUEST_KEY IN (
        $APPROVE_REQUEST_KEY,
        $REJECT_REQUEST_KEY
    )
);

DELETE FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
WHERE REQUEST_KEY IN (
    $APPROVE_REQUEST_KEY,
    $REJECT_REQUEST_KEY
);


-- ============================================================================
-- APPROVAL LIFECYCLE SCENARIO
-- ============================================================================

CALL ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
    $APPROVE_REQUEST_KEY,
    'SUP-003',
    'PRT-009',
    'ORD-008',
    'SUPPLIER_DISRUPTION',
    'Validation: critical Servo Controller disruption',
    'Expedite mitigation and evaluate governed alternate supplier SUP-006 Vertex Supply',
    'What is the downstream impact of disrupted supplier SUP-003 on part PRT-009?',
    'ontara_validation'
);


-- ============================================================================
-- 1. Governed evidence is copied from semantic truth
-- ============================================================================

INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Governed evidence hydration',
    'SUP-003 | PRT-009 | ORD-008 | 90 | CRITICAL | 60 units | 13187.40 USD | 15 shortfall | 0.42 DOI',
    CONCAT(
        SUPPLIER_ID,
        ' | ',
        PART_ID,
        ' | ',
        ORDER_ID,
        ' | ',
        RISK_SCORE,
        ' | ',
        RISK_BAND,
        ' | ',
        OUTSTANDING_UNITS,
        ' units | ',
        REVENUE_EXPOSURE_USD,
        ' USD | ',
        INVENTORY_SHORTFALL_UNITS,
        ' shortfall | ',
        DAYS_OF_INVENTORY,
        ' DOI'
    ),
    SUPPLIER_ID = 'SUP-003'
        AND PART_ID = 'PRT-009'
        AND PLANT_ID = 'PLT-003'
        AND ORDER_ID = 'ORD-008'
        AND CUSTOMER_ID = 'CUS-003'
        AND RISK_SCORE = 90
        AND RISK_BAND = 'CRITICAL'
        AND OUTSTANDING_UNITS = 60
        AND ROUND(REVENUE_EXPOSURE_USD, 2) = 13187.40
        AND AVAILABLE_INVENTORY_UNITS = 5
        AND SAFETY_STOCK_UNITS = 20
        AND INVENTORY_SHORTFALL_UNITS = 15
        AND ROUND(DAYS_OF_INVENTORY, 2) = 0.42
        AND ACTIVE_ALTERNATE_SUPPLIER_COUNT = 1
        AND FASTEST_ALTERNATE_LEAD_TIME_DAYS = 17
        AND RECOMMENDED_RESPONSE = 'ESCALATE_AND_EXPEDITE'
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY;


-- ============================================================================
-- 2. New action requires human approval
-- ============================================================================

INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Human approval starts pending',
    'PENDING_APPROVAL | PENDING | 1 REQUESTED event',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        COUNT(event.EVENT_ID),
        ' REQUESTED event'
    ),
    exception.STATUS = 'PENDING_APPROVAL'
        AND exception.APPROVAL_STATUS = 'PENDING'
        AND COUNT(event.EVENT_ID) = 1
        AND MIN(event.EVENT_TYPE) = 'REQUESTED'
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS;


-- ============================================================================
-- 3. Execution before human approval must be blocked
-- ============================================================================

CALL ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY
    ),
    'IN_PROGRESS',
    'ontara_validation',
    'Validation attempt before human approval'
);


INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Pre-approval execution guardrail',
    'PENDING_APPROVAL | PENDING | 1 event',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        COUNT(event.EVENT_ID),
        ' event'
    ),
    exception.STATUS = 'PENDING_APPROVAL'
        AND exception.APPROVAL_STATUS = 'PENDING'
        AND COUNT(event.EVENT_ID) = 1
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS;


-- ============================================================================
-- 4. Request retry must be idempotent
-- ============================================================================

CALL ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
    $APPROVE_REQUEST_KEY,
    'SUP-003',
    'PRT-009',
    'ORD-008',
    'SUPPLIER_DISRUPTION',
    'Validation: critical Servo Controller disruption',
    'Expedite mitigation and evaluate governed alternate supplier SUP-006 Vertex Supply',
    'What is the downstream impact of disrupted supplier SUP-003 on part PRT-009?',
    'ontara_validation'
);


INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Idempotent governed request',
    '1 exception | 1 event',
    CONCAT(
        exception_count,
        ' exception | ',
        event_count,
        ' event'
    ),
    exception_count = 1
        AND event_count = 1
FROM (
    SELECT
        COUNT(DISTINCT exception.EXCEPTION_ID)
            AS exception_count,
        COUNT(event.EVENT_ID)
            AS event_count
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
    LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
        ON event.EXCEPTION_ID = exception.EXCEPTION_ID
    WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
);


-- ============================================================================
-- 5. Human approval
-- ============================================================================

CALL ONTARA.GOVERNANCE.DECIDE_SUPPLY_EXCEPTION(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY
    ),
    'APPROVE',
    'ontara_validation_reviewer',
    'Validation human approval'
);


INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Human approval decision',
    'APPROVED | APPROVED | reviewer persisted | 2 events',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        exception.APPROVED_BY,
        ' | ',
        COUNT(event.EVENT_ID),
        ' events'
    ),
    exception.STATUS = 'APPROVED'
        AND exception.APPROVAL_STATUS = 'APPROVED'
        AND exception.APPROVED_BY = 'ontara_validation_reviewer'
        AND exception.APPROVED_AT IS NOT NULL
        AND COUNT(event.EVENT_ID) = 2
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS,
    exception.APPROVED_BY,
    exception.APPROVED_AT;


-- ============================================================================
-- 6. Approved action may move to IN_PROGRESS
-- ============================================================================

CALL ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY
    ),
    'IN_PROGRESS',
    'ontara_validation_operator',
    'Validation execution started'
);


INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Approved execution transition',
    'IN_PROGRESS | APPROVED | 3 events',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        COUNT(event.EVENT_ID),
        ' events'
    ),
    exception.STATUS = 'IN_PROGRESS'
        AND exception.APPROVAL_STATUS = 'APPROVED'
        AND COUNT(event.EVENT_ID) = 3
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS;


-- ============================================================================
-- 7. IN_PROGRESS may move to RESOLVED
-- ============================================================================

CALL ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY
    ),
    'RESOLVED',
    'ontara_validation_operator',
    'Validation remediation completed'
);


INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Controlled resolution transition',
    'RESOLVED | APPROVED | 4 events',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        COUNT(event.EVENT_ID),
        ' events'
    ),
    exception.STATUS = 'RESOLVED'
        AND exception.APPROVAL_STATUS = 'APPROVED'
        AND COUNT(event.EVENT_ID) = 4
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $APPROVE_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS;


-- ============================================================================
-- 8. Complete event lineage
-- ============================================================================

INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Append-only lifecycle lineage',
    'REQUESTED -> APPROVED -> STATUS_CHANGED -> STATUS_CHANGED',
    event_sequence,
    event_sequence =
        'REQUESTED -> APPROVED -> STATUS_CHANGED -> STATUS_CHANGED'
FROM (
    SELECT
        LISTAGG(
            EVENT_TYPE,
            ' -> '
        ) WITHIN GROUP (
            ORDER BY EVENT_AT, EVENT_ID
        ) AS event_sequence
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS
    WHERE EXCEPTION_ID = (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY
    )
);


-- ============================================================================
-- 9. Action Center exposes governed business context
-- ============================================================================

INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Action Center governed context',
    'Orion Precision | Servo Controller | Pune Manufacturing | Asterion Aerospace | STRATEGIC | RESOLVED',
    CONCAT(
        SUPPLIER_NAME,
        ' | ',
        PART_NAME,
        ' | ',
        PLANT_NAME,
        ' | ',
        CUSTOMER_NAME,
        ' | ',
        CUSTOMER_PRIORITY_TIER,
        ' | ',
        STATUS
    ),
    SUPPLIER_NAME = 'Orion Precision'
        AND PART_NAME = 'Servo Controller'
        AND PLANT_NAME = 'Pune Manufacturing'
        AND CUSTOMER_NAME = 'Asterion Aerospace'
        AND CUSTOMER_PRIORITY_TIER = 'STRATEGIC'
        AND STATUS = 'RESOLVED'
        AND SEMANTIC_CONTRACT_VERSION = '1.0.0'
        AND LAST_EVENT_TYPE = 'STATUS_CHANGED'
FROM ONTARA.GOVERNANCE.ACTION_CENTER
WHERE REQUEST_KEY = $APPROVE_REQUEST_KEY;


-- ============================================================================
-- REJECTION SCENARIO
-- ============================================================================

CALL ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
    $REJECT_REQUEST_KEY,
    'SUP-003',
    'PRT-009',
    'ORD-008',
    'SUPPLIER_DISRUPTION',
    'Validation: rejected supply action',
    'Evaluate alternate supplier',
    'Validation rejection path',
    'ontara_validation'
);


CALL ONTARA.GOVERNANCE.DECIDE_SUPPLY_EXCEPTION(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $REJECT_REQUEST_KEY
    ),
    'REJECT',
    'ontara_validation_reviewer',
    'Validation reviewer rejected action'
);


-- Attempt execution after rejection. It must not change persisted state.

CALL ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
    (
        SELECT EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = $REJECT_REQUEST_KEY
    ),
    'IN_PROGRESS',
    'ontara_validation_operator',
    'Validation execution attempt after rejection'
);


-- ============================================================================
-- 10. Rejection remains terminal for execution
-- ============================================================================

INSERT INTO GOVERNED_ACTION_VALIDATION_RESULTS
SELECT
    'Rejected action execution guardrail',
    'REJECTED | REJECTED | reviewer persisted | 2 events',
    CONCAT(
        exception.STATUS,
        ' | ',
        exception.APPROVAL_STATUS,
        ' | ',
        exception.REJECTED_BY,
        ' | ',
        COUNT(event.EVENT_ID),
        ' events'
    ),
    exception.STATUS = 'REJECTED'
        AND exception.APPROVAL_STATUS = 'REJECTED'
        AND exception.REJECTED_BY = 'ontara_validation_reviewer'
        AND exception.REJECTED_AT IS NOT NULL
        AND COUNT(event.EVENT_ID) = 2
FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception
LEFT JOIN ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS event
    ON event.EXCEPTION_ID = exception.EXCEPTION_ID
WHERE exception.REQUEST_KEY = $REJECT_REQUEST_KEY
GROUP BY
    exception.STATUS,
    exception.APPROVAL_STATUS,
    exception.REJECTED_BY,
    exception.REJECTED_AT;


-- ============================================================================
-- Release-gate detail
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
FROM GOVERNED_ACTION_VALIDATION_RESULTS
ORDER BY CHECK_NAME;


-- ============================================================================
-- Release-gate summary
-- ============================================================================

SELECT
    COUNT(*) AS TOTAL_CHECKS,
    COUNT_IF(PASSED) AS PASSED_CHECKS,
    COUNT_IF(NOT PASSED) AS FAILED_CHECKS,
    IFF(
        COUNT(*) = 10
        AND COUNT_IF(NOT PASSED) = 0,
        'PASS',
        'FAIL'
    ) AS OVERALL_STATUS
FROM GOVERNED_ACTION_VALIDATION_RESULTS;


-- ============================================================================
-- Validation-fixture cleanup
-- ============================================================================
--
-- Only dedicated ONTARA-VALIDATION-* fixtures are removed.
-- The real demo action and its audit history remain persisted.
-- ============================================================================

DELETE FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS
WHERE EXCEPTION_ID IN (
    SELECT EXCEPTION_ID
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE REQUEST_KEY IN (
        $APPROVE_REQUEST_KEY,
        $REJECT_REQUEST_KEY
    )
);

DELETE FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
WHERE REQUEST_KEY IN (
    $APPROVE_REQUEST_KEY,
    $REJECT_REQUEST_KEY
);