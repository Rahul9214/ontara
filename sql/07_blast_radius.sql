-- ============================================================================
-- Ontara — Governed Ontology Blast Radius
-- ============================================================================
--
-- Purpose
-- -------
-- Quantify downstream supply-chain impact from a supplier/part disruption.
--
-- Governed lineage:
--
-- Supplier
--   -> Supplier-Part sourcing
--   -> Part
--   -> Plant
--   -> Shipment
--   -> Customer Order
--   -> Customer
--
-- Outputs
-- -------
-- 1. SUPPLY_IMPACT_DETAILS
--      Order-level commercial, inventory, logistics and sourcing exposure.
--
-- 2. SUPPLY_ALTERNATE_SOURCES
--      Ranked alternate suppliers for every origin supplier/part pair.
--
-- 3. SUPPLY_IMPACT_SUMMARY
--      Executive-level blast-radius summary and deterministic response.
--
-- All calculations use governed ONTARA.CORE data.
-- ============================================================================


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA SEMANTIC;


-- ============================================================================
-- 1. ORDER-LEVEL GOVERNED IMPACT DETAIL
-- ============================================================================

CREATE OR REPLACE VIEW ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS AS

WITH latest_inventory AS (

    SELECT
        SNAPSHOT_DATE,
        PLANT_ID,
        PART_ID,
        ON_HAND_UNITS,
        ALLOCATED_UNITS,
        IN_TRANSIT_UNITS,
        SAFETY_STOCK_UNITS,
        AVG_DAILY_DEMAND_UNITS

    FROM ONTARA.CORE.INVENTORY_SNAPSHOTS

    QUALIFY
        SNAPSHOT_DATE = MAX(SNAPSHOT_DATE) OVER ()

),


shipment_rollup AS (

    SELECT
        CUSTOMER_ORDER_ID,

        COUNT(*) AS OUTBOUND_SHIPMENT_COUNT,

        SUM(SHIPPED_UNITS)
            AS OUTBOUND_SHIPPED_UNITS,

        COUNT_IF(
            STATUS = 'DELAYED'
            OR (
                ACTUAL_DELIVERY_DATE IS NOT NULL
                AND ACTUAL_DELIVERY_DATE > PROMISED_DELIVERY_DATE
            )
        ) AS LATE_OR_DELAYED_SHIPMENT_COUNT,

        MIN(PROMISED_DELIVERY_DATE)
            AS EARLIEST_PROMISED_DELIVERY_DATE,

        MAX(ACTUAL_DELIVERY_DATE)
            AS LATEST_ACTUAL_DELIVERY_DATE,

        LISTAGG(
            DISTINCT STATUS,
            ', '
        ) WITHIN GROUP (
            ORDER BY STATUS
        ) AS SHIPMENT_STATUSES

    FROM ONTARA.CORE.SHIPMENTS

    WHERE SHIPMENT_TYPE = 'OUTBOUND'

    GROUP BY CUSTOMER_ORDER_ID

),


purchase_order_rollup AS (

    SELECT
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID,

        COUNT(*)
            AS SUPPLIER_PLANT_PO_COUNT,

        COUNT_IF(
            STATUS IN ('OPEN', 'PARTIAL')
        ) AS OPEN_OR_PARTIAL_PO_COUNT,

        SUM(
            GREATEST(
                ORDERED_UNITS - RECEIVED_UNITS,
                0
            )
        ) AS PROCUREMENT_OUTSTANDING_UNITS,

        SUM(
            ORDERED_UNITS * UNIT_PURCHASE_COST_USD
            + FREIGHT_COST_USD
            + DUTY_COST_USD
            + HANDLING_COST_USD
        ) AS PROCUREMENT_COMMITTED_VALUE_USD

    FROM ONTARA.CORE.PURCHASE_ORDERS

    GROUP BY
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID

),


alternate_supplier_rollup AS (

    SELECT
        origin.SUPPLIER_ID
            AS ORIGIN_SUPPLIER_ID,

        origin.PART_ID,

        COUNT_IF(
            alternate_supplier.STATUS = 'ACTIVE'
        ) AS ACTIVE_ALTERNATE_SUPPLIER_COUNT,

        MIN(
            IFF(
                alternate_supplier.STATUS = 'ACTIVE',
                alternate.LEAD_TIME_DAYS,
                NULL
            )
        ) AS FASTEST_ALTERNATE_LEAD_TIME_DAYS,

        MIN(
            IFF(
                alternate_supplier.STATUS = 'ACTIVE',
                alternate.CONTRACTED_UNIT_COST_USD,
                NULL
            )
        ) AS LOWEST_ALTERNATE_UNIT_COST_USD

    FROM ONTARA.CORE.SUPPLIER_PARTS origin

    LEFT JOIN ONTARA.CORE.SUPPLIER_PARTS alternate
        ON alternate.PART_ID = origin.PART_ID
        AND alternate.SUPPLIER_ID <> origin.SUPPLIER_ID

    LEFT JOIN ONTARA.CORE.SUPPLIERS alternate_supplier
        ON alternate_supplier.SUPPLIER_ID
            = alternate.SUPPLIER_ID

    GROUP BY
        origin.SUPPLIER_ID,
        origin.PART_ID

),


impact_base AS (

    SELECT

        -- --------------------------------------------------------------------
        -- Disruption origin
        -- --------------------------------------------------------------------

        supplier.SUPPLIER_ID,
        supplier.SUPPLIER_NAME,
        supplier.COUNTRY_CODE
            AS SUPPLIER_COUNTRY_CODE,
        supplier.RISK_TIER,
        supplier.STATUS
            AS SUPPLIER_STATUS,

        supplier_part.PART_ID,
        part.PART_NAME,
        part.CATEGORY
            AS PART_CATEGORY,

        supplier_part.PRIMARY_SUPPLIER_FLAG,
        supplier_part.LEAD_TIME_DAYS
            AS CONTRACTED_LEAD_TIME_DAYS,
        supplier_part.CONTRACTED_UNIT_COST_USD,
        supplier_part.MINIMUM_ORDER_QUANTITY,

        -- --------------------------------------------------------------------
        -- Downstream plant
        -- --------------------------------------------------------------------

        customer_order.PLANT_ID,
        plant.PLANT_NAME,
        plant.REGION
            AS PLANT_REGION,

        -- --------------------------------------------------------------------
        -- Customer/order exposure
        -- --------------------------------------------------------------------

        customer_order.ORDER_ID,
        customer_order.ORDER_DATE,
        customer_order.PROMISED_SHIP_DATE,
        customer_order.STATUS
            AS ORDER_STATUS,

        customer_order.CUSTOMER_ID,
        customer.CUSTOMER_NAME,
        customer.SEGMENT
            AS CUSTOMER_SEGMENT,
        customer.PRIORITY_TIER
            AS CUSTOMER_PRIORITY_TIER,

        customer_order.ORDERED_UNITS,
        customer_order.FULFILLED_UNITS,

        GREATEST(
            customer_order.ORDERED_UNITS
                - customer_order.FULFILLED_UNITS,
            0
        ) AS OUTSTANDING_ORDER_UNITS,

        customer_order.UNIT_SALE_PRICE_USD,

        ROUND(
            customer_order.ORDERED_UNITS
                * customer_order.UNIT_SALE_PRICE_USD,
            2
        ) AS TOTAL_ORDER_VALUE_USD,

        ROUND(
            GREATEST(
                customer_order.ORDERED_UNITS
                    - customer_order.FULFILLED_UNITS,
                0
            )
            * customer_order.UNIT_SALE_PRICE_USD,
            2
        ) AS OUTSTANDING_REVENUE_EXPOSURE_USD,

        -- --------------------------------------------------------------------
        -- Inventory exposure
        -- --------------------------------------------------------------------

        inventory.SNAPSHOT_DATE
            AS INVENTORY_SNAPSHOT_DATE,

        COALESCE(
            inventory.ON_HAND_UNITS,
            0
        ) AS ON_HAND_UNITS,

        COALESCE(
            inventory.ALLOCATED_UNITS,
            0
        ) AS ALLOCATED_UNITS,

        COALESCE(
            inventory.IN_TRANSIT_UNITS,
            0
        ) AS IN_TRANSIT_UNITS,

        COALESCE(
            inventory.SAFETY_STOCK_UNITS,
            0
        ) AS SAFETY_STOCK_UNITS,

        COALESCE(
            inventory.AVG_DAILY_DEMAND_UNITS,
            0
        ) AS AVG_DAILY_DEMAND_UNITS,

        GREATEST(
            COALESCE(inventory.ON_HAND_UNITS, 0)
                - COALESCE(inventory.ALLOCATED_UNITS, 0),
            0
        ) AS AVAILABLE_INVENTORY_UNITS,

        GREATEST(
            COALESCE(inventory.SAFETY_STOCK_UNITS, 0)
                - GREATEST(
                    COALESCE(inventory.ON_HAND_UNITS, 0)
                        - COALESCE(
                            inventory.ALLOCATED_UNITS,
                            0
                        ),
                    0
                ),
            0
        ) AS INVENTORY_SHORTFALL_TO_SAFETY_UNITS,

        ROUND(
            GREATEST(
                COALESCE(inventory.ON_HAND_UNITS, 0)
                    - COALESCE(
                        inventory.ALLOCATED_UNITS,
                        0
                    ),
                0
            )
            / NULLIF(
                COALESCE(
                    inventory.AVG_DAILY_DEMAND_UNITS,
                    0
                ),
                0
            ),
            2
        ) AS DAYS_OF_INVENTORY,

        -- --------------------------------------------------------------------
        -- Logistics exposure
        -- --------------------------------------------------------------------

        COALESCE(
            shipment.OUTBOUND_SHIPMENT_COUNT,
            0
        ) AS OUTBOUND_SHIPMENT_COUNT,

        COALESCE(
            shipment.OUTBOUND_SHIPPED_UNITS,
            0
        ) AS OUTBOUND_SHIPPED_UNITS,

        COALESCE(
            shipment.LATE_OR_DELAYED_SHIPMENT_COUNT,
            0
        ) AS LATE_OR_DELAYED_SHIPMENT_COUNT,

        shipment.EARLIEST_PROMISED_DELIVERY_DATE,
        shipment.LATEST_ACTUAL_DELIVERY_DATE,
        shipment.SHIPMENT_STATUSES,

        -- --------------------------------------------------------------------
        -- Procurement relationship
        -- --------------------------------------------------------------------

        COALESCE(
            purchase_order.SUPPLIER_PLANT_PO_COUNT,
            0
        ) AS SUPPLIER_PLANT_PO_COUNT,

        COALESCE(
            purchase_order.OPEN_OR_PARTIAL_PO_COUNT,
            0
        ) AS OPEN_OR_PARTIAL_PO_COUNT,

        COALESCE(
            purchase_order.PROCUREMENT_OUTSTANDING_UNITS,
            0
        ) AS PROCUREMENT_OUTSTANDING_UNITS,

        ROUND(
            COALESCE(
                purchase_order.PROCUREMENT_COMMITTED_VALUE_USD,
                0
            ),
            2
        ) AS PROCUREMENT_COMMITTED_VALUE_USD,

        -- --------------------------------------------------------------------
        -- Alternate-source resilience
        -- --------------------------------------------------------------------

        COALESCE(
            alternate.ACTIVE_ALTERNATE_SUPPLIER_COUNT,
            0
        ) AS ACTIVE_ALTERNATE_SUPPLIER_COUNT,

        alternate.FASTEST_ALTERNATE_LEAD_TIME_DAYS,
        alternate.LOWEST_ALTERNATE_UNIT_COST_USD

    FROM ONTARA.CORE.SUPPLIER_PARTS supplier_part

    JOIN ONTARA.CORE.SUPPLIERS supplier
        ON supplier.SUPPLIER_ID
            = supplier_part.SUPPLIER_ID

    JOIN ONTARA.CORE.PARTS part
        ON part.PART_ID
            = supplier_part.PART_ID

    JOIN ONTARA.CORE.CUSTOMER_ORDERS customer_order
        ON customer_order.PART_ID
            = supplier_part.PART_ID

    JOIN ONTARA.CORE.CUSTOMERS customer
        ON customer.CUSTOMER_ID
            = customer_order.CUSTOMER_ID

    JOIN ONTARA.CORE.PLANTS plant
        ON plant.PLANT_ID
            = customer_order.PLANT_ID

    LEFT JOIN latest_inventory inventory
        ON inventory.PART_ID
            = customer_order.PART_ID
        AND inventory.PLANT_ID
            = customer_order.PLANT_ID

    LEFT JOIN shipment_rollup shipment
        ON shipment.CUSTOMER_ORDER_ID
            = customer_order.ORDER_ID

    LEFT JOIN purchase_order_rollup purchase_order
        ON purchase_order.SUPPLIER_ID
            = supplier_part.SUPPLIER_ID
        AND purchase_order.PART_ID
            = supplier_part.PART_ID
        AND purchase_order.PLANT_ID
            = customer_order.PLANT_ID

    LEFT JOIN alternate_supplier_rollup alternate
        ON alternate.ORIGIN_SUPPLIER_ID
            = supplier_part.SUPPLIER_ID
        AND alternate.PART_ID
            = supplier_part.PART_ID

    -- A supplier/part is considered relevant to a plant when the supplier is
    -- the governed primary source for that part OR procurement history proves
    -- that the supplier has supplied that plant/part combination.
    WHERE
        supplier_part.PRIMARY_SUPPLIER_FLAG
        OR COALESCE(
            purchase_order.SUPPLIER_PLANT_PO_COUNT,
            0
        ) > 0

),


scored_impact AS (

    SELECT
        impact_base.*,

        LEAST(
            100,

            -- Supplier operating disruption
            IFF(
                SUPPLIER_STATUS = 'DISRUPTED',
                25,
                0
            )

            +

            -- Governed supplier risk tier
            CASE RISK_TIER
                WHEN 'HIGH' THEN 20
                WHEN 'MEDIUM' THEN 10
                WHEN 'LOW' THEN 5
                ELSE 5
            END

            +

            -- Customer importance
            CASE CUSTOMER_PRIORITY_TIER
                WHEN 'STRATEGIC' THEN 15
                WHEN 'PRIORITY' THEN 10
                ELSE 5
            END

            +

            -- Existing unfulfilled demand
            IFF(
                OUTSTANDING_ORDER_UNITS > 0,
                15,
                0
            )

            +

            -- Inventory below safety threshold
            IFF(
                INVENTORY_SHORTFALL_TO_SAFETY_UNITS > 0,
                15,
                0
            )

            +

            -- Alternate-source resilience
            CASE
                WHEN ACTIVE_ALTERNATE_SUPPLIER_COUNT = 0
                    THEN 10

                WHEN FASTEST_ALTERNATE_LEAD_TIME_DAYS
                    > CONTRACTED_LEAD_TIME_DAYS
                    THEN 5

                ELSE 0
            END

            +

            -- Current logistics degradation
            IFF(
                LATE_OR_DELAYED_SHIPMENT_COUNT > 0,
                10,
                0
            )

        ) AS IMPACT_RISK_SCORE

    FROM impact_base

)


SELECT
    scored_impact.*,

    CASE
        WHEN IMPACT_RISK_SCORE >= 75
            THEN 'CRITICAL'

        WHEN IMPACT_RISK_SCORE >= 55
            THEN 'HIGH'

        WHEN IMPACT_RISK_SCORE >= 30
            THEN 'MEDIUM'

        ELSE 'LOW'
    END AS IMPACT_RISK_BAND

FROM scored_impact;


COMMENT ON VIEW ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS IS
    'Governed order-level supply disruption blast-radius analysis with commercial, inventory, logistics and sourcing exposure';


-- ============================================================================
-- 2. RANKED ALTERNATE SOURCING OPTIONS
-- ============================================================================

CREATE OR REPLACE VIEW ONTARA.SEMANTIC.SUPPLY_ALTERNATE_SOURCES AS

SELECT
    origin.SUPPLIER_ID
        AS ORIGIN_SUPPLIER_ID,

    origin_supplier.SUPPLIER_NAME
        AS ORIGIN_SUPPLIER_NAME,

    origin.PART_ID,

    part.PART_NAME,

    alternate.SUPPLIER_ID
        AS ALTERNATE_SUPPLIER_ID,

    alternate_supplier.SUPPLIER_NAME
        AS ALTERNATE_SUPPLIER_NAME,

    alternate_supplier.STATUS
        AS ALTERNATE_SUPPLIER_STATUS,

    alternate_supplier.RISK_TIER
        AS ALTERNATE_SUPPLIER_RISK_TIER,

    alternate.LEAD_TIME_DAYS
        AS ALTERNATE_LEAD_TIME_DAYS,

    alternate.CONTRACTED_UNIT_COST_USD
        AS ALTERNATE_UNIT_COST_USD,

    alternate.MINIMUM_ORDER_QUANTITY
        AS ALTERNATE_MINIMUM_ORDER_QUANTITY,

    alternate.PRIMARY_SUPPLIER_FLAG
        AS ALTERNATE_PRIMARY_SUPPLIER_FLAG,

    alternate.LEAD_TIME_DAYS
        - origin.LEAD_TIME_DAYS
        AS LEAD_TIME_DELTA_DAYS,

    ROUND(
        alternate.CONTRACTED_UNIT_COST_USD
            - origin.CONTRACTED_UNIT_COST_USD,
        2
    ) AS UNIT_COST_DELTA_USD,

    ROW_NUMBER() OVER (
        PARTITION BY
            origin.SUPPLIER_ID,
            origin.PART_ID

        ORDER BY
            IFF(
                alternate_supplier.STATUS = 'ACTIVE',
                0,
                1
            ),
            alternate.LEAD_TIME_DAYS,
            alternate.CONTRACTED_UNIT_COST_USD,
            alternate.SUPPLIER_ID
    ) AS ALTERNATE_RANK

FROM ONTARA.CORE.SUPPLIER_PARTS origin

JOIN ONTARA.CORE.SUPPLIERS origin_supplier
    ON origin_supplier.SUPPLIER_ID
        = origin.SUPPLIER_ID

JOIN ONTARA.CORE.PARTS part
    ON part.PART_ID
        = origin.PART_ID

JOIN ONTARA.CORE.SUPPLIER_PARTS alternate
    ON alternate.PART_ID
        = origin.PART_ID
    AND alternate.SUPPLIER_ID
        <> origin.SUPPLIER_ID

JOIN ONTARA.CORE.SUPPLIERS alternate_supplier
    ON alternate_supplier.SUPPLIER_ID
        = alternate.SUPPLIER_ID;


COMMENT ON VIEW ONTARA.SEMANTIC.SUPPLY_ALTERNATE_SOURCES IS
    'Ranked governed alternate suppliers for disrupted supplier-part combinations';


-- ============================================================================
-- 3. EXECUTIVE BLAST-RADIUS SUMMARY
-- ============================================================================

CREATE OR REPLACE VIEW ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY AS

WITH order_exposure AS (

    SELECT
        SUPPLIER_ID,
        SUPPLIER_NAME,
        SUPPLIER_COUNTRY_CODE,
        RISK_TIER,
        SUPPLIER_STATUS,

        COUNT(DISTINCT PART_ID)
            AS AFFECTED_PARTS,

        COUNT(DISTINCT PLANT_ID)
            AS AFFECTED_PLANTS,

        COUNT(DISTINCT ORDER_ID)
            AS AFFECTED_ORDERS,

        COUNT(DISTINCT CUSTOMER_ID)
            AS AFFECTED_CUSTOMERS,

        COUNT(
            DISTINCT IFF(
                CUSTOMER_PRIORITY_TIER = 'STRATEGIC',
                CUSTOMER_ID,
                NULL
            )
        ) AS STRATEGIC_CUSTOMERS_AFFECTED,

        SUM(ORDERED_UNITS)
            AS AFFECTED_ORDER_UNITS,

        SUM(OUTSTANDING_ORDER_UNITS)
            AS OUTSTANDING_ORDER_UNITS,

        ROUND(
            SUM(TOTAL_ORDER_VALUE_USD),
            2
        ) AS TOTAL_ORDER_VALUE_EXPOSED_USD,

        ROUND(
            SUM(OUTSTANDING_REVENUE_EXPOSURE_USD),
            2
        ) AS OUTSTANDING_REVENUE_EXPOSURE_USD,

        COUNT(
            DISTINCT IFF(
                LATE_OR_DELAYED_SHIPMENT_COUNT > 0,
                ORDER_ID,
                NULL
            )
        ) AS ORDERS_WITH_LOGISTICS_RISK,

        MAX(IMPACT_RISK_SCORE)
            AS MAX_IMPACT_RISK_SCORE,

        ROUND(
            AVG(IMPACT_RISK_SCORE),
            2
        ) AS AVG_IMPACT_RISK_SCORE

    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS

    GROUP BY
        SUPPLIER_ID,
        SUPPLIER_NAME,
        SUPPLIER_COUNTRY_CODE,
        RISK_TIER,
        SUPPLIER_STATUS

),


inventory_grain AS (

    SELECT DISTINCT
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID,
        AVAILABLE_INVENTORY_UNITS,
        SAFETY_STOCK_UNITS,
        INVENTORY_SHORTFALL_TO_SAFETY_UNITS,
        DAYS_OF_INVENTORY

    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS

),


inventory_exposure AS (

    SELECT
        SUPPLIER_ID,

        SUM(
            INVENTORY_SHORTFALL_TO_SAFETY_UNITS
        ) AS INVENTORY_SHORTFALL_UNITS,

        COUNT_IF(
            INVENTORY_SHORTFALL_TO_SAFETY_UNITS > 0
        ) AS PART_PLANT_SHORTFALLS,

        ROUND(
            MIN(DAYS_OF_INVENTORY),
            2
        ) AS LOWEST_DAYS_OF_INVENTORY

    FROM inventory_grain

    GROUP BY SUPPLIER_ID

),


alternate_grain AS (

    SELECT DISTINCT
        SUPPLIER_ID,
        PART_ID,
        ACTIVE_ALTERNATE_SUPPLIER_COUNT,
        FASTEST_ALTERNATE_LEAD_TIME_DAYS

    FROM ONTARA.SEMANTIC.SUPPLY_IMPACT_DETAILS

),


alternate_exposure AS (

    SELECT
        SUPPLIER_ID,

        COUNT_IF(
            ACTIVE_ALTERNATE_SUPPLIER_COUNT = 0
        ) AS PARTS_WITHOUT_ACTIVE_ALTERNATE,

        MIN(
            FASTEST_ALTERNATE_LEAD_TIME_DAYS
        ) AS FASTEST_AVAILABLE_ALTERNATE_LEAD_TIME_DAYS

    FROM alternate_grain

    GROUP BY SUPPLIER_ID

)


SELECT
    orders.SUPPLIER_ID,
    orders.SUPPLIER_NAME,
    orders.SUPPLIER_COUNTRY_CODE,
    orders.RISK_TIER,
    orders.SUPPLIER_STATUS,

    orders.AFFECTED_PARTS,
    orders.AFFECTED_PLANTS,
    orders.AFFECTED_ORDERS,
    orders.AFFECTED_CUSTOMERS,
    orders.STRATEGIC_CUSTOMERS_AFFECTED,

    orders.AFFECTED_ORDER_UNITS,
    orders.OUTSTANDING_ORDER_UNITS,

    orders.TOTAL_ORDER_VALUE_EXPOSED_USD,
    orders.OUTSTANDING_REVENUE_EXPOSURE_USD,

    COALESCE(
        inventory.INVENTORY_SHORTFALL_UNITS,
        0
    ) AS INVENTORY_SHORTFALL_UNITS,

    COALESCE(
        inventory.PART_PLANT_SHORTFALLS,
        0
    ) AS PART_PLANT_SHORTFALLS,

    inventory.LOWEST_DAYS_OF_INVENTORY,

    COALESCE(
        alternate.PARTS_WITHOUT_ACTIVE_ALTERNATE,
        0
    ) AS PARTS_WITHOUT_ACTIVE_ALTERNATE,

    alternate.FASTEST_AVAILABLE_ALTERNATE_LEAD_TIME_DAYS,

    orders.ORDERS_WITH_LOGISTICS_RISK,

    orders.MAX_IMPACT_RISK_SCORE,
    orders.AVG_IMPACT_RISK_SCORE,

    CASE
        WHEN orders.MAX_IMPACT_RISK_SCORE >= 75
            AND COALESCE(
                alternate.PARTS_WITHOUT_ACTIVE_ALTERNATE,
                0
            ) > 0
            THEN 'ESCALATE_AND_SOURCE_ALTERNATE'

        WHEN orders.MAX_IMPACT_RISK_SCORE >= 75
            THEN 'ESCALATE_AND_EXPEDITE'

        WHEN orders.MAX_IMPACT_RISK_SCORE >= 55
            THEN 'REVIEW_AND_MITIGATE'

        WHEN orders.MAX_IMPACT_RISK_SCORE >= 30
            THEN 'MONITOR_CLOSELY'

        ELSE 'MONITOR'
    END AS RECOMMENDED_RESPONSE

FROM order_exposure orders

LEFT JOIN inventory_exposure inventory
    ON inventory.SUPPLIER_ID
        = orders.SUPPLIER_ID

LEFT JOIN alternate_exposure alternate
    ON alternate.SUPPLIER_ID
        = orders.SUPPLIER_ID;


COMMENT ON VIEW ONTARA.SEMANTIC.SUPPLY_IMPACT_SUMMARY IS
    'Executive governed blast-radius summary with commercial exposure, resilience, risk score and deterministic recommended response';