-- Ontara governed semantic layer
--
-- Semantic contract version: 1.0.0
--
-- Canonical metrics:
--   - On-Time Delivery
--   - Fill Rate
--   - Days of Inventory
--   - Landed Cost per Unit
--
-- Governed business entities:
--   Supplier
--   Part
--   Plant
--   Shipment
--   Customer Order
--   Purchase Order
--   Customer
--
-- The semantic graph intentionally avoids redundant direct relationship
-- paths. Shipment metrics use the appropriate order relationship so that
-- Snowflake can resolve dimensions without ambiguous joins.


USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA SEMANTIC;


CREATE OR ALTER SEMANTIC VIEW ONTARA.SEMANTIC.SUPPLY_CHAIN

TABLES (

    suppliers AS ONTARA.CORE.SUPPLIERS
        PRIMARY KEY (SUPPLIER_ID)
        WITH SYNONYMS ('vendors')
        COMMENT = 'Governed supplier master',

    supplier_parts AS ONTARA.CORE.SUPPLIER_PARTS
        PRIMARY KEY (SUPPLIER_ID, PART_ID)
        WITH SYNONYMS (
            'supplier sourcing',
            'approved sources',
            'sourcing relationships'
        )
        COMMENT = 'Governed supplier-to-part sourcing bridge',

    parts AS ONTARA.CORE.PARTS
        PRIMARY KEY (PART_ID)
        WITH SYNONYMS ('components', 'materials')
        COMMENT = 'Governed part and component master',

    plants AS ONTARA.CORE.PLANTS
        PRIMARY KEY (PLANT_ID)
        WITH SYNONYMS ('facilities', 'sites')
        COMMENT = 'Governed manufacturing and distribution plant master',

    customers AS ONTARA.CORE.CUSTOMERS
        PRIMARY KEY (CUSTOMER_ID)
        WITH SYNONYMS ('accounts')
        COMMENT = 'Governed customer master',

    shipments AS ONTARA.CORE.SHIPMENTS
        PRIMARY KEY (SHIPMENT_ID)
        WITH SYNONYMS ('deliveries')
        COMMENT = 'Governed inbound and outbound shipment facts',

    customer_orders AS ONTARA.CORE.CUSTOMER_ORDERS
        PRIMARY KEY (ORDER_ID)
        WITH SYNONYMS ('orders', 'sales orders')
        COMMENT = 'Governed customer demand and fulfillment orders',

    purchase_orders AS ONTARA.CORE.PURCHASE_ORDERS
        PRIMARY KEY (PURCHASE_ORDER_ID)
        WITH SYNONYMS ('procurement orders', 'purchase orders')
        COMMENT = 'Governed inbound procurement orders and landed-cost inputs',

    inventory_current AS (
        SELECT
            i.SNAPSHOT_DATE,
            i.PLANT_ID,
            pl.PLANT_NAME,
            pl.REGION AS PLANT_REGION,
            i.PART_ID,
            p.PART_NAME,
            p.CATEGORY AS PART_CATEGORY,
            i.ON_HAND_UNITS,
            i.ALLOCATED_UNITS,
            i.IN_TRANSIT_UNITS,
            i.SAFETY_STOCK_UNITS,
            i.AVG_DAILY_DEMAND_UNITS
        FROM ONTARA.CORE.INVENTORY_SNAPSHOTS i
        JOIN ONTARA.CORE.PLANTS pl
            ON pl.PLANT_ID = i.PLANT_ID
        JOIN ONTARA.CORE.PARTS p
            ON p.PART_ID = i.PART_ID
        WHERE i.SNAPSHOT_DATE = (
            SELECT MAX(SNAPSHOT_DATE)
            FROM ONTARA.CORE.INVENTORY_SNAPSHOTS
        )
    )
        PRIMARY KEY (SNAPSHOT_DATE, PLANT_ID, PART_ID)
        WITH SYNONYMS ('inventory', 'stock')
        COMMENT = 'Latest governed plant-part inventory snapshot',

            blast_radius_paths AS (
        SELECT
            s.SUPPLIER_ID,
            s.SUPPLIER_NAME,
            s.RISK_TIER,
            s.STATUS AS SUPPLIER_STATUS,

            sp.PART_ID,
            p.PART_NAME,
            sp.PRIMARY_SUPPLIER_FLAG,
            sp.LEAD_TIME_DAYS,

            co.PLANT_ID,
            pl.PLANT_NAME,

            sh.SHIPMENT_ID,
            sh.STATUS AS SHIPMENT_STATUS,
            sh.PROMISED_DELIVERY_DATE
                AS SHIPMENT_PROMISED_DELIVERY_DATE,
            sh.ACTUAL_DELIVERY_DATE
                AS SHIPMENT_ACTUAL_DELIVERY_DATE,

            co.ORDER_ID,
            co.STATUS AS ORDER_STATUS,
            co.CUSTOMER_ID,

            c.CUSTOMER_NAME,
            c.PRIORITY_TIER

        FROM ONTARA.CORE.SUPPLIER_PARTS sp

        JOIN ONTARA.CORE.SUPPLIERS s
            ON s.SUPPLIER_ID = sp.SUPPLIER_ID

        JOIN ONTARA.CORE.PARTS p
            ON p.PART_ID = sp.PART_ID

        JOIN ONTARA.CORE.CUSTOMER_ORDERS co
            ON co.PART_ID = sp.PART_ID

        JOIN ONTARA.CORE.PLANTS pl
            ON pl.PLANT_ID = co.PLANT_ID

        JOIN ONTARA.CORE.CUSTOMERS c
            ON c.CUSTOMER_ID = co.CUSTOMER_ID

        LEFT JOIN ONTARA.CORE.SHIPMENTS sh
            ON sh.CUSTOMER_ORDER_ID = co.ORDER_ID
            AND sh.SHIPMENT_TYPE = 'OUTBOUND'
    )
        WITH SYNONYMS (
            'blast radius',
            'supply impact paths',
            'disruption paths',
            'impact lineage'
        )
        COMMENT = 'Governed deterministic Supplier-to-Part-to-Plant-to-Shipment-to-Order-to-Customer impact traversal'

)

RELATIONSHIPS (

    supplier_parts_to_suppliers AS
        supplier_parts (SUPPLIER_ID)
        REFERENCES suppliers (SUPPLIER_ID),

    supplier_parts_to_parts AS
        supplier_parts (PART_ID)
        REFERENCES parts (PART_ID),

    purchase_orders_to_suppliers AS
        purchase_orders (SUPPLIER_ID)
        REFERENCES suppliers (SUPPLIER_ID),

    purchase_orders_to_parts AS
        purchase_orders (PART_ID)
        REFERENCES parts (PART_ID),

    purchase_orders_to_plants AS
        purchase_orders (PLANT_ID)
        REFERENCES plants (PLANT_ID),

    customer_orders_to_customers AS
        customer_orders (CUSTOMER_ID)
        REFERENCES customers (CUSTOMER_ID),

    customer_orders_to_parts AS
        customer_orders (PART_ID)
        REFERENCES parts (PART_ID),

    customer_orders_to_plants AS
        customer_orders (PLANT_ID)
        REFERENCES plants (PLANT_ID),

    shipments_to_purchase_orders AS
        shipments (PURCHASE_ORDER_ID)
        REFERENCES purchase_orders (PURCHASE_ORDER_ID),

    shipments_to_customer_orders AS
        shipments (CUSTOMER_ORDER_ID)
        REFERENCES customer_orders (ORDER_ID)

)

DIMENSIONS (

        -- -----------------------------------------------------------------------
    -- Governed Blast-Radius Traversal
    -- -----------------------------------------------------------------------

    blast_radius_paths.supplier_id
        AS blast_radius_paths.SUPPLIER_ID
        COMMENT = 'Supplier at the origin of the governed impact path',

    blast_radius_paths.supplier_name
        AS blast_radius_paths.SUPPLIER_NAME
        COMMENT = 'Supplier business name in the impact path',

    blast_radius_paths.risk_tier
        AS blast_radius_paths.RISK_TIER
        COMMENT = 'Supplier risk tier in the impact path',

    blast_radius_paths.supplier_status
        AS blast_radius_paths.SUPPLIER_STATUS
        COMMENT = 'Supplier operating status in the impact path',

    blast_radius_paths.part_id
        AS blast_radius_paths.PART_ID
        COMMENT = 'Part exposed to the supplier disruption',

    blast_radius_paths.part_name
        AS blast_radius_paths.PART_NAME
        COMMENT = 'Exposed part name',

    blast_radius_paths.plant_id
        AS blast_radius_paths.PLANT_ID
        COMMENT = 'Plant associated with the affected order',

    blast_radius_paths.plant_name
        AS blast_radius_paths.PLANT_NAME
        COMMENT = 'Affected plant name',

    blast_radius_paths.shipment_id
        AS blast_radius_paths.SHIPMENT_ID
        COMMENT = 'Outbound shipment associated with the affected order',

    blast_radius_paths.shipment_status
        AS blast_radius_paths.SHIPMENT_STATUS
        COMMENT = 'Current outbound shipment status',

    blast_radius_paths.shipment_promised_delivery_date
        AS blast_radius_paths.SHIPMENT_PROMISED_DELIVERY_DATE
        COMMENT = 'Promised delivery date of the affected shipment',

    blast_radius_paths.shipment_actual_delivery_date
        AS blast_radius_paths.SHIPMENT_ACTUAL_DELIVERY_DATE
        COMMENT = 'Actual delivery date of the affected shipment',

    blast_radius_paths.order_id
        AS blast_radius_paths.ORDER_ID
        COMMENT = 'Customer order exposed through the governed path',

    blast_radius_paths.order_status
        AS blast_radius_paths.ORDER_STATUS
        COMMENT = 'Current status of the affected customer order',

    blast_radius_paths.customer_id
        AS blast_radius_paths.CUSTOMER_ID
        COMMENT = 'Customer associated with the affected order',

    blast_radius_paths.customer_name
        AS blast_radius_paths.CUSTOMER_NAME
        COMMENT = 'Affected customer business name',

    blast_radius_paths.priority_tier
        AS blast_radius_paths.PRIORITY_TIER
        COMMENT = 'Affected customer priority tier',

    -- -----------------------------------------------------------------------
    -- Supplier-Part Sourcing Bridge
    -- -----------------------------------------------------------------------

    supplier_parts.supplier_id
        AS supplier_parts.SUPPLIER_ID
        COMMENT = 'Supplier participating in the sourcing relationship',

    supplier_parts.part_id
        AS supplier_parts.PART_ID
        COMMENT = 'Part sourced from the supplier',

    supplier_parts.lead_time_days
        AS supplier_parts.LEAD_TIME_DAYS
        COMMENT = 'Contracted supplier lead time in days',

    supplier_parts.contracted_unit_cost_usd
        AS supplier_parts.CONTRACTED_UNIT_COST_USD
        COMMENT = 'Contracted unit sourcing cost in USD',

    supplier_parts.minimum_order_quantity
        AS supplier_parts.MINIMUM_ORDER_QUANTITY
        COMMENT = 'Minimum contracted order quantity',

    supplier_parts.primary_supplier_flag
        AS supplier_parts.PRIMARY_SUPPLIER_FLAG
        COMMENT = 'Whether the supplier is the primary governed source for the part',

    -- -----------------------------------------------------------------------
    -- Supplier
    -- -----------------------------------------------------------------------

    suppliers.supplier_id
        AS suppliers.SUPPLIER_ID
        COMMENT = 'Unique supplier identifier',

    suppliers.supplier_name
        AS suppliers.SUPPLIER_NAME
        COMMENT = 'Supplier business name',

    suppliers.supplier_country_code
        AS suppliers.COUNTRY_CODE
        COMMENT = 'Supplier country code',

    suppliers.risk_tier
        AS suppliers.RISK_TIER
        COMMENT = 'Governed supplier risk tier',

    suppliers.supplier_status
        AS suppliers.STATUS
        COMMENT = 'Current supplier operating status',


    -- -----------------------------------------------------------------------
    -- Part
    -- -----------------------------------------------------------------------

    parts.part_id
        AS parts.PART_ID
        COMMENT = 'Unique part identifier',

    parts.part_name
        AS parts.PART_NAME
        COMMENT = 'Part or component name',

    parts.part_category
        AS parts.CATEGORY
        COMMENT = 'Part category',

    parts.unit_of_measure
        AS parts.UNIT_OF_MEASURE
        COMMENT = 'Part unit of measure',


    -- -----------------------------------------------------------------------
    -- Plant
    -- -----------------------------------------------------------------------

    plants.plant_id
        AS plants.PLANT_ID
        COMMENT = 'Unique plant identifier',

    plants.plant_name
        AS plants.PLANT_NAME
        COMMENT = 'Plant or facility name',

    plants.plant_country_code
        AS plants.COUNTRY_CODE
        COMMENT = 'Plant country code',

    plants.region
        AS plants.REGION
        COMMENT = 'Plant operating region',

    plants.capacity_class
        AS plants.CAPACITY_CLASS
        COMMENT = 'Governed plant capacity classification',


    -- -----------------------------------------------------------------------
    -- Customer
    -- -----------------------------------------------------------------------

    customers.customer_id
        AS customers.CUSTOMER_ID
        COMMENT = 'Unique customer identifier',

    customers.customer_name
        AS customers.CUSTOMER_NAME
        COMMENT = 'Customer business name',

    customers.segment
        AS customers.SEGMENT
        COMMENT = 'Customer business segment',

    customers.customer_country_code
        AS customers.COUNTRY_CODE
        COMMENT = 'Customer country code',

    customers.priority_tier
        AS customers.PRIORITY_TIER
        COMMENT = 'Customer priority classification',


    -- -----------------------------------------------------------------------
    -- Shipment
    -- -----------------------------------------------------------------------

    shipments.shipment_id
        AS shipments.SHIPMENT_ID
        COMMENT = 'Unique shipment identifier',

    shipments.shipment_type
        AS shipments.SHIPMENT_TYPE
        COMMENT = 'Inbound or outbound shipment classification',

    shipments.shipment_status
        AS shipments.STATUS
        COMMENT = 'Current governed shipment status',

    shipments.carrier
        AS shipments.CARRIER
        COMMENT = 'Shipment carrier',

    shipments.plant_id
        AS shipments.PLANT_ID
        COMMENT = 'Plant associated with the shipment',

    shipments.part_id
        AS shipments.PART_ID
        COMMENT = 'Part associated with the shipment',

    shipments.supplier_id
        AS shipments.SUPPLIER_ID
        COMMENT = 'Supplier associated with an inbound shipment',

    shipments.customer_id
        AS shipments.CUSTOMER_ID
        COMMENT = 'Customer associated with an outbound shipment',

    shipments.purchase_order_id
        AS shipments.PURCHASE_ORDER_ID
        COMMENT = 'Purchase order associated with an inbound shipment',

    shipments.customer_order_id
        AS shipments.CUSTOMER_ORDER_ID
        COMMENT = 'Customer order associated with an outbound shipment',

    shipments.ship_date
        AS shipments.SHIP_DATE
        COMMENT = 'Shipment departure date',

    shipments.promised_delivery_date
        AS shipments.PROMISED_DELIVERY_DATE
        COMMENT = 'Contracted delivery date',

    shipments.actual_delivery_date
        AS shipments.ACTUAL_DELIVERY_DATE
        COMMENT = 'Actual completed delivery date',


    -- -----------------------------------------------------------------------
    -- Customer Order
    -- -----------------------------------------------------------------------

    customer_orders.order_id
        AS customer_orders.ORDER_ID
        COMMENT = 'Unique customer order identifier',

    customer_orders.order_status
        AS customer_orders.STATUS
        COMMENT = 'Current customer order status',

    customer_orders.customer_id
        AS customer_orders.CUSTOMER_ID
        COMMENT = 'Customer placing the order',

    customer_orders.plant_id
        AS customer_orders.PLANT_ID
        COMMENT = 'Plant fulfilling the order',

    customer_orders.part_id
        AS customer_orders.PART_ID
        COMMENT = 'Part requested by the customer',

    customer_orders.order_date
        AS customer_orders.ORDER_DATE
        COMMENT = 'Customer order creation date',

    customer_orders.promised_ship_date
        AS customer_orders.PROMISED_SHIP_DATE
        COMMENT = 'Promised customer ship date',


    -- -----------------------------------------------------------------------
    -- Purchase Order
    -- -----------------------------------------------------------------------

    purchase_orders.purchase_order_id
        AS purchase_orders.PURCHASE_ORDER_ID
        COMMENT = 'Unique purchase order identifier',

    purchase_orders.purchase_order_status
        AS purchase_orders.STATUS
        COMMENT = 'Current purchase order status',

    purchase_orders.supplier_id
        AS purchase_orders.SUPPLIER_ID
        COMMENT = 'Supplier receiving the purchase order',

    purchase_orders.plant_id
        AS purchase_orders.PLANT_ID
        COMMENT = 'Destination plant',

    purchase_orders.part_id
        AS purchase_orders.PART_ID
        COMMENT = 'Part being procured',

    purchase_orders.order_date
        AS purchase_orders.ORDER_DATE
        COMMENT = 'Purchase order creation date',

    purchase_orders.promised_delivery_date
        AS purchase_orders.PROMISED_DELIVERY_DATE
        COMMENT = 'Promised inbound delivery date',


    -- -----------------------------------------------------------------------
    -- Current Inventory
    -- -----------------------------------------------------------------------

    inventory_current.snapshot_date
        AS inventory_current.SNAPSHOT_DATE
        COMMENT = 'Latest governed inventory snapshot date',

    inventory_current.plant_id
        AS inventory_current.PLANT_ID
        COMMENT = 'Inventory plant identifier',

    inventory_current.plant_name
        AS inventory_current.PLANT_NAME
        COMMENT = 'Inventory plant name',

    inventory_current.plant_region
        AS inventory_current.PLANT_REGION
        COMMENT = 'Inventory plant region',

    inventory_current.part_id
        AS inventory_current.PART_ID
        COMMENT = 'Inventory part identifier',

    inventory_current.part_name
        AS inventory_current.PART_NAME
        COMMENT = 'Inventory part name',

    inventory_current.part_category
        AS inventory_current.PART_CATEGORY
        COMMENT = 'Inventory part category'

)

METRICS (

    shipments.on_time_delivery_pct
        USING (shipments_to_customer_orders)
        AS (
            100.0
            * COUNT_IF(
                shipments.SHIPMENT_TYPE = 'OUTBOUND'
                AND shipments.STATUS = 'DELIVERED'
                AND shipments.ACTUAL_DELIVERY_DATE IS NOT NULL
                AND shipments.ACTUAL_DELIVERY_DATE
                    <= shipments.PROMISED_DELIVERY_DATE
            )
            / NULLIF(
                COUNT_IF(
                    shipments.SHIPMENT_TYPE = 'OUTBOUND'
                    AND shipments.STATUS = 'DELIVERED'
                    AND shipments.ACTUAL_DELIVERY_DATE IS NOT NULL
                ),
                0
            )
        )
        WITH SYNONYMS (
            'OTD',
            'on time delivery',
            'on-time delivery rate',
            'delivery performance'
        )
        COMMENT = 'OTD_V1: percentage of completed outbound deliveries arriving on or before promised delivery date',

    customer_orders.fill_rate_pct
        USING (
            customer_orders_to_customers,
            customer_orders_to_parts,
            customer_orders_to_plants
        )
        AS (
            100.0
            * SUM(customer_orders.FULFILLED_UNITS)
            / NULLIF(SUM(customer_orders.ORDERED_UNITS), 0)
        )
        WITH SYNONYMS (
            'fill rate',
            'order fill rate',
            'fulfillment rate',
            'demand fulfillment'
        )
        COMMENT = 'FILL_RATE_V1: quantity-weighted fulfilled customer units divided by ordered customer units',

    inventory_current.days_of_inventory
        AS (
            SUM(
                inventory_current.ON_HAND_UNITS
                - inventory_current.ALLOCATED_UNITS
            )
            / NULLIF(
                SUM(inventory_current.AVG_DAILY_DEMAND_UNITS),
                0
            )
        )
        WITH SYNONYMS (
            'DOI',
            'days of supply',
            'inventory coverage',
            'inventory days'
        )
        COMMENT = 'DOI_V1: latest available physical inventory divided by average daily demand',

    purchase_orders.landed_cost_per_unit_usd
        USING (
            purchase_orders_to_suppliers,
            purchase_orders_to_parts,
            purchase_orders_to_plants
        )
        AS (
            SUM(
                purchase_orders.ORDERED_UNITS
                    * purchase_orders.UNIT_PURCHASE_COST_USD
                + purchase_orders.FREIGHT_COST_USD
                + purchase_orders.DUTY_COST_USD
                + purchase_orders.HANDLING_COST_USD
            )
            / NULLIF(
                SUM(purchase_orders.ORDERED_UNITS),
                0
            )
        )
        WITH SYNONYMS (
            'landed cost',
            'landed unit cost',
            'procurement landed cost',
            'delivered procurement cost'
        )
        COMMENT = 'LANDED_COST_V1: quantity-weighted purchase cost plus freight, duty, and handling per ordered unit'

)

COMMENT = 'Ontara governed supply-chain semantic contract version 1.0.0'

AI_VERIFIED_QUERIES (

    canonical_otd AS (
        QUESTION 'What is our on-time delivery rate?'
        VERIFIED_AT 1791249000
        ONBOARDING_QUESTION TRUE
        VERIFIED_BY '(STEWARD = ontara_data_steward)'
        SQL 'SELECT
                 ROUND(ON_TIME_DELIVERY_PCT, 2)
                     AS ON_TIME_DELIVERY_PCT
             FROM SEMANTIC_VIEW(
                 ONTARA.SEMANTIC.SUPPLY_CHAIN
                 METRICS shipments.on_time_delivery_pct
             )'
    ),

    canonical_fill_rate AS (
        QUESTION 'What is our fill rate?'
        VERIFIED_AT 1791249000
        ONBOARDING_QUESTION TRUE
        VERIFIED_BY '(STEWARD = ontara_data_steward)'
        SQL 'SELECT
                 ROUND(FILL_RATE_PCT, 2)
                     AS FILL_RATE_PCT
             FROM SEMANTIC_VIEW(
                 ONTARA.SEMANTIC.SUPPLY_CHAIN
                 METRICS customer_orders.fill_rate_pct
             )'
    ),

    canonical_days_of_inventory AS (
        QUESTION 'How many days of inventory do we have?'
        VERIFIED_AT 1791249000
        ONBOARDING_QUESTION TRUE
        VERIFIED_BY '(STEWARD = ontara_data_steward)'
        SQL 'SELECT
                 ROUND(DAYS_OF_INVENTORY, 2)
                     AS DAYS_OF_INVENTORY
             FROM SEMANTIC_VIEW(
                 ONTARA.SEMANTIC.SUPPLY_CHAIN
                 METRICS inventory_current.days_of_inventory
             )'
    ),

    canonical_landed_cost AS (
        QUESTION 'What is our landed cost per unit?'
        VERIFIED_AT 1791249000
        ONBOARDING_QUESTION TRUE
        VERIFIED_BY '(STEWARD = ontara_data_steward)'
        SQL 'SELECT
                 ROUND(LANDED_COST_PER_UNIT_USD, 2)
                     AS LANDED_COST_PER_UNIT_USD
             FROM SEMANTIC_VIEW(
                 ONTARA.SEMANTIC.SUPPLY_CHAIN
                 METRICS purchase_orders.landed_cost_per_unit_usd
             )'
    ),

    disrupted_supplier_blast_radius AS (
        QUESTION 'What is the downstream impact of disrupted supplier SUP-003 on part PRT-009?'
        VERIFIED_AT 1791249000
        ONBOARDING_QUESTION TRUE
        VERIFIED_BY '(STEWARD = ontara_data_steward)'
        SQL 'SELECT *
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
                 WHERE blast_radius_paths.supplier_id = ''SUP-003''
                   AND blast_radius_paths.part_id = ''PRT-009''
             )'
    )

);