# Troubleshooting Guide

Common issues and solutions for GrowthCues Core.

---

## Installation Issues

### "dbt command not found"

**Problem:** The `dbt` command is not recognized in your terminal.

**Solutions:**

1. **Verify installation:**

   ```bash
   python -m pip list | grep dbt
   ```

   If you don't see `dbt-core` and your adapter (`dbt-snowflake` or `dbt-bigquery`), reinstall:

   ```bash
   pip install dbt-snowflake  # or dbt-bigquery
   ```

2. **Check PATH:** Ensure Python's bin directory is in your PATH
   - **Mac/Linux:** Add to `~/.bashrc` or `~/.zshrc`:
     ```bash
     export PATH="$HOME/.local/bin:$PATH"
     ```
   - **Windows:** Python installer should add to PATH automatically; reinstall with "Add to PATH" checked

3. **Restart terminal:** Close and reopen your terminal after installation

---

## Connection Issues

### "Could not find profile named 'growthcues_core'"

**Problem:** dbt can't find your `profiles.yml` file or the profile is misconfigured.

**Solutions:**

1. **Check profiles.yml location:**
   - **Mac/Linux:** Should be at `~/.dbt/profiles.yml`
   - **Windows:** Should be at `C:\Users\YourUsername\.dbt\profiles.yml`

2. **Verify profile name:** Ensure your `profiles.yml` starts with `growthcues_core:` exactly (including the colon)

3. **Test connection:**
   ```bash
   dbt debug
   ```
   This will show exactly where dbt is looking for the profile file.

### "Database/Schema does not exist"

**Problem:** The database or schema you configured doesn't exist in your warehouse.

**Solutions:**

1. **Verify names in your data warehouse:**
   - **Snowflake:** Log in → Databases → Check exact names (case-sensitive!)
   - **BigQuery:** Console → Check project ID and dataset name

2. **Check configuration:** Review `dbt_project.yml` variables:

   ```yaml
   vars:
     segment_database: "EXACT_DATABASE_NAME" # Case-sensitive for Snowflake
     segment_schema: "exact_schema_name"
   ```

3. **Test with a simple query:**

   ```sql
   -- Snowflake
   SELECT * FROM YOUR_DATABASE.YOUR_SCHEMA.tracks LIMIT 1;

   -- BigQuery
   SELECT * FROM `your-project.your_dataset.tracks` LIMIT 1;
   ```

### "Insufficient privileges"

**Problem:** Your database user doesn't have the required permissions.

**Solutions:**

**For Snowflake:**

```sql
-- Your user needs these permissions
GRANT USAGE ON DATABASE YOUR_RAW_DATABASE TO ROLE YOUR_ROLE;
GRANT USAGE ON SCHEMA YOUR_RAW_DATABASE.YOUR_SCHEMA TO ROLE YOUR_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA YOUR_RAW_DATABASE.YOUR_SCHEMA TO ROLE YOUR_ROLE;

-- For the target schema where models are created
GRANT CREATE TABLE ON SCHEMA YOUR_TARGET_SCHEMA TO ROLE YOUR_ROLE;
GRANT CREATE VIEW ON SCHEMA YOUR_TARGET_SCHEMA TO ROLE YOUR_ROLE;
```

**For BigQuery:**

Your service account needs these roles:

- `BigQuery Data Editor`
- `BigQuery Job User`

Grant them in Google Cloud Console → IAM & Admin → IAM.

---

## Data Issues

### "No tracks/users/groups table found"

**Problem:** dbt can't find the Segment/Rudderstack tables.

**Solutions:**

1. **Verify Segment is loading data:**
   - Check your Segment dashboard for successful syncs
   - Query the raw table directly to confirm data exists

2. **Check table names:** Your tables might have different names:

   ```yaml
   vars:
     segment_tracks_table: "your_actual_tracks_table_name"
     segment_pages_table: "your_actual_pages_table_name"
     # etc.
   ```

3. **Check schema/database:** Ensure `segment_database` and `segment_schema` point to the correct location

### "Missing context_group_id or account_id is always null"

**Problem:** Events don't have account context, so all account-level metrics are null.

**Root causes:**

1. **Not using Segment B2B SaaS spec:** Your tracking doesn't include group context
2. **Wrong field name:** Your implementation uses a different field

**Solutions:**

1. **Verify your tracking implementation:**

   ```javascript
   // Segment B2B SaaS spec example
   analytics.track(
     "Button Clicked",
     {
       // event properties
     },
     {
       groupId: "account_123", // This becomes context_group_id
     },
   );
   ```

2. **Check if field exists:**

   ```sql
   SELECT context_group_id FROM your_database.your_schema.tracks LIMIT 10;
   ```

3. **Use a different field name:**

   ```yaml
   vars:
     group_id_field: "group_id" # Or whatever field you use
   ```

4. **If you don't have account context:** You'll need to update your tracking implementation to include group context in events

### "Models are running but producing no data"

**Problem:** Models compile and run successfully but tables are empty.

**Solutions:**

1. **Check source data:**

   ```sql
   -- Verify you have data in your source tables
   SELECT COUNT(*) FROM your_database.your_schema.tracks;
   SELECT MIN(timestamp), MAX(timestamp) FROM your_database.your_schema.tracks;
   ```

2. **Check lookback windows:** Your data might be older than the default lookback:

   ```yaml
   vars:
     tracks_lookback_days: 730 # Increase if your data is older
     identity_lookback_days: 730
   ```

3. **Check for filters:** Review the model SQL for any WHERE clauses that might be excluding all data

4. **Run in debug mode:**
   ```bash
   dbt run --models stg_segment_tracks --debug
   ```
   Check the compiled SQL to see what's actually being executed.

---

## Identity Stitching Issues

### "No events are being stitched"

**Problem:** All events remain anonymous even though identity stitching is enabled.

**Solutions:**

1. **Verify identity resolution table has data:**

   ```sql
   SELECT COUNT(*) FROM your_schema.stg_identity_resolution;
   ```

   If this returns 0, you have no identify events.

2. **Check identifies table:**

   ```sql
   SELECT
     anonymous_id,
     user_id,
     timestamp
   FROM your_database.your_schema.identifies
   WHERE user_id IS NOT NULL
   LIMIT 10;
   ```

   If this is empty, your tracking isn't sending identify calls.

3. **Verify field names:**

   ```yaml
   vars:
     identity_anonymous_id_field: "anonymous_id" # Check this matches your field
   ```

4. **Check if identify() is called in your tracking:**
   ```javascript
   // You need this call when users sign up/log in
   analytics.identify(
     userId,
     {
       // user traits
     },
     {
       anonymousId: anonymousId, // Links anonymous to authenticated
     },
   );
   ```

### "Too many anonymous events remain unstitched"

**Problem:** Most events are still anonymous even with identity stitching enabled.

**Possible causes:**

1. Users never call `identify()` after signup
2. Your tracking doesn't pass `anonymous_id` consistently
3. Lookback window is too short

**Solutions:**

1. **Increase lookback window:**

   ```yaml
   vars:
     identity_lookback_days: 730 # Default: 365
   ```

2. **Review tracking implementation:**
   - Ensure `identify()` is called after signup/login
   - Verify `anonymous_id` is captured before and after authentication

3. **Check identity mapping coverage:**
   ```sql
   -- How many tracks have been stitched?
   SELECT
     COUNT(*) as total_tracks,
     COUNT(DISTINCT user_id) as tracks_with_user_id,
     COUNT(DISTINCT anonymous_id) as tracks_with_anonymous_id
   FROM your_schema.stg_segment_tracks;
   ```

---

## Session Issues

### "Session counts are too high"

**Problem:** More sessions than expected.

**Possible causes:**

1. Session timeout is too short
2. Page views are creating many short sessions

**Solutions:**

1. **Increase session timeout:**

   ```yaml
   vars:
     session_timeout_minutes: 60 # Default: 30
   ```

2. **Exclude page views:**

   ```yaml
   vars:
     include_pages_in_sessions: false # Default: true
   ```

3. **After changing, refresh:**
   ```bash
   dbt run --full-refresh --models fct_sessions
   ```

### "Session counts are too low"

**Problem:** Fewer sessions than expected.

**Possible causes:**

1. Session timeout is too long
2. Events aren't being captured properly

**Solutions:**

1. **Decrease session timeout:**

   ```yaml
   vars:
     session_timeout_minutes: 15 # Default: 30
   ```

2. **Verify event tracking:**
   ```sql
   SELECT
     DATE(event_at) as date,
     COUNT(*) as event_count
   FROM your_schema.stg_segment_tracks
   GROUP BY 1
   ORDER BY 1 DESC
   LIMIT 30;
   ```

### "Session durations are unexpectedly long"

**Problem:** Average session duration is unrealistically high.

**Possible causes:**

1. Users leaving browser tabs open (creating artificially long sessions)
2. Session timeout is too high

**Solutions:**

1. **Decrease session timeout:**

   ```yaml
   vars:
     session_timeout_minutes: 30 # or lower
   ```

2. **Consider excluding page views:**
   ```yaml
   vars:
     include_pages_in_sessions: false
   ```

---

## Performance Issues

### "Models are taking too long to run"

**Problem:** dbt runs are slow or timing out.

**Solutions:**

1. **Use incremental runs (not full-refresh):**

   ```bash
   dbt run  # Incremental (fast)
   # vs
   dbt run --full-refresh  # Full (slow - only use when needed)
   ```

2. **Reduce lookback windows:**

   ```yaml
   vars:
     tracks_lookback_days: 180 # Default: 365
     identity_lookback_days: 180 # Default: 365
   ```

3. **Increase warehouse size:**
   - **Snowflake:** Increase warehouse size (XS → S → M → L)
   - **BigQuery:** No sizing needed, but check for slot contention

4. **Check for specific slow models:**

   ```bash
   dbt run --models fct_sessions --debug
   ```

   Look for the model execution time in the logs.

5. **Optimize specific models:**
   - Add clustering keys (Snowflake) or partitioning (BigQuery) on high-volume tables
   - Consider materializing staging models as tables instead of views

### "Out of memory errors"

**Problem:** Warehouse runs out of memory during execution.

**Solutions:**

1. **Increase warehouse size:**
   - **Snowflake:** Use a larger warehouse (M or L)
   - **BigQuery:** Check if you're hitting slot limits

2. **Reduce data volume:**

   ```yaml
   vars:
     tracks_lookback_days: 90 # Process less history
   ```

3. **Run models in stages:**
   ```bash
   dbt run --models staging  # First
   dbt run --models marts    # Then
   ```

---

## Build Errors

### "Compilation Error: Could not find model/macro"

**Problem:** dbt can't find a referenced model or macro.

**Solutions:**

1. **Install dependencies:**

   ```bash
   dbt deps
   ```

2. **Verify packages.yml:** If using as a package, ensure it's listed:

   ```yaml
   packages:
     - package: growthcues/growthcues_core
       version: 1.0.0
   ```

3. **Clear compiled artifacts:**
   ```bash
   dbt clean
   dbt deps
   dbt compile
   ```

### "Relation does not exist"

**Problem:** dbt is looking for a table that doesn't exist yet.

**Solutions:**

1. **Run in correct order:**

   ```bash
   dbt run --models staging  # Build staging first
   dbt run --models marts    # Then marts
   ```

2. **Check model dependencies:** Verify the model's `ref()` calls are correct

3. **Full refresh:**
   ```bash
   dbt run --full-refresh
   ```

---

## Test Failures

### "Tests are failing after initial setup"

**Problem:** Data quality tests are failing on your actual data.

**This is expected!** The tests are designed to catch data quality issues. Common failures:

1. **Null account_ids:** Normal if you have anonymous traffic
2. **Duplicate keys:** Indicates data quality issues in source data
3. **Referential integrity:** Missing records in dimension tables

**Solutions:**

1. **Review the specific test failure:**

   ```bash
   dbt test --select fct_account_metrics_daily
   ```

2. **Fix source data issues** if tests reveal actual data problems

3. **Adjust tests** if your business logic differs from assumptions

---

## Getting More Help

If you're still stuck:

1. **Check logs:** Run with `--debug` to see detailed output:

   ```bash
   dbt run --models your_model --debug
   ```

2. **Review compiled SQL:** Check `target/compiled/` to see exact SQL being executed

3. **Open a GitHub issue:** [github.com/growthcues/growthcues-core/issues](https://github.com/growthcues/growthcues-core/issues)
   - Include: dbt version, warehouse type, error messages, relevant configuration
   - **Do not include:** credentials, actual company data

4. **Check documentation:**
   - [Installation Guide](INSTALLATION.md)
   - [Configuration Guide](CONFIGURATION.md)
   - [Identity Stitching Guide](IDENTITY_STITCHING.md)
   - [Sessionization Guide](SESSIONIZATION.md)
   - [FAQ](FAQ.md)
