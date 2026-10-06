"""Configuration and governed semantic contracts for Ontara."""

APP_TITLE = "Ontara"
APP_SUBTITLE = "Governed Supply Chain Intelligence"
TAGLINE = "One supply chain. Shared definitions. Trusted answers."

SEMANTIC_VIEW = "ONTARA.SEMANTIC.SUPPLY_CHAIN"
SEMANTIC_CONTRACT_VERSION = "1.0.0"

METRICS = {
    "On-Time Delivery": {
        "column": "ON_TIME_DELIVERY_PCT",
        "version": "OTD_V1",
        "unit": "%",
        "precision": 2,
        "definition": (
            "Percentage of completed outbound deliveries arriving on or "
            "before the promised delivery date."
        ),
        "source": "shipments.ON_TIME_DELIVERY_PCT",
        "query": """
SELECT *
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    METRICS shipments.ON_TIME_DELIVERY_PCT
)
""",
        "aliases": (
            "on-time delivery",
            "on time delivery",
            "otd",
            "delivery performance",
        ),
    },
    "Fill Rate": {
        "column": "FILL_RATE_PCT",
        "version": "FILL_RATE_V1",
        "unit": "%",
        "precision": 2,
        "definition": (
            "Quantity-weighted fulfilled customer units divided by "
            "ordered customer units."
        ),
        "source": "customer_orders.FILL_RATE_PCT",
        "query": """
SELECT *
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    METRICS customer_orders.FILL_RATE_PCT
)
""",
        "aliases": (
            "fill rate",
            "order fill",
            "fulfillment rate",
            "demand fulfillment",
        ),
    },
    "Days of Inventory": {
        "column": "DAYS_OF_INVENTORY",
        "version": "DOI_V1",
        "unit": " days",
        "precision": 2,
        "definition": (
            "Latest available physical inventory divided by average "
            "daily demand."
        ),
        "source": "inventory_current.DAYS_OF_INVENTORY",
        "query": """
SELECT *
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    METRICS inventory_current.DAYS_OF_INVENTORY
)
""",
        "aliases": (
            "days of inventory",
            "days of supply",
            "doi",
            "inventory coverage",
            "inventory days",
        ),
    },
    "Landed Cost / Unit": {
        "column": "LANDED_COST_PER_UNIT_USD",
        "version": "LANDED_COST_V1",
        "unit": " USD",
        "precision": 2,
        "definition": (
            "Quantity-weighted purchase cost plus freight, duty, and "
            "handling per ordered unit."
        ),
        "source": "purchase_orders.LANDED_COST_PER_UNIT_USD",
        "query": """
SELECT *
FROM SEMANTIC_VIEW(
    ONTARA.SEMANTIC.SUPPLY_CHAIN
    METRICS purchase_orders.LANDED_COST_PER_UNIT_USD
)
""",
        "aliases": (
            "landed cost",
            "landed unit cost",
            "procurement landed cost",
            "delivered procurement cost",
        ),
    },
}

PERSONA_QUESTIONS = {
    "On-Time Delivery": [
        (
            "Planning",
            "What percentage of customer deliveries arrived on time?",
        ),
        (
            "Procurement",
            "What is our current outbound delivery performance?",
        ),
        (
            "Logistics",
            "What is the on-time delivery rate?",
        ),
    ],
    "Fill Rate": [
        (
            "Planning",
            "How much customer demand are we fulfilling?",
        ),
        (
            "Procurement",
            "What is the current order fill rate?",
        ),
        (
            "Logistics",
            "What percentage of ordered units were fulfilled?",
        ),
    ],
    "Days of Inventory": [
        (
            "Planning",
            "How many days of supply do we currently have?",
        ),
        (
            "Procurement",
            "What is our current inventory coverage?",
        ),
        (
            "Logistics",
            "What are our days of inventory?",
        ),
    ],
    "Landed Cost / Unit": [
        (
            "Planning",
            "What is our average delivered procurement cost per unit?",
        ),
        (
            "Procurement",
            "What is the landed unit cost?",
        ),
        (
            "Logistics",
            "What is purchase cost plus freight, duty, and handling per unit?",
        ),
    ],
}

ASK_EXAMPLES = (
    "What is our on-time delivery rate?",
    "What is the current fill rate?",
    "How many days of inventory do we have?",
    "What is our landed cost per unit?",
    "What is the downstream impact of disrupted supplier SUP-003?",
)

APP_CSS = """
<style>
    .stApp {
        background:
            radial-gradient(
                circle at 15% 0%,
                rgba(99, 102, 241, 0.11),
                transparent 32%
            ),
            radial-gradient(
                circle at 90% 12%,
                rgba(14, 165, 233, 0.08),
                transparent 28%
            );
    }

    .ontara-brand {
        padding: 0.25rem 0 1.1rem 0;
    }

    .ontara-kicker {
        color: #6366f1;
        font-size: 0.78rem;
        font-weight: 700;
        letter-spacing: 0.13em;
        text-transform: uppercase;
    }

    .ontara-title {
        font-size: 2.65rem;
        font-weight: 760;
        letter-spacing: -0.045em;
        line-height: 1.02;
        margin-top: 0.28rem;
    }

    .ontara-subtitle {
        color: rgba(127, 127, 127, 0.95);
        font-size: 1.02rem;
        margin-top: 0.45rem;
        max-width: 760px;
    }

    .trust-strip {
        border: 1px solid rgba(99, 102, 241, 0.18);
        border-radius: 16px;
        padding: 0.8rem 1rem;
        margin: 0.65rem 0 1.3rem 0;
        background: rgba(99, 102, 241, 0.04);
    }

    .trust-strip strong {
        color: #6366f1;
    }

    .surface-card {
        border: 1px solid rgba(128, 128, 128, 0.18);
        border-radius: 16px;
        padding: 1rem;
        min-height: 128px;
        background: rgba(128, 128, 128, 0.025);
    }

    .surface-card h4 {
        margin: 0 0 0.45rem 0;
    }

    .surface-card p {
        color: rgba(127, 127, 127, 0.95);
        margin-bottom: 0;
    }

    .contract-pass {
        border: 1px solid rgba(34, 197, 94, 0.35);
        background: rgba(34, 197, 94, 0.07);
        border-radius: 14px;
        padding: 0.8rem 1rem;
        margin: 0.6rem 0 1rem 0;
    }

    .guardrail {
        border: 1px solid rgba(245, 158, 11, 0.32);
        background: rgba(245, 158, 11, 0.06);
        border-radius: 14px;
        padding: 0.8rem 1rem;
    }

    div[data-testid="stMetric"] {
        border: 1px solid rgba(128, 128, 128, 0.14);
        border-radius: 16px;
        padding: 0.8rem 0.9rem;
        background: rgba(128, 128, 128, 0.025);
    }

    section[data-testid="stSidebar"] {
        border-right: 1px solid rgba(128, 128, 128, 0.13);
    }
</style>
"""