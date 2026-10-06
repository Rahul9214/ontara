-- ============================================================================
-- Ontara — Governed Action Loop
-- ============================================================================
--
-- Purpose
-- -------
-- Convert governed supply-chain disruption intelligence into controlled,
-- human-approved, persisted operational actions.
--
-- Lifecycle
-- ---------
-- Governed blast-radius signal
--     -> action request
--     -> PENDING_APPROVAL
--     -> APPROVED or REJECTED
--     -> IN_PROGRESS
--     -> RESOLVED
--
-- Design principles
-- -----------------
-- 1. Risk and exposure values are derived from governed semantic objects.
-- 2. Request keys make action creation idempotent.
-- 3. Human approval is mandatory before execution state can progress.
-- 4. Every state transition creates an append-only audit event.
-- 5. Streamlit / Cortex / MCP use procedures instead of arbitrary table DML.
-- ============================================================================


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA GOVERNANCE;


-- ============================================================================
-- 1. CURRENT GOVERNED ACTION STATE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS (

    EXCEPTION_ID VARCHAR NOT NULL,
    REQUEST_KEY VARCHAR NOT NULL,

    EXCEPTION_TYPE VARCHAR NOT NULL,

    SUPPLIER_ID VARCHAR NOT NULL,
    PART_ID VARCHAR NOT NULL,
    PLANT_ID VARCHAR,
    ORDER_ID VARCHAR,
    CUSTOMER_ID VARCHAR,

    TITLE VARCHAR NOT NULL,

    RECOMMENDED_RESPONSE VARCHAR,
    RECOMMENDED_ACTION VARCHAR NOT NULL,

    RISK_SCORE NUMBER(5, 2),
    RISK_BAND VARCHAR,

    OUTSTANDING_UNITS NUMBER(18, 0),
    REVENUE_EXPOSURE_USD NUMBER(18, 2),

    AVAILABLE_INVENTORY_UNITS NUMBER(18, 0),
    SAFETY_STOCK_UNITS NUMBER(18, 0),
    INVENTORY_SHORTFALL_UNITS NUMBER(18, 0),
    DAYS_OF_INVENTORY NUMBER(18, 2),

    ACTIVE_ALTERNATE_SUPPLIER_COUNT NUMBER(18, 0),
    FASTEST_ALTERNATE_LEAD_TIME_DAYS NUMBER(18, 0),

    STATUS VARCHAR NOT NULL,
    APPROVAL_STATUS VARCHAR NOT NULL,

    REQUESTED_BY VARCHAR NOT NULL,
    REQUESTED_AT TIMESTAMP_LTZ NOT NULL,

    APPROVED_BY VARCHAR,
    APPROVED_AT TIMESTAMP_LTZ,

    REJECTED_BY VARCHAR,
    REJECTED_AT TIMESTAMP_LTZ,

    DECISION_NOTE VARCHAR,

    SOURCE_QUESTION VARCHAR,

    SEMANTIC_CONTRACT_VERSION VARCHAR NOT NULL,
    SOURCE_OBJECT VARCHAR NOT NULL,

    CREATED_AT TIMESTAMP_LTZ NOT NULL,
    UPDATED_AT TIMESTAMP_LTZ NOT NULL,

    CONSTRAINT PK_SUPPLY_EXCEPTIONS
        PRIMARY KEY (EXCEPTION_ID),

    CONSTRAINT UQ_SUPPLY_EXCEPTIONS_REQUEST_KEY
        UNIQUE (REQUEST_KEY)
);


COMMENT ON TABLE ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS IS
    'Current governed state for human-reviewed Ontara supply-chain actions';


-- ============================================================================
-- 2. APPEND-ONLY ACTION EVENT TRAIL
-- ============================================================================

CREATE TABLE IF NOT EXISTS ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS (

    EVENT_ID VARCHAR NOT NULL,
    EXCEPTION_ID VARCHAR NOT NULL,

    EVENT_TYPE VARCHAR NOT NULL,

    FROM_STATUS VARCHAR,
    TO_STATUS VARCHAR,

    ACTOR VARCHAR NOT NULL,
    EVENT_NOTE VARCHAR,

    EVENT_PAYLOAD VARIANT,

    EVENT_AT TIMESTAMP_LTZ NOT NULL,

    CONSTRAINT PK_SUPPLY_EXCEPTION_EVENTS
        PRIMARY KEY (EVENT_ID)
);


COMMENT ON TABLE ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS IS
    'Append-only governed audit trail for Ontara supply exception lifecycle events';


-- ============================================================================
-- 3. REQUEST A GOVERNED ACTION
-- ============================================================================
--
-- The caller supplies identifiers and intent only.
--
-- Risk score, customer, plant, commercial exposure, inventory exposure,
-- alternate-source resilience and recommended response are resolved from
-- ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS.
--
-- REQUEST_KEY makes retries idempotent.
-- ============================================================================

CREATE OR REPLACE PROCEDURE
    ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
        P_REQUEST_KEY VARCHAR,
        P_SUPPLIER_ID VARCHAR,
        P_PART_ID VARCHAR,
        P_ORDER_ID VARCHAR,
        P_EXCEPTION_TYPE VARCHAR,
        P_TITLE VARCHAR,
        P_RECOMMENDED_ACTION VARCHAR,
        P_SOURCE_QUESTION VARCHAR,
        P_REQUESTED_BY VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Create an idempotent governed supply exception request from semantic blast-radius evidence'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_EXISTING_COUNT NUMBER DEFAULT 0;
    V_EXISTING_EXCEPTION_ID VARCHAR;

    V_IMPACT_COUNT NUMBER DEFAULT 0;

    V_EXCEPTION_ID VARCHAR;

    V_PLANT_ID VARCHAR;
    V_CUSTOMER_ID VARCHAR;

    V_RISK_SCORE NUMBER(5, 2);
    V_RISK_BAND VARCHAR;

    V_OUTSTANDING_UNITS NUMBER(18, 0);
    V_REVENUE_EXPOSURE_USD NUMBER(18, 2);

    V_AVAILABLE_INVENTORY_UNITS NUMBER(18, 0);
    V_SAFETY_STOCK_UNITS NUMBER(18, 0);
    V_INVENTORY_SHORTFALL_UNITS NUMBER(18, 0);
    V_DAYS_OF_INVENTORY NUMBER(18, 2);

    V_ACTIVE_ALTERNATE_COUNT NUMBER(18, 0);
    V_FASTEST_ALTERNATE_LEAD_TIME_DAYS NUMBER(18, 0);

    V_RECOMMENDED_RESPONSE VARCHAR;

    V_NOW TIMESTAMP_LTZ;
BEGIN

    -- ------------------------------------------------------------------------
    -- Input contract
    -- ------------------------------------------------------------------------

    IF (
        P_REQUEST_KEY IS NULL
        OR TRIM(P_REQUEST_KEY) = ''
        OR P_SUPPLIER_ID IS NULL
        OR P_PART_ID IS NULL
        OR P_ORDER_ID IS NULL
        OR P_EXCEPTION_TYPE IS NULL
        OR TRIM(P_EXCEPTION_TYPE) = ''
        OR P_TITLE IS NULL
        OR TRIM(P_TITLE) = ''
        OR P_RECOMMENDED_ACTION IS NULL
        OR TRIM(P_RECOMMENDED_ACTION) = ''
        OR P_REQUESTED_BY IS NULL
        OR TRIM(P_REQUESTED_BY) = ''
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_REQUEST',
            'message', 'Required governed action request fields are missing'
        );

    END IF;


    -- ------------------------------------------------------------------------
    -- Idempotency
    -- ------------------------------------------------------------------------

    SELECT COUNT(*)
    INTO :V_EXISTING_COUNT
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE REQUEST_KEY = :P_REQUEST_KEY;


    IF (V_EXISTING_COUNT > 0) THEN

        SELECT EXCEPTION_ID
        INTO :V_EXISTING_EXCEPTION_ID
        FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        WHERE REQUEST_KEY = :P_REQUEST_KEY
        QUALIFY ROW_NUMBER() OVER (
            ORDER BY CREATED_AT
        ) = 1;

        RETURN OBJECT_CONSTRUCT(
            'status', 'ALREADY_EXISTS',
            'exception_id', V_EXISTING_EXCEPTION_ID,
            'request_key', P_REQUEST_KEY,
            'message', 'Existing governed action returned for idempotent request'
        );

    END IF;


    -- ------------------------------------------------------------------------
    -- Governed semantic evidence must exist
    -- ------------------------------------------------------------------------

    SELECT COUNT(*)
    INTO :V_IMPACT_COUNT
    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS
    WHERE SUPPLIER_ID = :P_SUPPLIER_ID
      AND PART_ID = :P_PART_ID
      AND ORDER_ID = :P_ORDER_ID;


    IF (V_IMPACT_COUNT <> 1) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'IMPACT_NOT_FOUND',
            'supplier_id', P_SUPPLIER_ID,
            'part_id', P_PART_ID,
            'order_id', P_ORDER_ID,
            'matching_rows', V_IMPACT_COUNT,
            'message', 'Exactly one governed blast-radius record is required'
        );

    END IF;


    -- ------------------------------------------------------------------------
    -- Resolve action evidence from governed semantic objects
    -- ------------------------------------------------------------------------

    SELECT
        detail.PLANT_ID,
        detail.CUSTOMER_ID,
        detail.IMPACT_RISK_SCORE,
        detail.IMPACT_RISK_BAND,
        detail.OUTSTANDING_ORDER_UNITS,
        detail.OUTSTANDING_REVENUE_EXPOSURE_USD,
        detail.AVAILABLE_INVENTORY_UNITS,
        detail.SAFETY_STOCK_UNITS,
        detail.INVENTORY_SHORTFALL_TO_SAFETY_UNITS,
        detail.DAYS_OF_INVENTORY,
        detail.ACTIVE_ALTERNATE_SUPPLIER_COUNT,
        detail.FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        summary.RECOMMENDED_RESPONSE

    INTO
        :V_PLANT_ID,
        :V_CUSTOMER_ID,
        :V_RISK_SCORE,
        :V_RISK_BAND,
        :V_OUTSTANDING_UNITS,
        :V_REVENUE_EXPOSURE_USD,
        :V_AVAILABLE_INVENTORY_UNITS,
        :V_SAFETY_STOCK_UNITS,
        :V_INVENTORY_SHORTFALL_UNITS,
        :V_DAYS_OF_INVENTORY,
        :V_ACTIVE_ALTERNATE_COUNT,
        :V_FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        :V_RECOMMENDED_RESPONSE

    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS detail

    JOIN ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY summary
        ON summary.SUPPLIER_ID = detail.SUPPLIER_ID

    WHERE detail.SUPPLIER_ID = :P_SUPPLIER_ID
      AND detail.PART_ID = :P_PART_ID
      AND detail.ORDER_ID = :P_ORDER_ID;


    V_EXCEPTION_ID := UUID_STRING();
    V_NOW := CURRENT_TIMESTAMP();


    -- ------------------------------------------------------------------------
    -- Persist current state
    -- ------------------------------------------------------------------------

    INSERT INTO ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS (
        EXCEPTION_ID,
        REQUEST_KEY,
        EXCEPTION_TYPE,
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID,
        ORDER_ID,
        CUSTOMER_ID,
        TITLE,
        RECOMMENDED_RESPONSE,
        RECOMMENDED_ACTION,
        RISK_SCORE,
        RISK_BAND,
        OUTSTANDING_UNITS,
        REVENUE_EXPOSURE_USD,
        AVAILABLE_INVENTORY_UNITS,
        SAFETY_STOCK_UNITS,
        INVENTORY_SHORTFALL_UNITS,
        DAYS_OF_INVENTORY,
        ACTIVE_ALTERNATE_SUPPLIER_COUNT,
        FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        STATUS,
        APPROVAL_STATUS,
        REQUESTED_BY,
        REQUESTED_AT,
        SOURCE_QUESTION,
        SEMANTIC_CONTRACT_VERSION,
        SOURCE_OBJECT,
        CREATED_AT,
        UPDATED_AT
    )
    VALUES (
        :V_EXCEPTION_ID,
        :P_REQUEST_KEY,
        UPPER(TRIM(:P_EXCEPTION_TYPE)),
        :P_SUPPLIER_ID,
        :P_PART_ID,
        :V_PLANT_ID,
        :P_ORDER_ID,
        :V_CUSTOMER_ID,
        :P_TITLE,
        :V_RECOMMENDED_RESPONSE,
        :P_RECOMMENDED_ACTION,
        :V_RISK_SCORE,
        :V_RISK_BAND,
        :V_OUTSTANDING_UNITS,
        :V_REVENUE_EXPOSURE_USD,
        :V_AVAILABLE_INVENTORY_UNITS,
        :V_SAFETY_STOCK_UNITS,
        :V_INVENTORY_SHORTFALL_UNITS,
        :V_DAYS_OF_INVENTORY,
        :V_ACTIVE_ALTERNATE_COUNT,
        :V_FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        'PENDING_APPROVAL',
        'PENDING',
        :P_REQUESTED_BY,
        :V_NOW,
        :P_SOURCE_QUESTION,
        '1.0.0',
        'ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS',
        :V_NOW,
        :V_NOW
    );


    -- ------------------------------------------------------------------------
    -- Append audit event
    -- ------------------------------------------------------------------------

    INSERT INTO ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS (
        EVENT_ID,
        EXCEPTION_ID,
        EVENT_TYPE,
        FROM_STATUS,
        TO_STATUS,
        ACTOR,
        EVENT_NOTE,
        EVENT_PAYLOAD,
        EVENT_AT
    )
    SELECT
        UUID_STRING(),
        :V_EXCEPTION_ID,
        'REQUESTED',
        NULL,
        'PENDING_APPROVAL',
        :P_REQUESTED_BY,
        'Governed supply action submitted for human approval',
        OBJECT_CONSTRUCT(
            'request_key', :P_REQUEST_KEY,
            'supplier_id', :P_SUPPLIER_ID,
            'part_id', :P_PART_ID,
            'order_id', :P_ORDER_ID,
            'risk_score', :V_RISK_SCORE,
            'risk_band', :V_RISK_BAND,
            'revenue_exposure_usd', :V_REVENUE_EXPOSURE_USD,
            'recommended_response', :V_RECOMMENDED_RESPONSE,
            'semantic_contract_version', '1.0.0'
        ),
        :V_NOW;


    RETURN OBJECT_CONSTRUCT(
        'status', 'PENDING_APPROVAL',
        'exception_id', V_EXCEPTION_ID,
        'request_key', P_REQUEST_KEY,
        'risk_score', V_RISK_SCORE,
        'risk_band', V_RISK_BAND,
        'revenue_exposure_usd', V_REVENUE_EXPOSURE_USD,
        'recommended_response', V_RECOMMENDED_RESPONSE,
        'message', 'Governed supply action created and awaiting human approval'
    );

END;
$$;


-- ============================================================================
-- 4. HUMAN APPROVAL / REJECTION
-- ============================================================================

CREATE OR REPLACE PROCEDURE
    ONTARA.GOVERNANCE.DECIDE_SUPPLY_EXCEPTION(
        P_EXCEPTION_ID VARCHAR,
        P_DECISION VARCHAR,
        P_ACTOR VARCHAR,
        P_NOTE VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Human approval gate for governed Ontara supply actions'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_COUNT NUMBER DEFAULT 0;

    V_CURRENT_STATUS VARCHAR;
    V_CURRENT_APPROVAL_STATUS VARCHAR;

    V_DECISION VARCHAR;
    V_TARGET_STATUS VARCHAR;
    V_EVENT_TYPE VARCHAR;

    V_NOW TIMESTAMP_LTZ;
BEGIN

    IF (
        P_EXCEPTION_ID IS NULL
        OR P_DECISION IS NULL
        OR P_ACTOR IS NULL
        OR TRIM(P_ACTOR) = ''
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_REQUEST',
            'message', 'Exception ID, decision and actor are required'
        );

    END IF;


    V_DECISION := UPPER(TRIM(P_DECISION));


    IF (
        V_DECISION <> 'APPROVE'
        AND V_DECISION <> 'REJECT'
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_DECISION',
            'decision', V_DECISION,
            'message', 'Decision must be APPROVE or REJECT'
        );

    END IF;


    SELECT COUNT(*)
    INTO :V_COUNT
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE EXCEPTION_ID = :P_EXCEPTION_ID;


    IF (V_COUNT <> 1) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'NOT_FOUND',
            'exception_id', P_EXCEPTION_ID,
            'message', 'Governed supply exception was not found'
        );

    END IF;


    SELECT
        STATUS,
        APPROVAL_STATUS
    INTO
        :V_CURRENT_STATUS,
        :V_CURRENT_APPROVAL_STATUS
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE EXCEPTION_ID = :P_EXCEPTION_ID;


    IF (
        V_CURRENT_STATUS <> 'PENDING_APPROVAL'
        OR V_CURRENT_APPROVAL_STATUS <> 'PENDING'
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_STATE',
            'exception_id', P_EXCEPTION_ID,
            'current_status', V_CURRENT_STATUS,
            'approval_status', V_CURRENT_APPROVAL_STATUS,
            'message', 'Only pending actions can receive an approval decision'
        );

    END IF;


    V_NOW := CURRENT_TIMESTAMP();


    IF (V_DECISION = 'APPROVE') THEN

        V_TARGET_STATUS := 'APPROVED';
        V_EVENT_TYPE := 'APPROVED';


        UPDATE ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        SET
            STATUS = 'APPROVED',
            APPROVAL_STATUS = 'APPROVED',
            APPROVED_BY = :P_ACTOR,
            APPROVED_AT = :V_NOW,
            DECISION_NOTE = :P_NOTE,
            UPDATED_AT = :V_NOW
        WHERE EXCEPTION_ID = :P_EXCEPTION_ID;

    ELSE

        V_TARGET_STATUS := 'REJECTED';
        V_EVENT_TYPE := 'REJECTED';


        UPDATE ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
        SET
            STATUS = 'REJECTED',
            APPROVAL_STATUS = 'REJECTED',
            REJECTED_BY = :P_ACTOR,
            REJECTED_AT = :V_NOW,
            DECISION_NOTE = :P_NOTE,
            UPDATED_AT = :V_NOW
        WHERE EXCEPTION_ID = :P_EXCEPTION_ID;

    END IF;


    INSERT INTO ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS (
        EVENT_ID,
        EXCEPTION_ID,
        EVENT_TYPE,
        FROM_STATUS,
        TO_STATUS,
        ACTOR,
        EVENT_NOTE,
        EVENT_PAYLOAD,
        EVENT_AT
    )
    SELECT
        UUID_STRING(),
        :P_EXCEPTION_ID,
        :V_EVENT_TYPE,
        :V_CURRENT_STATUS,
        :V_TARGET_STATUS,
        :P_ACTOR,
        :P_NOTE,
        OBJECT_CONSTRUCT(
            'decision', :V_DECISION,
            'approval_status',
                IFF(
                    :V_DECISION = 'APPROVE',
                    'APPROVED',
                    'REJECTED'
                )
        ),
        :V_NOW;


    RETURN OBJECT_CONSTRUCT(
        'status', V_TARGET_STATUS,
        'exception_id', P_EXCEPTION_ID,
        'decision', V_DECISION,
        'actor', P_ACTOR,
        'message',
            IFF(
                V_DECISION = 'APPROVE',
                'Governed action approved by human reviewer',
                'Governed action rejected by human reviewer'
            )
    );

END;
$$;


-- ============================================================================
-- 5. CONTROLLED EXECUTION LIFECYCLE
-- ============================================================================
--
-- Only approved actions may move:
--
-- APPROVED -> IN_PROGRESS -> RESOLVED
--
-- This prevents an AI agent or UI client from bypassing the human gate.
-- ============================================================================

CREATE OR REPLACE PROCEDURE
    ONTARA.GOVERNANCE.UPDATE_SUPPLY_EXCEPTION_STATUS(
        P_EXCEPTION_ID VARCHAR,
        P_NEW_STATUS VARCHAR,
        P_ACTOR VARCHAR,
        P_NOTE VARCHAR
    )
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Advance an approved governed supply action through controlled execution states'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_COUNT NUMBER DEFAULT 0;

    V_CURRENT_STATUS VARCHAR;
    V_APPROVAL_STATUS VARCHAR;

    V_NEW_STATUS VARCHAR;

    V_TRANSITION_ALLOWED BOOLEAN DEFAULT FALSE;

    V_NOW TIMESTAMP_LTZ;
BEGIN

    IF (
        P_EXCEPTION_ID IS NULL
        OR P_NEW_STATUS IS NULL
        OR P_ACTOR IS NULL
        OR TRIM(P_ACTOR) = ''
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_REQUEST',
            'message', 'Exception ID, new status and actor are required'
        );

    END IF;


    V_NEW_STATUS := UPPER(TRIM(P_NEW_STATUS));


    IF (
        V_NEW_STATUS <> 'IN_PROGRESS'
        AND V_NEW_STATUS <> 'RESOLVED'
    ) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_TARGET_STATE',
            'requested_status', V_NEW_STATUS,
            'message', 'Execution status must be IN_PROGRESS or RESOLVED'
        );

    END IF;


    SELECT COUNT(*)
    INTO :V_COUNT
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE EXCEPTION_ID = :P_EXCEPTION_ID;


    IF (V_COUNT <> 1) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'NOT_FOUND',
            'exception_id', P_EXCEPTION_ID,
            'message', 'Governed supply exception was not found'
        );

    END IF;


    SELECT
        STATUS,
        APPROVAL_STATUS
    INTO
        :V_CURRENT_STATUS,
        :V_APPROVAL_STATUS
    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    WHERE EXCEPTION_ID = :P_EXCEPTION_ID;


    IF (V_APPROVAL_STATUS <> 'APPROVED') THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'HUMAN_APPROVAL_REQUIRED',
            'exception_id', P_EXCEPTION_ID,
            'approval_status', V_APPROVAL_STATUS,
            'message', 'Action cannot execute until a human approves it'
        );

    END IF;


    V_TRANSITION_ALLOWED :=
        (
            V_CURRENT_STATUS = 'APPROVED'
            AND V_NEW_STATUS = 'IN_PROGRESS'
        )
        OR
        (
            V_CURRENT_STATUS = 'IN_PROGRESS'
            AND V_NEW_STATUS = 'RESOLVED'
        );


    IF (NOT V_TRANSITION_ALLOWED) THEN

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_TRANSITION',
            'exception_id', P_EXCEPTION_ID,
            'from_status', V_CURRENT_STATUS,
            'to_status', V_NEW_STATUS,
            'message', 'Requested governed lifecycle transition is not allowed'
        );

    END IF;


    V_NOW := CURRENT_TIMESTAMP();


    UPDATE ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS
    SET
        STATUS = :V_NEW_STATUS,
        UPDATED_AT = :V_NOW
    WHERE EXCEPTION_ID = :P_EXCEPTION_ID;


    INSERT INTO ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS (
        EVENT_ID,
        EXCEPTION_ID,
        EVENT_TYPE,
        FROM_STATUS,
        TO_STATUS,
        ACTOR,
        EVENT_NOTE,
        EVENT_PAYLOAD,
        EVENT_AT
    )
    SELECT
        UUID_STRING(),
        :P_EXCEPTION_ID,
        'STATUS_CHANGED',
        :V_CURRENT_STATUS,
        :V_NEW_STATUS,
        :P_ACTOR,
        :P_NOTE,
        OBJECT_CONSTRUCT(
            'from_status', :V_CURRENT_STATUS,
            'to_status', :V_NEW_STATUS
        ),
        :V_NOW;


    RETURN OBJECT_CONSTRUCT(
        'status', V_NEW_STATUS,
        'exception_id', P_EXCEPTION_ID,
        'from_status', V_CURRENT_STATUS,
        'to_status', V_NEW_STATUS,
        'actor', P_ACTOR,
        'message', 'Governed action lifecycle state updated'
    );

END;
$$;


-- ============================================================================
-- 6. ACTION CENTER VIEW
-- ============================================================================

CREATE OR REPLACE VIEW ONTARA.GOVERNANCE.ACTION_CENTER AS

WITH latest_event AS (

    SELECT
        EVENT_ID,
        EXCEPTION_ID,
        EVENT_TYPE,
        FROM_STATUS,
        TO_STATUS,
        ACTOR
            AS LAST_EVENT_ACTOR,
        EVENT_NOTE
            AS LAST_EVENT_NOTE,
        EVENT_AT
            AS LAST_EVENT_AT

    FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTION_EVENTS

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY EXCEPTION_ID
        ORDER BY EVENT_AT DESC, EVENT_ID DESC
    ) = 1

)


SELECT
    exception.EXCEPTION_ID,
    exception.REQUEST_KEY,

    exception.EXCEPTION_TYPE,

    exception.STATUS,
    exception.APPROVAL_STATUS,

    exception.SUPPLIER_ID,
    supplier.SUPPLIER_NAME,

    exception.PART_ID,
    part.PART_NAME,

    exception.PLANT_ID,
    plant.PLANT_NAME,

    exception.ORDER_ID,

    exception.CUSTOMER_ID,
    customer.CUSTOMER_NAME,
    customer.PRIORITY_TIER
        AS CUSTOMER_PRIORITY_TIER,

    exception.TITLE,

    exception.RECOMMENDED_RESPONSE,
    exception.RECOMMENDED_ACTION,

    exception.RISK_SCORE,
    exception.RISK_BAND,

    exception.OUTSTANDING_UNITS,
    exception.REVENUE_EXPOSURE_USD,

    exception.AVAILABLE_INVENTORY_UNITS,
    exception.SAFETY_STOCK_UNITS,
    exception.INVENTORY_SHORTFALL_UNITS,
    exception.DAYS_OF_INVENTORY,

    exception.ACTIVE_ALTERNATE_SUPPLIER_COUNT,
    exception.FASTEST_ALTERNATE_LEAD_TIME_DAYS,

    exception.REQUESTED_BY,
    exception.REQUESTED_AT,

    exception.APPROVED_BY,
    exception.APPROVED_AT,

    exception.REJECTED_BY,
    exception.REJECTED_AT,

    exception.DECISION_NOTE,

    exception.SOURCE_QUESTION,
    exception.SEMANTIC_CONTRACT_VERSION,
    exception.SOURCE_OBJECT,

    latest_event.EVENT_TYPE
        AS LAST_EVENT_TYPE,

    latest_event.LAST_EVENT_ACTOR,
    latest_event.LAST_EVENT_NOTE,
    latest_event.LAST_EVENT_AT,

    exception.CREATED_AT,
    exception.UPDATED_AT,

    DATEDIFF(
        'minute',
        exception.REQUESTED_AT,
        CURRENT_TIMESTAMP()
    ) AS ACTION_AGE_MINUTES

FROM ONTARA.GOVERNANCE.SUPPLY_EXCEPTIONS exception

LEFT JOIN ONTARA.CORE.SUPPLIERS supplier
    ON supplier.SUPPLIER_ID
        = exception.SUPPLIER_ID

LEFT JOIN ONTARA.CORE.PARTS part
    ON part.PART_ID
        = exception.PART_ID

LEFT JOIN ONTARA.CORE.PLANTS plant
    ON plant.PLANT_ID
        = exception.PLANT_ID

LEFT JOIN ONTARA.CORE.CUSTOMERS customer
    ON customer.CUSTOMER_ID
        = exception.CUSTOMER_ID

LEFT JOIN latest_event
    ON latest_event.EXCEPTION_ID
        = exception.EXCEPTION_ID;


COMMENT ON VIEW ONTARA.GOVERNANCE.ACTION_CENTER IS
    'Governed current-state Action Center for Ontara human-approved supply-chain remediation workflows';