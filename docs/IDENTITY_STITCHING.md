# Identity Stitching Guide

Complete guide to understanding and configuring identity stitching in GrowthCues Core.

## Overview

Identity stitching is the process of linking anonymous visitor activity to known user identities. This is critical for B2B SaaS because it allows you to attribute pre-signup behavior (product exploration, free tier usage) to the accounts that eventually convert.

---

## What is Identity Stitching?

**Identity stitching** connects anonymous visitor IDs (e.g., `anonymous_id`, `visitor_id`, `device_id`) to authenticated user IDs (e.g., `user_id`, `email`) so that all of a user's activity—both before and after they identify themselves—can be attributed to a single identity.

### Common Scenarios

- **Anonymous browsing → Signup:** Visitor browses your marketing site anonymously, then creates an account → Their browsing events get mapped to their `user_id`
- **Multi-device usage:** User browses on mobile (anonymous), then logs in on desktop → Mobile activity gets linked to their authenticated identity
- **Freemium conversion:** User explores your product as anonymous/trial user, then upgrades → Pre-conversion behavior helps predict future conversions

---

## Why This Matters for B2B SaaS

### Without Identity Stitching

- ❌ You lose visibility into the pre-signup journey
- ❌ Product analytics show artificially low engagement (missing anonymous events)
- ❌ Attribution is broken (can't connect early interest signals to converted accounts)

### With Identity Stitching

- ✅ Complete customer journey from first touch to conversion
- ✅ Accurate product engagement metrics including trial/free tier activity
- ✅ Better predictive models (more complete behavioral history)
- ✅ Attribute anonymous events to B2B accounts for account-level metrics

---

## The Algorithm

Identity stitching uses a **three-table approach**:

### Step 1: Build Identity Graph

The `stg_identity_resolution` model creates a mapping table by analyzing Segment/Rudderstack's `identifies` events:

```sql
-- Extract all anonymous_id → user_id links from identify calls
SELECT
    anonymous_id,
    user_id,
    timestamp
FROM segment.identifies
WHERE user_id IS NOT NULL
    AND timestamp >= (CURRENT_TIMESTAMP - 365 days) -- Configurable lookback
```

**Why the timestamp filter?**

Identity mappings can become stale (e.g., shared devices, recycled IDs). The lookback window (default: 365 days) ensures we only use recent mappings.

### Step 2: Resolve to Master Identity

When a single `anonymous_id` has multiple `user_id` values (e.g., multiple people shared a device), we use **last-touch attribution**—the most recent identity wins:

```sql
-- Take the MOST RECENT user_id for each anonymous_id
SELECT
    anonymous_id,
    user_id as master_user_id
FROM (
    SELECT
        anonymous_id,
        user_id,
        ROW_NUMBER() OVER (
            PARTITION BY anonymous_id
            ORDER BY timestamp DESC
        ) AS rn
    FROM identifies
)
WHERE rn = 1
```

**Result:** A clean mapping table: `anonymous_id → master_user_id`

### Step 3: Stitch Events

The `stg_segment_tracks` model joins events with the identity graph to backfill missing `user_id` values:

```sql
-- Prefer explicit user_id, fall back to stitched identity
SELECT
    event_id,
    COALESCE(tracks.user_id, identity_map.master_user_id) AS user_id,
    account_id,
    event_name,
    event_at
FROM tracks
LEFT JOIN stg_identity_resolution AS identity_map
    ON tracks.anonymous_id = identity_map.anonymous_id
```

**Logic:**

- If event already has `user_id` → keep it (user was authenticated)
- If event only has `anonymous_id` → lookup `master_user_id` from identity graph
- If no mapping exists → event remains anonymous

---

## Account Backfilling Logic

A more subtle problem: **anonymous events don't have account context**.

Even after mapping `anonymous_id → user_id`, those events still lack the `account_id` (B2B context). We solve this by creating a second mapping table (`stg_user_account_mapping`) that tracks each user's most recent account:

```sql
-- Find the latest account_id for each user_id
SELECT
    user_id,
    account_id
FROM (
    SELECT
        user_id,
        account_id,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY event_timestamp DESC
        ) AS rn
    FROM tracks
    WHERE user_id IS NOT NULL AND account_id IS NOT NULL
)
WHERE rn = 1
```

Then in `stg_segment_tracks`, we perform a **two-level join**:

```sql
-- 1. Stitch user_id from anonymous_id
-- 2. Backfill account_id from stitched user_id
SELECT
    COALESCE(tracks.user_id, identity_map.master_user_id) AS user_id,
    COALESCE(tracks.account_id, user_account_map.latest_account_id) AS account_id,
    ...
FROM tracks
LEFT JOIN identity_map ON tracks.anonymous_id = identity_map.anonymous_id
LEFT JOIN user_account_map ON COALESCE(tracks.user_id, identity_map.master_user_id) = user_account_map.user_id
```

**Result:** Anonymous events now have both `user_id` AND `account_id`, making them fully attributable to B2B accounts.

---

## Configuration

### Enable/Disable Identity Stitching

```yaml
vars:
  enable_identity_stitching: true # Default: true
```

**When to disable (`false`):**

- Your product always requires authentication (no anonymous users)
- You want to simplify the pipeline and skip identity resolution logic

**When disabled:**

- Skips `stg_identity_resolution` and `stg_user_account_mapping` models
- Removes JOINs from `stg_segment_tracks`
- All tracks pass through with their original `user_id` and `account_id` values
- **Performance benefit:** Eliminates ~20-30% of staging layer compute time

### Customize Anonymous ID Field

```yaml
vars:
  identity_anonymous_id_field: "anonymous_id" # Default: "anonymous_id"
```

**Common alternatives:**

- `visitor_id`
- `device_id`
- `client_id`

**After changing:** Run `dbt run --full-refresh` to reprocess.

### Adjust Lookback Windows

```yaml
vars:
  identity_lookback_days: 365 # Default: 365 days
  tracks_lookback_days: 365 # Default: 365 days
```

**When to adjust:**

- **Increase (730+ days):** If you have long sales cycles and need historical mappings
- **Decrease (90-180 days):** For performance optimization if your sales cycle is short

**After changing:** Run `dbt run --full-refresh` to reprocess.

---

## What If Users Never Have Anonymous Events?

The identity stitching is **completely optional** and graceful:

- **Users who always authenticate:** Their events already have `user_id` → no stitching needed, events pass through unchanged
- **Users who are always anonymous:** No identify events exist → they remain anonymous, no data corruption
- **Users with mixed behavior:** Anonymous events get stitched to their authenticated identity → complete journey visibility

The `COALESCE()` logic ensures that explicit identities always take precedence over stitched ones.

---

## Data Lineage

Understanding the flow helps with debugging:

```
Raw Data:
  segment.identifies  →  stg_identity_resolution (anonymous_id → master_user_id)
  segment.tracks      →  stg_user_account_mapping (user_id → latest_account_id)
                      ↓
                   stg_segment_tracks (fully stitched events)
                      ↓
            fct_sessions, dim_users, fct_account_metrics_daily, etc.
```

All downstream models depend on the stitched events from `stg_segment_tracks`, so identity resolution happens at the foundation of the data pipeline.

---

## Performance Considerations

Identity stitching adds two LEFT JOINs to the tracks staging model, which can impact query performance.

### Query Performance

- Each tracks query joins with `stg_identity_resolution` (small lookup table) and `stg_user_account_mapping` (user-level aggregation)
- For large event volumes (millions of rows), these joins are the primary performance factor
- **Recommended:** Materialize `stg_identity_resolution` and `stg_user_account_mapping` as **tables** (already configured by default)
- **Optimization:** The lookback windows (`identity_lookback_days`, `tracks_lookback_days`) directly control data volume—decrease them if performance is a concern

### Build Time

- Initial `dbt run` processes all historical data within the lookback window
- Subsequent incremental runs are much faster

**Typical timing:**

- 1M events: ~30-60 seconds on medium warehouse
- 10M events: ~3-5 minutes on medium warehouse
- 100M+ events: Consider decreasing `tracks_lookback_days` to 90-180 days

### Warehouse Costs

- Identity stitching adds ~20-30% to staging layer compute time compared to no stitching
- This is a one-time cost at the staging layer—downstream models benefit from clean, stitched data
- **Cost optimization:** Use incremental runs (`dbt run`) instead of full refreshes for production

### When to Disable

If your product always requires authentication (no anonymous usage), you can skip identity stitching entirely:

```yaml
vars:
  enable_identity_stitching: false
```

All tracks will pass through with their original `user_id` and `account_id` values.

---

## Cross-Database Compatibility

The identity stitching logic uses dbt's cross-database macros to work on both BigQuery and Snowflake:

- `dbt.dateadd()` instead of `TIMESTAMP_ADD` or `DATEADD`
- `dbt.current_timestamp()` instead of `CURRENT_TIMESTAMP()` or `CURRENT_TIMESTAMP`
- Standard SQL window functions (supported by both platforms)

This ensures the same SQL compiles correctly on both data warehouses.

---

## Troubleshooting

### Problem: No events are being stitched

**Check:**

1. Are there identify events in your `identifies` table?
2. Do identify events have both `anonymous_id` and `user_id`?
3. Is your `identity_anonymous_id_field` configured correctly?

**Debug query:**

```sql
-- Check identity mappings
SELECT COUNT(*) FROM stg_identity_resolution;

-- Should show rows if stitching is working
```

### Problem: Too many anonymous events remain unstitched

**Possible causes:**

1. Users never call `identify()` after signup
2. Your tracking implementation doesn't pass `anonymous_id` consistently
3. The lookback window is too short (identity mappings are older than `identity_lookback_days`)

**Solutions:**

- Increase `identity_lookback_days` in configuration
- Review your tracking implementation to ensure `identify()` calls are made
- Check that `anonymous_id` is captured and passed through your tracking

### Problem: Events have wrong account_id after stitching

**Possible causes:**

1. User switched accounts and the most recent account isn't correct
2. Account mapping is using stale data

**Solutions:**

- Review the `stg_user_account_mapping` logic—it uses the most recent account by `event_timestamp`
- Consider whether your business logic requires different account attribution (e.g., first account vs. last account)

---

## Next Steps

- **Configure identity stitching:** See [Configuration Guide](CONFIGURATION.md)
- **Understand sessionization:** See [Sessionization Guide](SESSIONIZATION.md)
- **Review metrics:** Check [METRICS.md](../METRICS.md)
- **Having issues?** See [Troubleshooting](TROUBLESHOOTING.md)
