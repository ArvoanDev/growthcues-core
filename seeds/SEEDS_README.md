# Development Seed Data

This directory contains seed data for developing and testing the GrowthCues Core dbt package. These seeds simulate realistic Segment/RudderStack event data to enable local development and unit testing without requiring access to a production data warehouse.

## Overview

The seed files replicate the standard Segment event tracking schema and provide ~40 days of synthetic data (January 1, 2026 - February 10, 2026) for testing:

### Seed Files

Seed files use standard Segment table naming convention:

- **tracks.csv** - Event tracking data (78 events)
- **pages.csv** - Page view data (72 page views)
- **identifies.csv** - Anonymous ID to user ID mappings (8 identify calls)
- **users.csv** - User profile data (8 users)
- **groups.csv** - Account/organization data (3 accounts)

### Test Scenarios Covered

The seed data is designed to test:

1. **Multi-account B2B scenarios**
   - 3 accounts (Acme Corp, TechCorp Inc, StartupX)
   - Variable team sizes (2-3 users per account)

2. **User activity patterns**
   - Daily active users (DAU) - users active every day
   - Weekly active users (WAU) - users active weekly
   - Power users vs. casual users
   - User 007 (grace@startupx.io) - churned user with no recent activity

3. **Identity resolution**
   - Anonymous browsing before signup (anon_003 → user_003)
   - Persistent user tracking across sessions

4. **Session analysis**
   - Multiple events within session windows
   - Cross-session activity tracking
   - Page views and track events interleaved

5. **Time-series metrics**
   - 40-day window for testing MAU (monthly active users)
   - Regular activity patterns for trend analysis
   - Account and user cohort analysis

## Setting Up Your Development Environment

### 1. Configure Your dbt Profile

Ensure your `profiles.yml` is configured to use DuckDB for the `dev` target:

```yaml
growthcues_core:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "growthcues.duckdb"
      schema: "main"
      threads: 4
```

The profile should be in:

- `~/.dbt/profiles.yml` (user-level, recommended)
- `./profiles.yml` (project-level, gitignored)

**Note:** The seed files use standard Segment table names (`tracks`, `pages`, etc.) and the `dbt_project.yml` is configured to look in the `main` schema where DuckDB seeds are loaded. This works out-of-the-box for local development.

### 2. Load the Seed Data

Run the following command to load seed data into your DuckDB database:

```bash
dbt seed --target dev
```

This will create the following tables in the `main` schema:

- `main.tracks`
- `main.pages`
- `main.identifies`
- `main.users`
- `main.groups`

### 3. Run the Models

After seeding, run the dbt models:

```bash
# Run all models
dbt run --target dev

# Or run specific model layers
dbt run --target dev --select staging
dbt run --target dev --select marts.core
```

### 4. Test the Models

Run dbt tests to verify data quality:

```bash
dbt test --target dev
```

### 5. Query Your Data

You can query the DuckDB database directly:

```bash
duckdb growthcues.duckdb
```

Example queries:

```sql
-- Check Daily Active Users
SELECT metric_date, dau, mau, user_stickiness_ratio
FROM fct_product_metrics_daily
ORDER BY metric_date DESC
LIMIT 10;

-- Check Account Activity
SELECT account_id, first_seen_at, last_seen_at, lifetime_unique_users
FROM dim_accounts;

-- Check User Activity
SELECT user_id, first_seen_at, last_seen_at, latest_account_id
FROM dim_users;
```

## Data Schema Details

### Account Summary

| Account ID  | Name         | Users | Active Users (Last 30d) |
| ----------- | ------------ | ----- | ----------------------- |
| account_001 | Acme Corp    | 3     | 3                       |
| account_002 | TechCorp Inc | 3     | 3                       |
| account_003 | StartupX     | 2     | 1 (grace churned)       |

### User Summary

| User ID  | Email               | Account     | First Seen | Activity Pattern       |
| -------- | ------------------- | ----------- | ---------- | ---------------------- |
| user_001 | alice@acme.com      | account_001 | 2026-01-01 | Very active (daily)    |
| user_002 | bob@acme.com        | account_001 | 2026-01-02 | Active (frequent)      |
| user_003 | charlie@acme.com    | account_001 | 2026-01-03 | Moderate (weekly)      |
| user_004 | diana@techcorp.com  | account_002 | 2026-01-05 | Very active (daily)    |
| user_005 | edward@techcorp.com | account_002 | 2026-01-05 | Moderate (sporadic)    |
| user_006 | frank@startupx.io   | account_003 | 2026-01-08 | Very active (daily)    |
| user_007 | grace@startupx.io   | account_003 | 2026-01-08 | Churned (last: Jan 18) |
| user_008 | henry@techcorp.com  | account_002 | 2026-01-17 | Active (regular)       |

## Configuration Variables

The source table configuration is handled in `profiles.yml` under each target's `vars:` section (see Setup Step 1 above). This allows different table names per target (dev vs prod).

Additional configuration in `dbt_project.yml`:

```yaml
vars:
  # Session configuration
  session_timeout_minutes: 30
  include_pages_in_sessions: false # Set to true to include page views

  # Identity stitching
  enable_identity_stitching: false # Set to true to test identity resolution
  identity_anonymous_id_field: "anonymous_id"

  # Lookback windows
  tracks_lookback_days: 365
  pages_lookback_days: 365
  identity_lookback_days: 365

  # Group/Account field
  group_id: "context_group_id"
```

### Testing Identity Stitching

To test identity resolution features, update your `dbt_project.yml`:

```yaml
vars:
  enable_identity_stitching: true
  identity_anonymous_id_field: "anonymous_id"
```

Then re-run:

```bash
dbt run --target dev --select stg_identity_resolution+
```

## Using with Production Data

The `dbt_project.yml` is configured by default to use the `main` schema for local development. When you're ready to use this with production Segment data, simply override the schema:

### Option 1: Override via CLI

```bash
dbt run --target prod --vars '{"segment_schema": "segment_events"}'
```

### Option 2: Update dbt_project.yml

Change the `segment_schema` var in your `dbt_project.yml`:

```yaml
vars:
  segment_schema: "segment_events" # or your actual schema name
```

Table names don't need to be overridden since seeds use the standard Segment naming convention.

## Resetting Your Environment

To start fresh:

```bash
# Remove the DuckDB database
rm growthcues.duckdb

# Reload seeds and rebuild
dbt seed --target dev
dbt run --target dev
```

## Extending Seed Data

To add more test data:

1. Follow the CSV schema patterns in existing seeds
2. Ensure timestamp consistency (newer events should have later timestamps)
3. Maintain referential integrity (user_id, account_id, anonymous_id must match)
4. Run `dbt seed --target dev --full-refresh` to reload

## Differences from Integration Test Seeds

The seeds in this directory (`seeds/`) are separate from integration test seeds (`integration_tests/seeds/`):

- **Development seeds** (this directory): For local development, unit testing, and exploring the models
- **Integration test seeds** (`integration_tests/`): For CI/CD and package testing

Both sets of seeds follow the same schema but may contain different data patterns or volumes.

## Troubleshooting

### "Table with name tracks does not exist" error

Make sure you've run `dbt seed --target dev` first to create the tables in the `main` schema.

If you're trying to use production data, make sure to override the `segment_schema` var to point to your actual schema (see "Using with Production Data" section above).

### "Relation not found" errors

Make sure seeds are loaded:

```bash
dbt seed --target dev --full-refresh
```

### Timestamp/date parsing errors

DuckDB should automatically parse the timestamp format `YYYY-MM-DD HH:MM:SS`. If you encounter issues, check that your DuckDB version is up to date.

### Schema not found

Ensure your `profiles.yml` dev target specifies `schema: "main"` (not `segment_events`) since that's where dbt seeds load data in DuckDB.

### No data in fact tables

Check that your lookback windows include the seed data dates:

```yaml
vars:
  tracks_lookback_days: 365 # Ensure this covers your seed date range
```

## Next Steps

Once your dev environment is seeded and models are running:

1. Test metric calculations against expected values
2. Validate dimension tables (users, accounts)
3. Experiment with different configuration variables
4. Add custom models or metrics
5. Test edge cases with additional seed data

For questions or issues, refer to the main [README.md](../README.md) or [CONTRIBUTING.md](../CONTRIBUTING.md).
