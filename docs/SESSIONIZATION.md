# Sessionization Guide

Complete guide to understanding and configuring sessionization in GrowthCues Core.

## Overview

The `fct_sessions` table uses a sophisticated algorithm to group raw events into meaningful user sessions. Understanding this logic helps you interpret session metrics correctly and customize the timeout if needed.

---

## What is a Session?

A **session** is a continuous sequence of events by the same user with no more than **30 minutes** (configurable) of inactivity between events.

**Note:** By default, sessions include both **tracked events** (from `stg_segment_tracks`) and **page views** (from `stg_segment_pages`). This can be controlled via the `include_pages_in_sessions` variable.

### Examples

- User logs in at 9:00 AM, clicks 10 buttons, views 5 pages, logs out at 9:45 AM → **1 session** (45 minutes duration, 15 total interactions)
- User active at 2:00 PM, then inactive until 3:00 PM → **2 sessions** (60-minute gap exceeds timeout)
- User makes 1 click at 4:00 PM, no other activity → **1 session** (0 minutes duration, 1 event)

---

## The Algorithm

The sessionization logic uses a **three-step window function approach**:

### Step 1: Detect Session Boundaries

For each event, we look at the **previous event** by the same user and calculate the time gap:

```sql
-- If gap > 30 minutes → new session (flag = 1)
-- If gap ≤ 30 minutes → same session (flag = 0)
CASE
  WHEN DATEDIFF('minute', previous_event, current_event) > 30
  THEN 1
  ELSE 0
END AS is_new_session_flag
```

Uses `LAG()` window function to access the previous event timestamp.

### Step 2: Create Session Groups

We take those binary flags (0, 0, 1, 0, 1, 1, ...) and calculate a **cumulative sum**:

```sql
SUM(is_new_session_flag) OVER (
  PARTITION BY user_id
  ORDER BY event_timestamp
) AS user_session_index
```

**Result:** Each session gets a unique index number (0, 1, 2, 3, ...) per user.

**Example:**

| Event Time | Flag | Cumulative Sum (Session Index) |
| ---------- | ---- | ------------------------------ |
| 9:00 AM    | 0    | 0                              |
| 9:10 AM    | 0    | 0                              |
| 9:50 AM    | 1    | 1 (new session started)        |
| 10:00 AM   | 0    | 1                              |
| 11:00 AM   | 1    | 2 (new session started)        |

### Step 3: Aggregate to Session Level

Finally, we group all events by `(user_id, user_session_index)` and calculate:

- **Session Start:** `MIN(event_timestamp)`
- **Session End:** `MAX(event_timestamp)`
- **Duration:** Time difference between start and end
- **Events in Session:** `COUNT(*)`
- **Account ID:** Taken from the **first event** chronologically in the session

---

## Account Attribution Logic

When users switch accounts mid-session (rare but possible), we attribute the session to the **account where the session started**:

```sql
-- Use ROW_NUMBER to identify the first event
ROW_NUMBER() OVER (
  PARTITION BY user_id, user_session_index
  ORDER BY event_timestamp
) AS event_rank_in_session

-- Then extract account_id from that first event
MAX(CASE WHEN event_rank_in_session = 1 THEN account_id END) AS account_id
```

This ensures sessions are cleanly attributed to a single account for aggregation.

---

## Incremental Processing

To optimize warehouse costs, the model uses **incremental materialization**:

```sql
-- On incremental runs, only process NEW events
-- But look back 30 minutes to catch sessions still in progress
WHERE event_at >= (last_session_end - 30 minutes)
```

**Why the lookback?**

Without it, a session spanning multiple incremental runs would be split into separate sessions. The lookback ensures we recalculate any session that might still be active.

**Trade-off:** Small amount of duplicate work (last 30 minutes) to ensure correctness.

---

## Configuration

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

- **`true` (default)**: Both tracked events AND page views count toward sessions
  - Page views contribute to session duration and help define session boundaries
  - **Use case:** Content-heavy products where browsing is meaningful engagement
- **`false`**: Only explicit tracked events count in sessions (page views excluded)
  - **Use case:** Pure SaaS products where page views are navigation noise and only feature usage matters

**After changing:** Run `dbt run --full-refresh --models fct_sessions` to recalculate all sessions.

---

## Cross-Database Compatibility

The logic uses dbt's cross-database macros to work on both BigQuery and Snowflake:

- `dbt.datediff()` instead of `TIMESTAMP_DIFF` or `DATEDIFF`
- `dbt.dateadd()` instead of `TIMESTAMP_ADD` or `DATEADD`
- `dbt_utils.generate_surrogate_key()` for session ID generation

This ensures the same SQL compiles correctly on both platforms.

---

## Performance Considerations

Sessionization uses window functions (`LAG()`, `ROW_NUMBER()`, `SUM() OVER()`), which are compute-intensive.

### Why It's Expensive

- Window functions must process all events per user in order
- Cannot be easily parallelized within a user's event stream
- Performance scales with total event volume and number of unique users

### Incremental Strategy

- `fct_sessions` uses **incremental materialization** to minimize reprocessing
- Initial `dbt run --full-refresh` processes all historical data
- Subsequent `dbt run` only processes new events + a lookback window (default: `session_timeout_minutes`)
- The lookback ensures sessions spanning multiple runs aren't split incorrectly

### Optimization Strategies

1. **Use incremental runs for production:** Avoid `--full-refresh` unless changing `session_timeout_minutes`
2. **Reduce input volume:** Decrease `tracks_lookback_days` in staging to limit historical data
3. **Warehouse sizing:** Test with your actual data volume to determine appropriate warehouse size
4. **Clustering/Partitioning:** Consider adding clustering on `user_id` (Snowflake) or partitioning by date (BigQuery) for very large datasets

### Monitoring

- Run `dbt run --models fct_sessions` and check the logs for execution time
- Compare incremental vs full-refresh timing to validate your incremental strategy is working
- If builds are slower than expected, review the dbt docs on incremental model optimization for your warehouse

### Typical Performance

**Build times on medium warehouse:**

- 1M events: ~30-60 seconds (incremental)
- 10M events: ~3-5 minutes (incremental)
- 100M+ events: Consider decreasing `tracks_lookback_days` to 90-180 days

**Full refresh timing:**

- ~3-5x slower than incremental runs
- Only run when changing `session_timeout_minutes` or for debugging

---

## Session Metrics

The `fct_sessions` table provides the following metrics:

| Column                     | Definition                                               |
| :------------------------- | :------------------------------------------------------- |
| `session_id`               | Unique identifier for the session                        |
| `user_id`                  | User who performed the session                           |
| `account_id`               | Account attributed to the session (from first event)     |
| `session_start_at`         | Timestamp of the first event in the session              |
| `session_end_at`           | Timestamp of the last event in the session               |
| `session_duration_minutes` | Duration of the session (end - start) in minutes         |
| `events_in_session`        | Count of events during the session                       |
| `session_date`             | Date of the session start (for partitioning/aggregation) |

---

## Using Session Data

### Account-Level Session Metrics

Session data rolls up into `fct_account_metrics_daily`:

- **Sessions per day/7d/30d:** Total session count in each time window
- **Total time on platform (7d/30d):** Sum of all session durations
- **Average daily sessions/time:** Mean session count and duration per active day

### User-Level Session Metrics

Session data rolls up into `fct_user_metrics_daily`:

- **Sessions today/L30:** Session count on snapshot date and in last 30 days
- **Avg session duration:** Mean duration across all sessions
- **Events per session:** Mean event count per session

---

## Troubleshooting

### Problem: Session counts are too high

**Possible causes:**

1. Session timeout is too short (e.g., 15 minutes when users take longer breaks)
2. Page views are included and creating many short sessions

**Solutions:**

- Increase `session_timeout_minutes` in configuration
- Set `include_pages_in_sessions: false` to exclude page views

### Problem: Session counts are too low

**Possible causes:**

1. Session timeout is too long (e.g., 60 minutes for a high-frequency product)
2. Events aren't being captured properly

**Solutions:**

- Decrease `session_timeout_minutes` in configuration
- Verify event tracking implementation

### Problem: Session durations are unexpectedly long

**Possible causes:**

1. Users are leaving browser tabs open (creating artificially long sessions)
2. Session timeout is too high

**Solutions:**

- Decrease `session_timeout_minutes` to better reflect actual engagement
- Consider excluding page views if they're causing duration inflation

### Problem: Incremental runs are creating duplicate sessions

**Possible causes:**

1. The incremental lookback isn't working correctly
2. Session IDs are changing between runs

**Solutions:**

- Run `dbt run --full-refresh --models fct_sessions` to reset
- Check that `session_timeout_minutes` hasn't changed between runs
- Verify the incremental logic in the model SQL

---

## Next Steps

- **Configure sessionization:** See [Configuration Guide](CONFIGURATION.md)
- **Understand identity stitching:** See [Identity Stitching Guide](IDENTITY_STITCHING.md)
- **Review metrics:** Check [METRICS.md](../METRICS.md)
- **Having issues?** See [Troubleshooting](TROUBLESHOOTING.md)
