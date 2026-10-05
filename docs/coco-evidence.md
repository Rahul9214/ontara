# CoCo Evidence Log

This document records genuine Cortex Code / CoCo usage during the Ontara lifecycle.

It exists to make the development process auditable and to avoid claiming tool usage that did
not occur.

## Current Environment

- Project: Ontara
- Working directory: `D:\ontara`
- Cortex Code version: `1.1.87`
- Snowflake CLI version: `3.28.0`
- Current event account: `YL85787`
- Organization: `OIVNDBA`
- Account locator: `KS20773`
- Region: `AWS_AP_NORTHEAST_1`
- User: `rahsonu2u`
- Current setup role: `ACCOUNTADMIN`
- Event credits: `$400`

## Original Event Account Incident

The project was initially configured against the event account:

- Organization: `VZPORPJ`
- Account name: `RV94636`
- Account locator: `JN99634`
- Region: `AWS_AP_SOUTHEAST_7`
- User: `rahsonu2u`

### Connection Verification

Verified:

- Agent connection resolved to `RV94636`.
- SQL connection resolved to `RV94636`.
- Local OAuth authentication succeeded.
- SQL read-only mode was enabled.
- Snowflake CLI connection testing succeeded.
- Snowflake account identity was verified through SQL.

### Entitlement Failure

The first CoCo model request returned:

`Cortex Code is not enabled or the usage limit has been reached.`

Request ID:

`836047a4-c2c2-45c0-a6f4-4e230655366f`

Additional diagnostics verified:

- account-level CoCo CLI daily limit = `-1`,
- user-level CoCo CLI daily limit = `-1`,
- cross-region inference = `ANY_REGION`,
- `SNOWFLAKE.CORTEX_USER` was available,
- `SNOWFLAKE.CORTEX_AGENT_USER` was available,
- Cortex base models were visible.

A direct Cortex inference test returned:

`AI function _COMPLETE_WITH_PROMPT_HISTORY_LLM is not available for trial accounts.`

Hackathon support was contacted with the diagnostic evidence.

## Replacement Event Account

Hack2Skill support instructed the project to create a new Snowflake account using a
replacement event-specific signup link and continue development on the newly created account.

Replacement account:

- Organization: `OIVNDBA`
- Account name: `YL85787`
- Account locator: `KS20773`
- Region: `AWS_AP_NORTHEAST_1`
- User: `rahsonu2u`
- Role: `ACCOUNTADMIN`
- Event credits: `$400`

No Ontara database objects had been created in the original account, so no application data or
Snowflake object migration was required.

### Replacement Account Verification

Verified:

- `SNOWFLAKE.CORTEX_USER` is granted and available.
- `SNOWFLAKE.COPILOT_USER` is granted and available.
- `SNOWFLAKE.CORTEX_AGENT_USER` is granted and available.
- `CORTEX_CODE_SNOWSIGHT_DAILY_EST_CREDIT_LIMIT_PER_USER = -1`.
- `CORTEX_CODE_CLI_DAILY_EST_CREDIT_LIMIT_PER_USER = -1`.
- `CORTEX_ENABLED_CROSS_REGION = ANY_REGION`.
- Account authentication and normal Snowflake SQL execution succeed.

### Replacement Account Entitlement Failure

CoCo in Snowsight returned:

`Cortex Code is not enabled or the usage limit has been reached.`

Request ID:

`54983e6e-ce2d-49db-8dd6-f61d2985212f`

A direct Cortex inference check returned:

`AI function _COMPLETE_WITH_PROMPT_HISTORY_LLM is not available for trial accounts.`

Because the required Cortex database roles, CoCo usage parameters, cross-region inference,
authentication, and SQL access are all configured successfully, the remaining blocker is the
trial-account Cortex AI / Cortex Code entitlement.

Hackathon support has been notified again with the replacement-account diagnostics.

## Evidence Policy

Until Cortex Code entitlement is restored:

- deterministic local engineering may continue,
- available Snowflake SQL functionality may be used,
- no CoCo-generated implementation will be claimed,
- no AI output will be fabricated,
- CoCo planning, implementation assistance, review, testing, and validation will resume as soon
  as access becomes available.

## Future Evidence Entries

For each genuine CoCo-assisted development phase, record:

- timestamp,
- Git branch,
- development phase,
- CoCo mode,
- prompt objective,
- Snowflake connection,
- files or Snowflake objects affected,
- commands or tools used,
- validation performed,
- significant output,
- commit or pull request reference.
