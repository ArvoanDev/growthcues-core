# Configuration Guide

Complete reference for configuring GrowthCues Core.

## Overview

GrowthCues Core is configured through variables in your `dbt_project.yml` file. All configurations are optional and come with sensible defaults.

---

## Data Source Configuration

### Required Variables

```yaml
vars:
  segment_database: "YOUR_DATABASE" # Database/project containing Segment data
  segment_schema: "YOUR_SCHEMA" # Schema/dataset containing Segment tables
```

### Optional Table Name Overrides

If your Segment tables have different names, override them:

```yaml
vars:
  segment_tracks_table: "tracks" # Default: "tracks"
  segment_pages_table: "pages" # Default: "pages"
  segment_identifies_table: "identifies" # Default: "identifies"
  segment_users_table: "users" # Default: "users"
  segment_groups_table: "groups" # Default: "groups"
```

---

## Session Configuration

### Session Timeout

Control how sessions are defined based on inactivity:

```yaml
vars:
  session_timeout_minutes: 30 # Default: 30 minutes
```

**What this controls:**

- Two events by the same user are considered part of the same session if they occur within this time window
- When running incrementally, the model looks back this many minutes from the last session end to catch sessions that might still be active

**Common values:**

- **30 minutes** (default): Standard for most web applications
- **60 minutes**: For products with longer, more contemplative workflows (design tools, research platforms)
- **15 minutes**: For high-frequency, task-based applications (chat tools, quick lookups)

**After changing:** Run `dbt run --full-refresh --models fct_sessions` to recalculate all sessions.

### Page View Inclusion

Control whether page views are included in session calculations:

```yaml
vars:
  include_pages_in_sessions: true # Default: true
```

**Options:**

- **`true` (default)**: Both tracked events AND page views count toward sessions. Page views contribute to session duration and help define session boundaries.
  - **Use case:** Content-heavy products where browsing is meaningful engagement
- **`false`**: Only explicit tracked events count in sessions. Page views are excluded.
  - **Use case:** Pure SaaS products where page views are navigation noise and only feature usage matters

**After changing:** Run `dbt run --full-refresh --models fct_sessions` to recalculate all sessions.

---

## Identity Stitching Configuration

Identity stitching links anonymous visitor activity to authenticated users. See [Identity Stitching Guide](IDENTITY_STITCHING.md) for detailed explanation.

### Enable/Disable Identity Stitching

```yaml
vars:
  enable_identity_stitching: true # Default: true
```

**When to disable (`false`):**

- Your product always requires authentication (no anonymous users)
- You want to simplify the pipeline and skip identity resolution logic
- **Performance benefit:** Eliminates identity stitching overhead and JOIN operations

**When disabled:**

- Skips `stg_identity_resolution` and `stg_user_account_mapping` models
- Removes JOINs from `stg_segment_tracks`
- All tracks pass through with their original `user_id` and `account_id` values

### Anonymous ID Field

Customize the field name used for anonymous identifiers:

```yaml
vars:
  identity_anonymous_id_field: "anonymous_id" # Default: "anonymous_id"
```

**Common alternatives:**

- `visitor_id`
- `device_id`
- `client_id`
- Any custom field your tracking implementation uses

**After changing:** Run `dbt run --full-refresh` to reprocess with the new field.

### Identity Lookback Window

Control how far back to look for identity mappings:

```yaml
vars:
  identity_lookback_days: 365 # Default: 365 days
```

**When to adjust:**

- **Increase (730+ days):** If you have long sales cycles and need historical mappings
- **Decrease (90-180 days):** For performance optimization if your sales cycle is short

**Why this matters:** Limits stale identity mappings (e.g., shared devices, recycled IDs).

**After changing:** Run `dbt run --full-refresh` to reprocess with the new lookback.

---

## Data Processing Configuration

### Tracks Lookback Window

Control how far back to process event data:

```yaml
vars:
  tracks_lookback_days: 365 # Default: 365 days
```

**When to adjust:**

- **Decrease (90-180 days):** To limit data processing volume and improve query performance
- **Increase (730+ days):** If you need long-term historical analysis

**Performance impact:**

- Directly controls data volume in staging models
- Lower values = faster queries, less warehouse compute
- Higher values = more complete historical data

**After changing:** Run `dbt run --full-refresh` to reprocess with the new lookback.

---

## Account ID Field Configuration

Customize the field used for account identification:

```yaml
vars:
  group_id_field: "context_group_id" # Default: "context_group_id"
```

**When to customize:**

- Your Segment implementation uses a different field for account IDs
- You're using a CDP other than Segment/Rudderstack with different naming conventions

**Common alternatives:**

- `account_id`
- `group_id`
- `organization_id`
- `company_id`

**After changing:** Run `dbt run --full-refresh` to reprocess with the new field.

---

## Package-Specific Configuration

If installing as a package (Method 1), namespace your variables under `growthcues_core`:

```yaml
vars:
  growthcues_core:
    segment_database: "ANALYTICS"
    segment_schema: "segment_production"
    session_timeout_minutes: 30
    enable_identity_stitching: true
    # ... all other variables
```

If using the template/clone method (Method 2), omit the namespace:

```yaml
vars:
  segment_database: "ANALYTICS"
  segment_schema: "segment_production"
  session_timeout_minutes: 30
  enable_identity_stitching: true
  # ... all other variables
```

---

## Complete Configuration Example

### For Package Installation (Method 1)

```yaml
# dbt_project.yml
vars:
  growthcues_core:
    # Required: Data source location
    segment_database: "ANALYTICS"
    segment_schema: "segment_production"

    # Optional: Table name overrides (if needed)
    # segment_tracks_table: "tracks"
    # segment_pages_table: "pages"
    # segment_identifies_table: "identifies"
    # segment_users_table: "users"
    # segment_groups_table: "groups"

    # Optional: Session configuration
    session_timeout_minutes: 30
    include_pages_in_sessions: true

    # Optional: Identity stitching
    enable_identity_stitching: true
    identity_anonymous_id_field: "anonymous_id"
    identity_lookback_days: 365

    # Optional: Data processing
    tracks_lookback_days: 365

    # Optional: Account ID field
    # group_id_field: "context_group_id"
```

### For Template Installation (Method 2)

```yaml
# dbt_project.yml
vars:
  # Required: Data source location
  segment_database: "RAW_DATA"
  segment_schema: "SEGMENT_PRODUCTION"

  # Optional: Table name overrides (if needed)
  # segment_tracks_table: "tracks"
  # segment_pages_table: "pages"
  # segment_identifies_table: "identifies"
  # segment_users_table: "users"
  # segment_groups_table: "groups"

  # Optional: Session configuration
  session_timeout_minutes: 30
  include_pages_in_sessions: true

  # Optional: Identity stitching
  enable_identity_stitching: true
  identity_anonymous_id_field: "anonymous_id"
  identity_lookback_days: 365

  # Optional: Data processing
  tracks_lookback_days: 365

  # Optional: Account ID field
  # group_id_field: "context_group_id"
```

---

## Performance Tuning

### For Large Event Volumes (10M+ events)

```yaml
vars:
  tracks_lookback_days: 180 # Reduce historical data volume
  identity_lookback_days: 180 # Reduce identity mapping volume
  session_timeout_minutes: 30 # Keep default
  enable_identity_stitching: true # Keep enabled unless not needed
```

### For Products with No Anonymous Users

```yaml
vars:
  enable_identity_stitching: false # Disable entirely for performance
  tracks_lookback_days: 365 # Can keep higher since no stitching overhead
```

### For Products with Long, Contemplative Workflows

```yaml
vars:
  session_timeout_minutes: 60 # Increase timeout for longer sessions
  include_pages_in_sessions: true # Include page views for content engagement
```

### For High-Frequency, Task-Based Products

```yaml
vars:
  session_timeout_minutes: 15 # Decrease timeout for quick interactions
  include_pages_in_sessions: false # Exclude navigation noise
```

---

## Applying Configuration Changes

Most configuration changes require a full refresh:

```bash
# Full refresh (recalculates all historical data)
dbt run --full-refresh

# Full refresh for specific models only
dbt run --full-refresh --models fct_sessions
dbt run --full-refresh --models staging
```

**Exception:** Data source location changes (database/schema/table names) can use regular incremental runs:

```bash
dbt run
```

---

## Validation

After changing configuration, validate your setup:

```bash
# Test connection and configuration
dbt debug

# Compile models to check for errors
dbt compile

# Run models
dbt run

# Run tests to validate data quality
dbt test
```

---

## Next Steps

- **Understand identity stitching:** See [Identity Stitching Guide](IDENTITY_STITCHING.md)
- **Understand sessionization:** See [Sessionization Guide](SESSIONIZATION.md)
- **Review metrics:** Check [METRICS.md](../METRICS.md)
- **Having issues?** See [Troubleshooting](TROUBLESHOOTING.md)
