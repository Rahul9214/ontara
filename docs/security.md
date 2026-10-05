# Security

## Principles

- least privilege,
- explicit trust boundaries,
- no committed credentials,
- governed actions,
- human approval for operational writes,
- auditable mutation history.

## Credential Handling

Snowflake connections remain outside the repository.

Never commit:

- connections.toml,
- Snowflake passwords,
- OAuth credentials,
- tokens,
- private keys,
- API keys,
- Streamlit secrets.

## AI Safety

Conversational output must not directly mutate operational state.

Actions must follow:

recommendation
-> structured proposed action
-> human review
-> explicit approval
-> persisted action
-> audit record

## Data

The hackathon implementation uses synthetic supply-chain data.

## Future Least-Privilege Runtime

The prototype should transition away from ACCOUNTADMIN to a dedicated Ontara role once the
initial Snowflake object bootstrap is established.
