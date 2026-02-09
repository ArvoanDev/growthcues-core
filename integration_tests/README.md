# Integration Tests for GrowthCues Core

This folder contains integration tests to validate the GrowthCues Core package works correctly on both Snowflake and BigQuery.

## Running Tests Locally

### Prerequisites

- dbt Core installed (`dbt-snowflake` or `dbt-bigquery`)
- Access to a test warehouse/project
- Add an `integration_tests` profile to your `~/.dbt/profiles.yml`:

```yaml
integration_tests:
  target: bigquery # or snowflake
  outputs:
    bigquery:
      type: bigquery
      method: oauth # or service-account
      project: YOUR_GCP_PROJECT_ID
      dataset: dbt_integration_tests
      threads: 4
      location: US
    snowflake:
      type: snowflake
      account: YOUR_ACCOUNT
      user: YOUR_USERNAME
      password: YOUR_PASSWORD
      role: YOUR_ROLE
      database: YOUR_DATABASE
      warehouse: YOUR_WAREHOUSE
      schema: dbt_integration_tests
      threads: 4
```

**Note:** There is no `profiles.yml` file in this directory by design - dbt will use your `~/.dbt/profiles.yml` configuration.

### Setup

1. Install dependencies:

```bash
cd integration_tests
dbt deps
```

2. Load seed data:

```bash
dbt seed --target bigquery  # or --target snowflake
```

3. Run models:

```bash
dbt run --target bigquery  # or --target snowflake
```

4. Run tests:

```bash
dbt test --target bigquery  # or --target snowflake
```

## Seed Data

The seed files in `seeds/` contain minimal test data that simulates a Segment/Rudderstack data structure:

- **segment_tracks.csv**: Sample event tracking data with multiple users and accounts
- **segment_pages.csv**: Sample page view data
- **segment_identifies.csv**: Identity resolution data linking anonymous IDs to user IDs
- **segment_users.csv**: User dimension data
- **segment_groups.csv**: Account/group dimension data

## CI/CD

GitHub Actions automatically runs these tests on every push and pull request against both Snowflake and BigQuery warehouses.

See `.github/workflows/integration_tests.yml` for the CI configuration.
