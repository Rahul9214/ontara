-- Ontara governed MCP tool wrappers.
--
-- Security boundary:
-- - no arbitrary SQL
-- - no approval/rejection tool
-- - no arbitrary workflow status mutation
-- - request tool derives actor from CURRENT_USER()
-- - procedures execute with owner rights so callers need access only
--   to the narrowly scoped procedure contract.

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA APP;


-- ---------------------------------------------------------------------
-- 1. Canonical governed metric
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ONTARA.APP.MCP_GET_GOVERNED_METRIC(
    METRIC_NAME VARCHAR
)
COPY GRANTS
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Returns one approved Ontara canonical metric through its governed semantic contract.'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_METRIC VARCHAR;
    V_VALUE NUMBER(38,8);
BEGIN
    V_METRIC := UPPER(TRIM(METRIC_NAME));

    IF (
        V_METRIC = 'OTD'
        OR V_METRIC = 'ON_TIME_DELIVERY'
        OR V_METRIC = 'ON_TIME_DELIVERY_PCT'
    ) THEN

        SELECT ON_TIME_DELIVERY_PCT
        INTO :V_VALUE
        FROM SEMANTIC_VIEW(
            ONTARA.SEMANTIC.SUPPLY_CHAIN
            METRICS SHIPMENTS.ON_TIME_DELIVERY_PCT
        );

        RETURN OBJECT_CONSTRUCT(
            'status', 'OK',
            'metric_key', 'OTD',
            'contract_id', 'OTD_V1',
            'contract_version', '1.0.0',
            'value', V_VALUE,
            'unit', 'PERCENT',
            'semantic_view', 'ONTARA.SEMANTIC.SUPPLY_CHAIN',
            'definition',
                'Percentage of completed outbound deliveries arriving on or before promised delivery date.'
        );

    ELSEIF (
        V_METRIC = 'FILL_RATE'
        OR V_METRIC = 'FILL_RATE_PCT'
    ) THEN

        SELECT FILL_RATE_PCT
        INTO :V_VALUE
        FROM SEMANTIC_VIEW(
            ONTARA.SEMANTIC.SUPPLY_CHAIN
            METRICS CUSTOMER_ORDERS.FILL_RATE_PCT
        );

        RETURN OBJECT_CONSTRUCT(
            'status', 'OK',
            'metric_key', 'FILL_RATE',
            'contract_id', 'FILL_RATE_V1',
            'contract_version', '1.0.0',
            'value', V_VALUE,
            'unit', 'PERCENT',
            'semantic_view', 'ONTARA.SEMANTIC.SUPPLY_CHAIN',
            'definition',
                'Quantity-weighted fulfilled customer units divided by ordered customer units.'
        );

    ELSEIF (
        V_METRIC = 'DOI'
        OR V_METRIC = 'DAYS_OF_INVENTORY'
    ) THEN

        SELECT DAYS_OF_INVENTORY
        INTO :V_VALUE
        FROM SEMANTIC_VIEW(
            ONTARA.SEMANTIC.SUPPLY_CHAIN
            METRICS INVENTORY_CURRENT.DAYS_OF_INVENTORY
        );

        RETURN OBJECT_CONSTRUCT(
            'status', 'OK',
            'metric_key', 'DOI',
            'contract_id', 'DOI_V1',
            'contract_version', '1.0.0',
            'value', V_VALUE,
            'unit', 'DAYS',
            'semantic_view', 'ONTARA.SEMANTIC.SUPPLY_CHAIN',
            'definition',
                'Latest available physical inventory divided by average daily demand.'
        );

    ELSEIF (
        V_METRIC = 'LANDED_COST'
        OR V_METRIC = 'LANDED_COST_PER_UNIT'
        OR V_METRIC = 'LANDED_COST_PER_UNIT_USD'
    ) THEN

        SELECT LANDED_COST_PER_UNIT_USD
        INTO :V_VALUE
        FROM SEMANTIC_VIEW(
            ONTARA.SEMANTIC.SUPPLY_CHAIN
            METRICS PURCHASE_ORDERS.LANDED_COST_PER_UNIT_USD
        );

        RETURN OBJECT_CONSTRUCT(
            'status', 'OK',
            'metric_key', 'LANDED_COST',
            'contract_id', 'LANDED_COST_V1',
            'contract_version', '1.0.0',
            'value', V_VALUE,
            'unit', 'USD_PER_UNIT',
            'semantic_view', 'ONTARA.SEMANTIC.SUPPLY_CHAIN',
            'definition',
                'Quantity-weighted purchase, freight, duty, and handling cost per ordered unit.'
        );

    ELSE

        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_METRIC',
            'requested_metric', METRIC_NAME,
            'allowed_metrics',
                ARRAY_CONSTRUCT(
                    'OTD',
                    'FILL_RATE',
                    'DOI',
                    'LANDED_COST'
                )
        );

    END IF;
END;
$$;


-- ---------------------------------------------------------------------
-- 2. Supplier ontology blast radius
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ONTARA.APP.MCP_GET_SUPPLIER_BLAST_RADIUS(
    SUPPLIER_ID VARCHAR
)
COPY GRANTS
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Returns governed quantitative downstream impact for one supplier.'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_RESULT VARIANT;
BEGIN

    IF (
        SUPPLIER_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(SUPPLIER_ID)),
            '^SUP-[0-9]{3}$'
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_INPUT',
            'field', 'supplier_id',
            'expected_format', 'SUP-###'
        );
    END IF;

    SELECT
        IFF(
            COUNT(*) = 0,

            OBJECT_CONSTRUCT(
                'status', 'NOT_FOUND',
                'supplier_id', UPPER(TRIM(:SUPPLIER_ID))
            ),

            OBJECT_CONSTRUCT_KEEP_NULL(
                'status', 'OK',
                'supplier_id', MAX(SUPPLIER_ID),
                'supplier_name', MAX(SUPPLIER_NAME),
                'supplier_country_code', MAX(SUPPLIER_COUNTRY_CODE),
                'risk_tier', MAX(RISK_TIER),
                'supplier_status', MAX(SUPPLIER_STATUS),
                'affected_parts', MAX(AFFECTED_PARTS),
                'affected_plants', MAX(AFFECTED_PLANTS),
                'affected_orders', MAX(AFFECTED_ORDERS),
                'affected_customers', MAX(AFFECTED_CUSTOMERS),
                'strategic_customers_affected',
                    MAX(STRATEGIC_CUSTOMERS_AFFECTED),
                'affected_order_units', MAX(AFFECTED_ORDER_UNITS),
                'outstanding_order_units',
                    MAX(OUTSTANDING_ORDER_UNITS),
                'total_order_value_exposed_usd',
                    MAX(TOTAL_ORDER_VALUE_EXPOSED_USD),
                'outstanding_revenue_exposure_usd',
                    MAX(OUTSTANDING_REVENUE_EXPOSURE_USD),
                'inventory_shortfall_units',
                    MAX(INVENTORY_SHORTFALL_UNITS),
                'part_plant_shortfalls',
                    MAX(PART_PLANT_SHORTFALLS),
                'lowest_days_of_inventory',
                    MAX(LOWEST_DAYS_OF_INVENTORY),
                'parts_without_active_alternate',
                    MAX(PARTS_WITHOUT_ACTIVE_ALTERNATE),
                'fastest_available_alternate_lead_time_days',
                    MAX(FASTEST_AVAILABLE_ALTERNATE_LEAD_TIME_DAYS),
                'orders_with_logistics_risk',
                    MAX(ORDERS_WITH_LOGISTICS_RISK),
                'max_impact_risk_score',
                    MAX(MAX_IMPACT_RISK_SCORE),
                'avg_impact_risk_score',
                    MAX(AVG_IMPACT_RISK_SCORE),
                'recommended_response',
                    MAX(RECOMMENDED_RESPONSE),
                'ontology_path',
                    'Supplier -> Part -> Plant -> Shipment -> Order -> Customer',
                'source_object',
                    'ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY'
            )
        )
    INTO :V_RESULT
    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY
    WHERE SUPPLIER_ID = UPPER(TRIM(:SUPPLIER_ID));

    RETURN V_RESULT;
END;
$$;


-- ---------------------------------------------------------------------
-- 3. Exact operational health path
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ONTARA.APP.MCP_GET_OPERATIONAL_HEALTH(
    SUPPLIER_ID VARCHAR,
    PART_ID VARCHAR,
    PLANT_ID VARCHAR,
    ORDER_ID VARCHAR
)
COPY GRANTS
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Returns governed operational health for one supplier-part-plant-order path.'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_RESULT VARIANT;
BEGIN

    IF (
        SUPPLIER_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(SUPPLIER_ID)),
            '^SUP-[0-9]{3}$'
        )
        OR PART_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(PART_ID)),
            '^PRT-[0-9]{3}$'
        )
        OR PLANT_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(PLANT_ID)),
            '^PLT-[0-9]{3}$'
        )
        OR ORDER_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(ORDER_ID)),
            '^ORD-[0-9]{3}$'
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_INPUT',
            'expected',
                'SUP-### / PRT-### / PLT-### / ORD-###'
        );
    END IF;

    SELECT
        IFF(
            COUNT(*) = 0,

            OBJECT_CONSTRUCT(
                'status', 'NOT_FOUND',
                'supplier_id', UPPER(TRIM(:SUPPLIER_ID)),
                'part_id', UPPER(TRIM(:PART_ID)),
                'plant_id', UPPER(TRIM(:PLANT_ID)),
                'order_id', UPPER(TRIM(:ORDER_ID))
            ),

            OBJECT_CONSTRUCT_KEEP_NULL(
                'status', 'OK',
                'health_key', MAX(HEALTH_KEY),
                'supplier_id', MAX(SUPPLIER_ID),
                'supplier_name', MAX(SUPPLIER_NAME),
                'supplier_risk_tier', MAX(SUPPLIER_RISK_TIER),
                'supplier_status', MAX(SUPPLIER_STATUS),
                'part_id', MAX(PART_ID),
                'part_name', MAX(PART_NAME),
                'plant_id', MAX(PLANT_ID),
                'plant_name', MAX(PLANT_NAME),
                'order_id', MAX(ORDER_ID),
                'customer_id', MAX(CUSTOMER_ID),
                'customer_name', MAX(CUSTOMER_NAME),
                'customer_priority_tier',
                    MAX(CUSTOMER_PRIORITY_TIER),
                'ordered_units', MAX(ORDERED_UNITS),
                'fulfilled_units', MAX(FULFILLED_UNITS),
                'outstanding_order_units',
                    MAX(OUTSTANDING_ORDER_UNITS),
                'outstanding_revenue_exposure_usd',
                    MAX(OUTSTANDING_REVENUE_EXPOSURE_USD),
                'available_inventory_units',
                    MAX(AVAILABLE_INVENTORY_UNITS),
                'safety_stock_units',
                    MAX(SAFETY_STOCK_UNITS),
                'inventory_shortfall_to_safety_units',
                    MAX(INVENTORY_SHORTFALL_TO_SAFETY_UNITS),
                'days_of_inventory',
                    MAX(DAYS_OF_INVENTORY),
                'late_or_delayed_shipment_count',
                    MAX(LATE_OR_DELAYED_SHIPMENT_COUNT),
                'active_alternate_supplier_count',
                    MAX(ACTIVE_ALTERNATE_SUPPLIER_COUNT),
                'fastest_alternate_lead_time_days',
                    MAX(FASTEST_ALTERNATE_LEAD_TIME_DAYS),
                'impact_risk_score',
                    MAX(IMPACT_RISK_SCORE),
                'impact_risk_band',
                    MAX(IMPACT_RISK_BAND),
                'operational_health_status',
                    MAX(OPERATIONAL_HEALTH_STATUS),
                'recommended_response',
                    MAX(RECOMMENDED_RESPONSE),
                'source_object',
                    'ONTARA.SEMANTIC.OPERATIONAL_SUPPLY_HEALTH'
            )
        )
    INTO :V_RESULT
    FROM ONTARA.SEMANTIC.OPERATIONAL_SUPPLY_HEALTH
    WHERE SUPPLIER_ID = UPPER(TRIM(:SUPPLIER_ID))
      AND PART_ID = UPPER(TRIM(:PART_ID))
      AND PLANT_ID = UPPER(TRIM(:PLANT_ID))
      AND ORDER_ID = UPPER(TRIM(:ORDER_ID));

    RETURN V_RESULT;
END;
$$;


-- ---------------------------------------------------------------------
-- 4. Read governed exception state
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ONTARA.APP.MCP_GET_SUPPLY_EXCEPTION(
    EXCEPTION_ID VARCHAR
)
COPY GRANTS
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Reads one governed supply exception without permitting workflow mutation.'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_RESULT VARIANT;
BEGIN

    IF (
        EXCEPTION_ID IS NULL
        OR LENGTH(TRIM(EXCEPTION_ID)) = 0
        OR LENGTH(EXCEPTION_ID) > 100
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_INPUT',
            'field', 'exception_id'
        );
    END IF;

    SELECT
        IFF(
            COUNT(*) = 0,

            OBJECT_CONSTRUCT(
                'status', 'NOT_FOUND',
                'exception_id', :EXCEPTION_ID
            ),

            OBJECT_CONSTRUCT_KEEP_NULL(
                'status', 'OK',
                'exception_id', MAX(EXCEPTION_ID),
                'request_key', MAX(REQUEST_KEY),
                'exception_type', MAX(EXCEPTION_TYPE),
                'workflow_status', MAX(STATUS),
                'approval_status', MAX(APPROVAL_STATUS),
                'supplier_id', MAX(SUPPLIER_ID),
                'supplier_name', MAX(SUPPLIER_NAME),
                'part_id', MAX(PART_ID),
                'part_name', MAX(PART_NAME),
                'plant_id', MAX(PLANT_ID),
                'plant_name', MAX(PLANT_NAME),
                'order_id', MAX(ORDER_ID),
                'customer_id', MAX(CUSTOMER_ID),
                'customer_name', MAX(CUSTOMER_NAME),
                'title', MAX(TITLE),
                'recommended_response',
                    MAX(RECOMMENDED_RESPONSE),
                'recommended_action',
                    MAX(RECOMMENDED_ACTION),
                'risk_score', MAX(RISK_SCORE),
                'risk_band', MAX(RISK_BAND),
                'revenue_exposure_usd',
                    MAX(REVENUE_EXPOSURE_USD),
                'requested_by', MAX(REQUESTED_BY),
                'requested_at', MAX(REQUESTED_AT),
                'approved_by', MAX(APPROVED_BY),
                'approved_at', MAX(APPROVED_AT),
                'rejected_by', MAX(REJECTED_BY),
                'rejected_at', MAX(REJECTED_AT),
                'decision_note', MAX(DECISION_NOTE),
                'source_question', MAX(SOURCE_QUESTION),
                'semantic_contract_version',
                    MAX(SEMANTIC_CONTRACT_VERSION),
                'last_event_type', MAX(LAST_EVENT_TYPE),
                'last_event_actor', MAX(LAST_EVENT_ACTOR),
                'last_event_at', MAX(LAST_EVENT_AT),
                'approval_required', TRUE,
                'mcp_can_approve', FALSE,
                'mcp_can_change_status', FALSE,
                'source_object',
                    'ONTARA.GOVERNANCE.ACTION_CENTER'
            )
        )
    INTO :V_RESULT
    FROM ONTARA.GOVERNANCE.ACTION_CENTER
    WHERE EXCEPTION_ID = :EXCEPTION_ID;

    RETURN V_RESULT;
END;
$$;


-- ---------------------------------------------------------------------
-- 5. Request-only governed action tool
-- ---------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ONTARA.APP.MCP_REQUEST_SUPPLY_EXCEPTION(
    SUPPLIER_ID VARCHAR,
    PART_ID VARCHAR,
    ORDER_ID VARCHAR,
    SOURCE_QUESTION VARCHAR
)
COPY GRANTS
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Creates an idempotent governed mitigation request; cannot approve, reject, or execute it.'
EXECUTE AS OWNER
AS
$$
DECLARE
    V_MATCH_COUNT NUMBER;
    V_RECOMMENDED_ACTION VARCHAR;
    V_REQUEST_KEY VARCHAR;
    V_TITLE VARCHAR;
    V_ACTOR VARCHAR;
    V_BASE_RESULT VARIANT;
BEGIN

    IF (
        SUPPLIER_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(SUPPLIER_ID)),
            '^SUP-[0-9]{3}$'
        )
        OR PART_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(PART_ID)),
            '^PRT-[0-9]{3}$'
        )
        OR ORDER_ID IS NULL
        OR NOT REGEXP_LIKE(
            UPPER(TRIM(ORDER_ID)),
            '^ORD-[0-9]{3}$'
        )
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_INPUT',
            'expected',
                'SUP-### / PRT-### / ORD-###'
        );
    END IF;

    IF (
        SOURCE_QUESTION IS NULL
        OR LENGTH(TRIM(SOURCE_QUESTION)) = 0
        OR LENGTH(SOURCE_QUESTION) > 1000
    ) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'INVALID_INPUT',
            'field', 'source_question',
            'max_length', 1000
        );
    END IF;

    SELECT
        COUNT(*),
        MAX(RECOMMENDED_RESPONSE)
    INTO
        :V_MATCH_COUNT,
        :V_RECOMMENDED_ACTION
    FROM ONTARA.SEMANTIC.OPERATIONAL_SUPPLY_HEALTH
    WHERE SUPPLIER_ID = UPPER(TRIM(:SUPPLIER_ID))
      AND PART_ID = UPPER(TRIM(:PART_ID))
      AND ORDER_ID = UPPER(TRIM(:ORDER_ID));

    IF (V_MATCH_COUNT = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'NOT_FOUND',
            'supplier_id', UPPER(TRIM(SUPPLIER_ID)),
            'part_id', UPPER(TRIM(PART_ID)),
            'order_id', UPPER(TRIM(ORDER_ID))
        );
    END IF;

    V_REQUEST_KEY := CONCAT(
        'MCP-',
        UPPER(TRIM(SUPPLIER_ID)),
        '-',
        UPPER(TRIM(PART_ID)),
        '-',
        UPPER(TRIM(ORDER_ID)),
        '-',
        SUBSTR(
            SHA2(UPPER(TRIM(SOURCE_QUESTION)), 256),
            1,
            12
        )
    );

    V_TITLE := CONCAT(
        'Governed mitigation request: ',
        UPPER(TRIM(SUPPLIER_ID)),
        ' / ',
        UPPER(TRIM(PART_ID)),
        ' / ',
        UPPER(TRIM(ORDER_ID))
    );

    V_ACTOR := CURRENT_USER();

    CALL ONTARA.GOVERNANCE.REQUEST_SUPPLY_EXCEPTION(
        :V_REQUEST_KEY,
        :SUPPLIER_ID,
        :PART_ID,
        :ORDER_ID,
        'SUPPLIER_DISRUPTION',
        :V_TITLE,
        :V_RECOMMENDED_ACTION,
        :SOURCE_QUESTION,
        :V_ACTOR
    )
    INTO :V_BASE_RESULT;

    RETURN OBJECT_CONSTRUCT_KEEP_NULL(
        'status', 'REQUEST_ROUTED',
        'request_key', V_REQUEST_KEY,
        'requested_by', V_ACTOR,
        'recommended_action', V_RECOMMENDED_ACTION,
        'approval_required', TRUE,
        'mcp_can_approve', FALSE,
        'mcp_can_reject', FALSE,
        'mcp_can_change_status', FALSE,
        'governed_result', V_BASE_RESULT
    );

END;
$$;