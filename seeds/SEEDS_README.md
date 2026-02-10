# Development Seed Data

This directory contains seed data for developing and testing the GrowthCues Core dbt package. These seeds simulate realistic Segment/RudderStack event data to enable local development and unit testing without requiring access to a production data warehouse.

## Overview

The seed files replicate the standard Segment event tracking schema and provide ~40 days of synthetic data (January 1, 2026 - February 10, 2026) for testing:

### Seed Files

- **segment_tracks.csv** - Event tracking data (78 events)
- **segment_pages.csv** - Page view data (72 page views)
- **segment_identifies.csv** - Anonymous ID to user ID mappings (8 identify calls)
- **segment_users.csv** - User profile data (8 users)
- **segment_groups.csv** - Account/organization data (3 accounts)

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

Ensure your `profiles.yml` is configured to use DuckDB for the `dev` target. Example profile configuration:

```yaml
growthcues_core:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "growthcues.duckdb"
      schema: segment_events
      threads: 4
```

The profile can be in:

- `~/.dbt/profiles.yml` (user-level)
- `./profiles.yml` (project-level, gitignored)

### 2. Configure Source Table Names

Add the following to your `dbt_project.yml` to point dbt to the seed tables. Since seeds are loaded into the `main` schema with names like `segment_tracks`, you need to configure the source variables:

```yaml
vars:
  # Point to seed tables in main schema
  segment_schema: "main"
  segment_tracks_table: "segment_tracks"
  segment_pages_table: "segment_pages"
  segment_identifies_table: "segment_identifies"
  segment_users_table: "segment_users"
  segment_groups_table: "segment_groups"
```

Add these vars to your existing `dbt_project.yml` under the `vars:` section.

### 3. Load the Seed Data

Run the following command to load seed data into your DuckDB database:

```bash
dbt seed --target dev
```

This will create the following tables in the `main` schema:

- `main.segment_tracks`
- `main.segment_pages`
- `main.segment_identifies`
- `main.segment_users`
- `main.segment_groups`

### 4. Run the Models

After seeding and configuring the vars, run the dbt models:

```bash
# Run all models
dbt run --target dev

# Or run specific model layers
dbt run --target dev --select staging
dbt run --target dev --select marts.core
```

### 5. Test the Models

Run dbt tests to verify data quality:

```bash
dbt test --target dev
```

### 6. Query Your Data

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

For the seed data to work, you need to configure your `dbt_project.yml` with the following variables:

```yaml
vars:
  # REQUIRED: Point to seed tables
  segment_schema: "main"
  segment_tracks_table: "segment_tracks"
  segment_pages_table: "segment_pages"
  segment_identifies_table: "segment_identifies"
  segment_users_table: "segment_users"
  segment_groups_table: "segment_groups"

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
Table with name tracks does not exist" error

This means dbt is looking for tables in the wrong schema or with the wrong names. Make sure you've added the source configuration vars to your `dbt_project.yml`:

```yaml
vars:
  segment_schema: "main"
  segment_tracks_table: "segment_tracks"
  segment_pages_table: "segment_pages"
  segment_identifies_table: "segment_identifies"
  segment_users_table: "segment_users"
  segment_groups_table: "segment_groups"
```

### "

- **Development seeds** (this directory): For local development, unit testing, and exploring the models
- **Integration test seeds** (`integration_tests/`): For CI/CD and package testing

Both sets of seeds follow the same schema but may contain different data patterns or volumes.

## Troubleshooting

### "Relation not found" errors

Make sure seeds are loaded:

```bash
dbt seed --target dev --full-refresh
```

### Timestamp/date parsing errors

DuckDB should automatically parse the timestamp format `YYYY-MM-DD HH:MM:SS`. If you encounter issues, check that your DuckDB version is up to date.

### Schema not found

Ensure your `profiles.yml` specifies the correct schema:

```yaml
schema: segment_events # Must match source configuration
```

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
