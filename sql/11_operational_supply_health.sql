-- Ontara incremental operational supply-health materialization.
--
-- This pipeline intentionally reads from CORE instead of
-- SUPPLY_IMPACT_DETAILS because the latter contains a non-equality
-- outer-join predicate that is incompatible with incremental refresh.

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE DYNAMIC TABLE ONTARA.SEMANTIC.OPERATIONAL_SUPPLY_HEALTH
    TARGET_LAG = '1 minute'
    WAREHOUSE = ONTARA_WH
    REFRESH_MODE = INCREMENTAL
    INITIALIZE = ON_CREATE
    COMMENT = 'Incremental operational supply-health state for CDC automation.'
AS
WITH latest_inventory AS (
    SELECT
        SNAPSHOT_DATE,
        PLANT_ID,
        PART_ID,
        ON_HAND_UNITS,
        ALLOCATED_UNITS,
        SAFETY_STOCK_UNITS,
        AVG_DAILY_DEMAND_UNITS
    FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY PLANT_ID, PART_ID
        ORDER BY SNAPSHOT_DATE DESC
    ) = 1
),

shipment_rollup AS (
    SELECT
        CUSTOMER_ORDER_ID,
        COUNT_IF(
            STATUS = 'DELAYED'
            OR (
                ACTUAL_DELIVERY_DATE IS NOT NULL
                AND ACTUAL_DELIVERY_DATE > PROMISED_DELIVERY_DATE
            )
        ) AS LATE_OR_DELAYED_SHIPMENT_COUNT
    FROM ONTARA.CORE.SHIPMENTS
    WHERE SHIPMENT_TYPE = 'OUTBOUND'
    GROUP BY CUSTOMER_ORDER_ID
),

purchase_order_rollup AS (
    SELECT
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID,
        COUNT(*) AS SUPPLIER_PLANT_PO_COUNT
    FROM ONTARA.CORE.PURCHASE_ORDERS
    GROUP BY
        SUPPLIER_ID,
        PART_ID,
        PLANT_ID
),

alternate_supplier_rollup AS (
    SELECT
        origin.SUPPLIER_ID AS ORIGIN_SUPPLIER_ID,
        origin.PART_ID,

        COUNT_IF(
            alternate.SUPPLIER_ID <> origin.SUPPLIER_ID
            AND alternate_supplier.STATUS = 'ACTIVE'
        ) AS ACTIVE_ALTERNATE_SUPPLIER_COUNT,

        MIN(
            IFF(
                alternate.SUPPLIER_ID <> origin.SUPPLIER_ID
                AND alternate_supplier.STATUS = 'ACTIVE',
                alternate.LEAD_TIME_DAYS,
                NULL
            )
        ) AS FASTEST_ALTERNATE_LEAD_TIME_DAYS

    FROM ONTARA.CORE.SUPPLIER_PARTS origin

    LEFT JOIN ONTARA.CORE.SUPPLIER_PARTS alternate
        ON alternate.PART_ID = origin.PART_ID

    LEFT JOIN ONTARA.CORE.SUPPLIERS alternate_supplier
        ON alternate_supplier.SUPPLIER_ID = alternate.SUPPLIER_ID

    GROUP BY
        origin.SUPPLIER_ID,
        origin.PART_ID
),

impact_base AS (
    SELECT
        supplier.SUPPLIER_ID,
        supplier.SUPPLIER_NAME,
        supplier.RISK_TIER AS SUPPLIER_RISK_TIER,
        supplier.STATUS AS SUPPLIER_STATUS,

        supplier_part.PART_ID,
        part.PART_NAME,
        supplier_part.LEAD_TIME_DAYS AS CONTRACTED_LEAD_TIME_DAYS,

        customer_order.PLANT_ID,
        plant.PLANT_NAME,

        customer_order.ORDER_ID,
        customer_order.CUSTOMER_ID,
        customer.CUSTOMER_NAME,
        customer.PRIORITY_TIER AS CUSTOMER_PRIORITY_TIER,

        customer_order.ORDERED_UNITS,
        customer_order.FULFILLED_UNITS,

        GREATEST(
            customer_order.ORDERED_UNITS
                - customer_order.FULFILLED_UNITS,
            0
        ) AS OUTSTANDING_ORDER_UNITS,

        ROUND(
            GREATEST(
                customer_order.ORDERED_UNITS
                    - customer_order.FULFILLED_UNITS,
                0
            ) * customer_order.UNIT_SALE_PRICE_USD,
            2
        ) AS OUTSTANDING_REVENUE_EXPOSURE_USD,

        GREATEST(
            COALESCE(inventory.ON_HAND_UNITS, 0)
                - COALESCE(inventory.ALLOCATED_UNITS, 0),
            0
        ) AS AVAILABLE_INVENTORY_UNITS,

        COALESCE(
            inventory.SAFETY_STOCK_UNITS,
            0
        ) AS SAFETY_STOCK_UNITS,

        GREATEST(
            COALESCE(inventory.SAFETY_STOCK_UNITS, 0)
                - GREATEST(
                    COALESCE(inventory.ON_HAND_UNITS, 0)
                        - COALESCE(inventory.ALLOCATED_UNITS, 0),
                    0
                ),
            0
        ) AS INVENTORY_SHORTFALL_TO_SAFETY_UNITS,

        ROUND(
            GREATEST(
                COALESCE(inventory.ON_HAND_UNITS, 0)
                    - COALESCE(inventory.ALLOCATED_UNITS, 0),
                0
            )
            / NULLIF(
                COALESCE(inventory.AVG_DAILY_DEMAND_UNITS, 0),
                0
            ),
            2
        ) AS DAYS_OF_INVENTORY,

        COALESCE(
            shipment.LATE_OR_DELAYED_SHIPMENT_COUNT,
            0
        ) AS LATE_OR_DELAYED_SHIPMENT_COUNT,

        COALESCE(
            alternate.ACTIVE_ALTERNATE_SUPPLIER_COUNT,
            0
        ) AS ACTIVE_ALTERNATE_SUPPLIER_COUNT,

        alternate.FASTEST_ALTERNATE_LEAD_TIME_DAYS

    FROM ONTARA.CORE.SUPPLIER_PARTS supplier_part

    JOIN ONTARA.CORE.SUPPLIERS supplier
        ON supplier.SUPPLIER_ID = supplier_part.SUPPLIER_ID

    JOIN ONTARA.CORE.PARTS part
        ON part.PART_ID = supplier_part.PART_ID

    JOIN ONTARA.CORE.CUSTOMER_ORDERS customer_order
        ON customer_order.PART_ID = supplier_part.PART_ID

    JOIN ONTARA.CORE.CUSTOMERS customer
        ON customer.CUSTOMER_ID = customer_order.CUSTOMER_ID

    JOIN ONTARA.CORE.PLANTS plant
        ON plant.PLANT_ID = customer_order.PLANT_ID

    LEFT JOIN latest_inventory inventory
        ON inventory.PART_ID = customer_order.PART_ID
        AND inventory.PLANT_ID = customer_order.PLANT_ID

    LEFT JOIN shipment_rollup shipment
        ON shipment.CUSTOMER_ORDER_ID = customer_order.ORDER_ID

    LEFT JOIN purchase_order_rollup purchase_order
        ON purchase_order.SUPPLIER_ID = supplier_part.SUPPLIER_ID
        AND purchase_order.PART_ID = supplier_part.PART_ID
        AND purchase_order.PLANT_ID = customer_order.PLANT_ID

    LEFT JOIN alternate_supplier_rollup alternate
        ON alternate.ORIGIN_SUPPLIER_ID = supplier_part.SUPPLIER_ID
        AND alternate.PART_ID = supplier_part.PART_ID

    WHERE
        supplier_part.PRIMARY_SUPPLIER_FLAG
        OR COALESCE(
            purchase_order.SUPPLIER_PLANT_PO_COUNT,
            0
        ) > 0
),

scored AS (
    SELECT
        impact_base.*,

        LEAST(
            100,

            IFF(
                SUPPLIER_STATUS = 'DISRUPTED',
                25,
                0
            )

            + CASE SUPPLIER_RISK_TIER
                WHEN 'HIGH' THEN 20
                WHEN 'MEDIUM' THEN 10
                WHEN 'LOW' THEN 5
                ELSE 5
              END

            + CASE CUSTOMER_PRIORITY_TIER
                WHEN 'STRATEGIC' THEN 15
                WHEN 'PRIORITY' THEN 10
                ELSE 5
              END

            + IFF(
                OUTSTANDING_ORDER_UNITS > 0,
                15,
                0
              )

            + IFF(
                INVENTORY_SHORTFALL_TO_SAFETY_UNITS > 0,
                15,
                0
              )

            + CASE
                WHEN ACTIVE_ALTERNATE_SUPPLIER_COUNT = 0
                    THEN 10
                WHEN FASTEST_ALTERNATE_LEAD_TIME_DAYS
                    > CONTRACTED_LEAD_TIME_DAYS
                    THEN 5
                ELSE 0
              END

            + IFF(
                LATE_OR_DELAYED_SHIPMENT_COUNT > 0,
                10,
                0
              )
        ) AS IMPACT_RISK_SCORE

    FROM impact_base
),

classified AS (
    SELECT
        scored.*,

        CASE
            WHEN IMPACT_RISK_SCORE >= 75 THEN 'CRITICAL'
            WHEN IMPACT_RISK_SCORE >= 55 THEN 'HIGH'
            WHEN IMPACT_RISK_SCORE >= 30 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS IMPACT_RISK_BAND,

        CASE
            WHEN IMPACT_RISK_SCORE >= 80 THEN 'CRITICAL'
            WHEN IMPACT_RISK_SCORE >= 60 THEN 'AT_RISK'
            WHEN IMPACT_RISK_SCORE >= 40 THEN 'WATCH'
            ELSE 'STABLE'
        END AS OPERATIONAL_HEALTH_STATUS,

        CASE
            WHEN IMPACT_RISK_SCORE >= 80
                AND ACTIVE_ALTERNATE_SUPPLIER_COUNT > 0
                THEN 'ESCALATE_AND_EXPEDITE'
            WHEN IMPACT_RISK_SCORE >= 80
                THEN 'ESCALATE_NO_ALTERNATE'
            WHEN IMPACT_RISK_SCORE >= 60
                THEN 'MITIGATE_AND_MONITOR'
            WHEN IMPACT_RISK_SCORE >= 40
                THEN 'MONITOR'
            ELSE 'NO_ACTION'
        END AS RECOMMENDED_RESPONSE

    FROM scored
)

SELECT
    CONCAT(
        SUPPLIER_ID, '|',
        PART_ID, '|',
        PLANT_ID, '|',
        ORDER_ID, '|',
        CUSTOMER_ID
    ) AS HEALTH_KEY,

    SUPPLIER_ID,
    SUPPLIER_NAME,
    SUPPLIER_RISK_TIER,
    SUPPLIER_STATUS,
    PART_ID,
    PART_NAME,
    CONTRACTED_LEAD_TIME_DAYS,
    PLANT_ID,
    PLANT_NAME,
    ORDER_ID,
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CUSTOMER_PRIORITY_TIER,
    ORDERED_UNITS,
    FULFILLED_UNITS,
    OUTSTANDING_ORDER_UNITS,
    OUTSTANDING_REVENUE_EXPOSURE_USD,
    AVAILABLE_INVENTORY_UNITS,
    SAFETY_STOCK_UNITS,
    INVENTORY_SHORTFALL_TO_SAFETY_UNITS,
    DAYS_OF_INVENTORY,
    LATE_OR_DELAYED_SHIPMENT_COUNT,
    ACTIVE_ALTERNATE_SUPPLIER_COUNT,
    FASTEST_ALTERNATE_LEAD_TIME_DAYS,
    IMPACT_RISK_SCORE,
    IMPACT_RISK_BAND,
    OPERATIONAL_HEALTH_STATUS,
    RECOMMENDED_RESPONSE

FROM classified

WHERE
       OUTSTANDING_ORDER_UNITS > 0
    OR SUPPLIER_STATUS = 'DISRUPTED'
    OR IMPACT_RISK_SCORE >= 40
;
