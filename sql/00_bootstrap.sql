-- Ontara Snowflake bootstrap
--
-- Purpose:
--   Establish the minimum Snowflake infrastructure required for Ontara.
--
-- Execution:
--   Run against the Hack2Skill replacement event account only.
--
-- Expected account:
--   Organization: OIVNDBA
--   Account: YL85787
--   Region: AWS_AP_NORTHEAST_1
--
-- Security:
--   ACCOUNTADMIN is used only for account-level bootstrap.
--   Normal Ontara object creation continues under ONTARA_DEV_ROLE.
--
-- This script is intentionally safe to rerun for the hackathon environment.

-- ---------------------------------------------------------------------------
-- 1. Verify bootstrap context
-- ---------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

SELECT
    CURRENT_ORGANIZATION_NAME() AS organization_name,
    CURRENT_ACCOUNT_NAME() AS account_name,
    CURRENT_ACCOUNT() AS account_locator,
    CURRENT_REGION() AS region,
    CURRENT_USER() AS user_name,
    CURRENT_ROLE() AS role_name;

-- Stop execution manually if the result is not the expected replacement
-- Hack2Skill event account before running the remaining statements.


-- ---------------------------------------------------------------------------
-- 2. Development role
-- ---------------------------------------------------------------------------

CREATE ROLE IF NOT EXISTS ONTARA_DEV_ROLE
    COMMENT = 'Least-privilege development role for Ontara';

-- Keep the custom role inside Snowflake's standard role hierarchy.
GRANT ROLE ONTARA_DEV_ROLE TO ROLE SYSADMIN;

-- The Hack2Skill event user was created as a case-sensitive identifier.
-- Use the exact quoted identifier so Snowflake does not normalize it to
-- uppercase RAHSONU2U.
GRANT ROLE ONTARA_DEV_ROLE
    TO USER "rahsonu2u";

-- ---------------------------------------------------------------------------
-- 3. Development warehouse
-- ---------------------------------------------------------------------------

CREATE WAREHOUSE IF NOT EXISTS ONTARA_WH
    WAREHOUSE_TYPE = STANDARD
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'X-Small development warehouse for Ontara';

GRANT USAGE, OPERATE
    ON WAREHOUSE ONTARA_WH
    TO ROLE ONTARA_DEV_ROLE;


-- ---------------------------------------------------------------------------
-- 4. Database
-- ---------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS ONTARA
    COMMENT = 'Governed Supply Chain Intelligence for Ontara';

GRANT USAGE
    ON DATABASE ONTARA
    TO ROLE ONTARA_DEV_ROLE;


-- ---------------------------------------------------------------------------
-- 5. Application schemas
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS ONTARA.RAW
    COMMENT = 'Source-oriented ingestion boundary';

CREATE SCHEMA IF NOT EXISTS ONTARA.CORE
    COMMENT = 'Typed governed supply-chain relational model';

CREATE SCHEMA IF NOT EXISTS ONTARA.SEMANTIC
    COMMENT = 'Governed semantic definitions and canonical metrics';

CREATE SCHEMA IF NOT EXISTS ONTARA.GOVERNANCE
    COMMENT = 'Governed operational actions and audit state';

CREATE SCHEMA IF NOT EXISTS ONTARA.APP
    COMMENT = 'Application-supporting Snowflake objects';


-- ---------------------------------------------------------------------------
-- 6. Schema usage
-- ---------------------------------------------------------------------------

GRANT USAGE
    ON SCHEMA ONTARA.RAW
    TO ROLE ONTARA_DEV_ROLE;

GRANT USAGE
    ON SCHEMA ONTARA.CORE
    TO ROLE ONTARA_DEV_ROLE;

GRANT USAGE
    ON SCHEMA ONTARA.SEMANTIC
    TO ROLE ONTARA_DEV_ROLE;

-- Allow the development role to create governed native semantic views.
GRANT CREATE SEMANTIC VIEW ON SCHEMA ONTARA.SEMANTIC
    TO ROLE ONTARA_DEV_ROLE;

-- Allow governed analytical views used by ontology impact analysis.
GRANT CREATE VIEW ON SCHEMA ONTARA.SEMANTIC
    TO ROLE ONTARA_DEV_ROLE;

-- Streamlit product-surface privileges.
GRANT USAGE
    ON SCHEMA ONTARA.APP
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE STREAMLIT
    ON SCHEMA ONTARA.APP
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE STAGE
    ON SCHEMA ONTARA.APP
    TO ROLE ONTARA_DEV_ROLE;

-- Governed action-loop privileges.
GRANT USAGE
    ON SCHEMA ONTARA.GOVERNANCE
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE TABLE
    ON SCHEMA ONTARA.GOVERNANCE
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE VIEW
    ON SCHEMA ONTARA.GOVERNANCE
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE PROCEDURE
    ON SCHEMA ONTARA.GOVERNANCE
    TO ROLE ONTARA_DEV_ROLE;

GRANT USAGE
    ON SCHEMA ONTARA.GOVERNANCE
    TO ROLE ONTARA_DEV_ROLE;

GRANT USAGE
    ON SCHEMA ONTARA.APP
    TO ROLE ONTARA_DEV_ROLE;


-- ---------------------------------------------------------------------------
-- 7. Current-feature creation privileges
-- ---------------------------------------------------------------------------
--
-- PR #3 creates RAW ingestion objects and CORE relational objects only.
-- Later features will grant additional narrowly scoped privileges when needed.

GRANT CREATE TABLE, CREATE FILE FORMAT, CREATE STAGE
    ON SCHEMA ONTARA.RAW
    TO ROLE ONTARA_DEV_ROLE;

GRANT CREATE TABLE, CREATE VIEW
    ON SCHEMA ONTARA.CORE
    TO ROLE ONTARA_DEV_ROLE;


-- ---------------------------------------------------------------------------
-- 8. Switch away from ACCOUNTADMIN
-- ---------------------------------------------------------------------------

USE ROLE ONTARA_DEV_ROLE;
USE WAREHOUSE ONTARA_WH;
USE DATABASE ONTARA;
USE SCHEMA RAW;


-- ---------------------------------------------------------------------------
-- 9. Deterministic CSV file format
-- ---------------------------------------------------------------------------

CREATE FILE FORMAT IF NOT EXISTS ONTARA.RAW.ONTARA_CSV_FORMAT
    TYPE = CSV
    COMPRESSION = AUTO
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('')
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    ENCODING = 'UTF8'
    SKIP_BYTE_ORDER_MARK = TRUE
    COMMENT = 'Strict UTF-8 CSV format for deterministic Ontara synthetic data';


-- ---------------------------------------------------------------------------
-- 10. Named internal stage
-- ---------------------------------------------------------------------------

CREATE STAGE IF NOT EXISTS ONTARA.RAW.SYNTHETIC_STAGE
    FILE_FORMAT = (
        FORMAT_NAME = 'ONTARA.RAW.ONTARA_CSV_FORMAT'
    )
    ENCRYPTION = (
        TYPE = 'SNOWFLAKE_SSE'
    )
    COMMENT = 'Internal stage for reproducible Ontara synthetic CSV loading';


-- ---------------------------------------------------------------------------
-- 11. Bootstrap validation
-- ---------------------------------------------------------------------------

SELECT
    CURRENT_ROLE() AS current_role,
    CURRENT_WAREHOUSE() AS current_warehouse,
    CURRENT_DATABASE() AS current_database,
    CURRENT_SCHEMA() AS current_schema;

SHOW FILE FORMATS
    LIKE 'ONTARA_CSV_FORMAT'
    IN SCHEMA ONTARA.RAW;

SHOW STAGES
    LIKE 'SYNTHETIC_STAGE'
    IN SCHEMA ONTARA.RAW;