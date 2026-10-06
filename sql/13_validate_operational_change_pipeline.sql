-- Ontara operational change-pipeline validation.
--
-- Non-mutating checks for the production Dynamic Table / Stream / Task pipeline.

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;

-- 1. Controlled source baseline must be restored.
SELECT
    'SOURCE_BASELINE' AS CHECK_NAME,
    IFF(
        ON_HAND_UNITS = 30
        AND ALLOCATED_UNITS = 25
        AND ON_HAND_UNITS - ALLOCATED_UNITS = 5
        AND SAFETY_STOCK_UNITS = 20,
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'on_hand_units', ON_HAND_UNITS,
        'allocated_units', ALLOCATED_UNITS,
        'available_units', ON_HAND_UNITS - ALLOCATED_UNITS,
        'safety_stock_units', SAFETY_STOCK_UNITS
    ) AS DETAILS
FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
WHERE SNAPSHOT_DATE = '2026-09-30'
  AND PLANT_ID = 'PLT-003'
  AND PART_ID = 'PRT-009'
;

-- 2. Controlled governed state must match the validated baseline.
SELECT
    'GOVERNED_BASELINE' AS CHECK_NAME,
    IFF(
        AVAILABLE_INVENTORY_UNITS = 5
        AND INVENTORY_SHORTFALL_TO_SAFETY_UNITS = 15
        AND DAYS_OF_INVENTORY = 0.42
        AND IMPACT_RISK_SCORE = 90
        AND IMPACT_RISK_BAND = 'CRITICAL'
        AND OPERATIONAL_HEALTH_STATUS = 'CRITICAL'
        AND RECOMMENDED_RESPONSE = 'ESCALATE_AND_EXPEDITE',
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'available_inventory_units', AVAILABLE_INVENTORY_UNITS,
        'inventory_shortfall_units', INVENTORY_SHORTFALL_TO_SAFETY_UNITS,
        'days_of_inventory', DAYS_OF_INVENTORY,
        'impact_risk_score', IMPACT_RISK_SCORE,
        'impact_risk_band', IMPACT_RISK_BAND,
        'operational_health_status', OPERATIONAL_HEALTH_STATUS,
        'recommended_response', RECOMMENDED_RESPONSE
    ) AS DETAILS
FROM ONTARA.SEMANTIC.OPERATIONAL_SUPPLY_HEALTH
WHERE SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND PLANT_ID = 'PLT-003'
  AND ORDER_ID = 'ORD-008'
;

-- 3. Stream should be empty after the validated round trip.
SELECT
    'STREAM_EMPTY_AFTER_ROUNDTRIP' AS CHECK_NAME,
    IFF(
        NOT SYSTEM$STREAM_HAS_DATA(
            'ONTARA.GOVERNANCE.SUPPLY_HEALTH_STREAM'
        ),
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'stream_has_data',
        SYSTEM$STREAM_HAS_DATA(
            'ONTARA.GOVERNANCE.SUPPLY_HEALTH_STREAM'
        )
    ) AS DETAILS
;

-- 4. Persisted CDC should contain balanced update pairs.
SELECT
    'PERSISTED_CDC_HISTORY' AS CHECK_NAME,
    IFF(
        COUNT(*) >= 8
        AND COUNT_IF(STREAM_ACTION = 'DELETE')
            = COUNT_IF(STREAM_ACTION = 'INSERT')
        AND COUNT_IF(STREAM_IS_UPDATE) = COUNT(*),
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'total_rows', COUNT(*),
        'delete_rows', COUNT_IF(STREAM_ACTION = 'DELETE'),
        'insert_rows', COUNT_IF(STREAM_ACTION = 'INSERT'),
        'update_rows', COUNT_IF(STREAM_IS_UPDATE)
    ) AS DETAILS
FROM ONTARA.GOVERNANCE.SUPPLY_HEALTH_CHANGE_LOG
;

-- 5. Controlled path should contain both forward and reverse CDC states.
SELECT
    'CONTROLLED_PATH_ROUNDTRIP' AS CHECK_NAME,
    IFF(
        COUNT_IF(
            AVAILABLE_INVENTORY_UNITS = 5
            AND IMPACT_RISK_SCORE = 90
            AND OPERATIONAL_HEALTH_STATUS = 'CRITICAL'
        ) >= 2
        AND COUNT_IF(
            AVAILABLE_INVENTORY_UNITS = 25
            AND IMPACT_RISK_SCORE = 75
            AND OPERATIONAL_HEALTH_STATUS = 'AT_RISK'
        ) >= 2,
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'path_rows', COUNT(*),
        'critical_state_rows',
            COUNT_IF(
                AVAILABLE_INVENTORY_UNITS = 5
                AND IMPACT_RISK_SCORE = 90
                AND OPERATIONAL_HEALTH_STATUS = 'CRITICAL'
            ),
        'at_risk_state_rows',
            COUNT_IF(
                AVAILABLE_INVENTORY_UNITS = 25
                AND IMPACT_RISK_SCORE = 75
                AND OPERATIONAL_HEALTH_STATUS = 'AT_RISK'
            )
    ) AS DETAILS
FROM ONTARA.GOVERNANCE.SUPPLY_HEALTH_CHANGE_LOG
WHERE SUPPLIER_ID = 'SUP-003'
  AND PART_ID = 'PRT-009'
  AND PLANT_ID = 'PLT-003'
  AND ORDER_ID = 'ORD-008'
;

-- 6. At least one successful manual task execution must exist.
SELECT
    'TASK_EXECUTION_SUCCEEDED' AS CHECK_NAME,
    IFF(
        COUNT_IF(
            STATE = 'SUCCEEDED'
            AND SCHEDULED_FROM = 'EXECUTE TASK'
        ) >= 1,
        'PASS',
        'FAIL'
    ) AS STATUS,
    OBJECT_CONSTRUCT(
        'successful_manual_runs',
            COUNT_IF(
                STATE = 'SUCCEEDED'
                AND SCHEDULED_FROM = 'EXECUTE TASK'
            ),
        'latest_scheduled_time', MAX(SCHEDULED_TIME)
    ) AS DETAILS
FROM TABLE(
    ONTARA.INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'PROCESS_SUPPLY_HEALTH_CHANGES',
        RESULT_LIMIT => 100
    )
)
;
