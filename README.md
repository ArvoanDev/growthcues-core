# GrowthCues Core

**The Open Source Semantic Layer for B2B SaaS.**

A dbt project to calculate **Account-Level** and **Product-Level** metrics from Segment/Rudderstack data using the **Segment B2B SaaS spec**. Includes AI-ready schema context for LLMs, agentic analytics, and self-serve GTM insights.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![dbt](https://img.shields.io/badge/dbt-1.0%2B-orange) ![Snowflake](https://img.shields.io/badge/Snowflake-Compatible-blue) ![BigQuery](https://img.shields.io/badge/BigQuery-Compatible-blue)

## 📖 What is this?

**GrowthCues Core** is an open-source dbt project that acts as the foundational semantic layer for Product-Led Growth (PLG) teams in B2B SaaS organizations.

👉 For a tutorial on how to use this for self-serve GTM analytics, read: [Building Self-Serve GTM Analytics with Claude, BigQuery, dbt, and MCP](https://growthcues.com/blog/self-serve-analytics-claude-mcp/).

Most analytics tools focus only on Users. B2B businesses need to track **Accounts**. This project handles both.

It produces six critical tables in your warehouse:

1. **`fct_product_metrics_daily`**: The executive view. Global DAU/WAU/MAU and Account volume (DAA/WAA/MAA) across the entire product, with velocity trends.

2. **`fct_account_metrics_daily`**: The operational view. Granular, account-by-account health metrics including Stickiness, Feature Breadth, Seat Velocity, Usage Contraction, and Churn Risk flags.

3. **`fct_user_metrics_daily`**: The behavioral view. Snapshot of individual user activity, frequency, session patterns, champion identification, admin proxy flags, and lifecycle status.

4. **`fct_sessions`**: The engagement view. Sessionized event data showing user engagement patterns including session duration, events per session, and session frequency.

5. **`dim_accounts`**: A master dimension table for every company, including first/last seen timestamps, current active seats, lifetime users, and days since activity.

6. **`dim_users`**: A master dimension table for every user, including first/last seen timestamps, lifetime account associations, and primary account mapping.

## 🚀 Features

- **Warehouse Native:** Runs entirely on Snowflake or BigQuery. No data leaves your infrastructure.

- **B2B Standard:** Compatible out-of-the-box with Segment and Rudderstack using the **Segment B2B SaaS spec**. Requires `context_group_id` in tracks table for account identification; however, you can customize this field in `dbt_project.yml` if your implementation differs.

- **Identity Stitching:** Automatically links anonymous visitor activity to authenticated users, providing complete customer journey visibility from first touch to conversion. Includes account backfilling to attribute pre-signup events to B2B accounts.

- **Smart Sessionization:** Groups raw events into meaningful user sessions with configurable timeout windows. Handles incremental processing efficiently to minimize warehouse compute costs.

- **B2B SaaS Granularity:** Calculates metrics at the Global (Product), Account (Customer), and User (Person) levels.

- **Zero Hallucinations:** Includes a specialized `schema.yml` designed to ground LLMs (ChatGPT/Claude) in your specific business logic.

## 🛠 Quick Start

Choose your installation method based on your needs:

- **Method 1 (Recommended):** Install as a **dbt Package** - Get automatic updates and easy version management
- **Method 2:** Clone as a **Template** - Full control to customize SQL directly

### Prerequisites

Before you begin, ensure you have:

- dbt Core (v1.0+) or dbt Cloud
- **Python 3.10 or higher** installed on your computer
- Access to a **Snowflake** or **BigQuery** warehouse with appropriate permissions
- Raw data from **Segment** or **Rudderstack** loaded into your warehouse following the **Segment B2B SaaS spec**:
  - `tracks` table with `context_group_id` field (containing the account/group ID)
  - `users` table (identify calls)
  - `groups` table (group/account identify calls)
  - **Note:** This project assumes the B2B SaaS data model where account context is passed via `context_group_id` in event tracking. If your implementation uses a different field for account IDs, you can customize this in `dbt_project.yml`.

---

## 📦 Installation Method 1: dbt Package (Recommended)

Install GrowthCues Core as a package in your existing dbt project. This method gives you automatic updates and clean separation between your code and the package code.

### Step 1: Add to packages.yml

In your dbt project root, create or edit `packages.yml`:

```yaml
packages:
  - package: growthcues/growthcues_core
    version: 1.0.0
```

### Step 2: Install the package

```bash
dbt deps
```

This downloads the package into `dbt_packages/growthcues_core/` (do not edit files in this folder).

### Step 3: Configure sources in your dbt_project.yml

Add these variables to your `dbt_project.yml` to point to your Segment/Rudderstack data:

```yaml
vars:
  growthcues_core:
    # Required: Point to your Segment data location
    segment_database: "YOUR_DATABASE" # e.g., "ANALYTICS" (Snowflake) or your project ID (BigQuery)
    segment_schema: "YOUR_SEGMENT_SCHEMA" # e.g., "segment_production", "rudderstack_events"


    # Optional: Override table names if they differ
    # segment_tracks_table: "tracks"
    # segment_pages_table: "pages"
    # segment_identifies_table: "identifies"
    # segment_users_table: "users"
    # segment_groups_table: "groups"

    # Optional: Customize behavior
    # session_timeout_minutes: 30
    # include_pages_in_sessions: false
    # enable_identity_stitching: true
```

**Example for Snowflake:**

```yaml
vars:
  growthcues_core:
    segment_database: "ANALYTICS"
    segment_schema: "segment_production"
```

**Example for BigQuery:**

```yaml
vars:
  growthcues_core:
    segment_database: "my-company-analytics" # Your GCP project ID
    segment_schema: "segment_events"
```

### Step 4: Run the models

```bash
# Run all GrowthCues Core models
dbt run --models growthcues_core

# Or run specific models
dbt run --models growthcues_core.fct_product_metrics_daily
```

### Step 5: Query your metrics

The package creates six tables in your target schema:

```sql
-- Snowflake
SELECT * FROM YOUR_SCHEMA.fct_product_metrics_daily LIMIT 10;

-- BigQuery
SELECT * FROM `YOUR_PROJECT.YOUR_DATASET.fct_product_metrics_daily` LIMIT 10;
```

**That's it!** You now have all six metrics tables available. To update to a new version, just change the version in `packages.yml` and run `dbt deps` again.

---

## 🔧 Installation Method 2: Template/Clone

Use this method if you need to customize the SQL directly or want full control over the code.

### Prerequisites (same as above)

### Step 1: Install Python (if not already installed)

**Windows:**

1. Download Python from [python.org/downloads](https://python.org/downloads)
2. Run the installer and **check the box** "Add Python to PATH"
3. Complete the installation

**Mac:**

```bash
brew install python3
```

**Linux:**

```bash
sudo apt update
sudo apt install python3 python3-pip
```

**Verify installation:**
Open a terminal/command prompt and run:

```bash
python --version
# Should show Python 3.10 or higher
```

### Step 2: Install dbt Core

Open your terminal/command prompt and run the appropriate command for your data warehouse:

**For Snowflake:**

```bash
pip install dbt-snowflake
```

**For BigQuery:**

```bash
pip install dbt-bigquery
```

**Verify installation:**

```bash
dbt --version
# Should show dbt version 1.0 or higher
```

### Step 3: Clone This Project

Navigate to where you want to store the project and run:

```bash
git clone https://github.com/growthcues/growthcues-core.git
cd growthcues-core
```

If you don't have `git` installed:

- **Windows/Mac:** Download GitHub Desktop from [desktop.github.com](https://desktop.github.com)
- **Or** download the project as a ZIP file from GitHub and extract it

### Step 4: Configure Database Connection

You need to create a `profiles.yml` file to connect dbt to your data warehouse.

#### Option A: Snowflake Connection

1. **Find your dbt profiles directory:**
   - **Mac/Linux:** `~/.dbt/`
   - **Windows:** `C:\Users\YourUsername\.dbt\`

2. **Create the directory if it doesn't exist:**

   ```bash
   mkdir -p ~/.dbt
   ```

3. **Create or edit the `profiles.yml` file** in that directory with the following content:

```yaml
growthcues_core:
  target: prod
  outputs:
    prod:
      type: snowflake
      account: YOUR_ACCOUNT_IDENTIFIER # e.g., abc12345.us-east-1
      user: YOUR_USERNAME
      password: YOUR_PASSWORD
      role: YOUR_ROLE # e.g., ANALYST, TRANSFORMER
      database: YOUR_DATABASE # e.g., ANALYTICS
      warehouse: YOUR_WAREHOUSE # e.g., COMPUTE_WH
      schema: YOUR_SCHEMA # e.g., DBT_PROD (where models will be created)
      threads: 4
      client_session_keep_alive: False
```

**To find your Snowflake account identifier:**

- Look at your Snowflake URL: `https://ABC12345.snowflakecomputing.com/`
- Your account identifier is `ABC12345` (or might include region like `ABC12345.us-east-1`)

**Alternative: Using key pair authentication (more secure):**

```yaml
growthcues_core:
  target: prod
  outputs:
    prod:
      type: snowflake
      account: YOUR_ACCOUNT_IDENTIFIER
      user: YOUR_USERNAME
      private_key_path: /path/to/your/private_key.p8
      private_key_passphrase: YOUR_PASSPHRASE # if key is encrypted
      role: YOUR_ROLE
      database: YOUR_DATABASE
      warehouse: YOUR_WAREHOUSE
      schema: YOUR_SCHEMA
      threads: 4
```

#### Option B: BigQuery Connection

1. **Set up a Google Cloud Service Account:**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Navigate to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Give it a name (e.g., `dbt-user`)
   - Grant it these roles:
     - `BigQuery Data Editor`
     - `BigQuery Job User`
   - Click "Create Key" → Choose JSON → Download the key file
   - Save this file securely (e.g., `~/.dbt/bigquery-keyfile.json`)

2. **Find your dbt profiles directory:**
   - **Mac/Linux:** `~/.dbt/`
   - **Windows:** `C:\Users\YourUsername\.dbt\`

3. **Create the directory if it doesn't exist:**

   ```bash
   mkdir -p ~/.dbt
   ```

4. **Create or edit the `profiles.yml` file** in that directory:

```yaml
growthcues_core:
  target: prod
  outputs:
    prod:
      type: bigquery
      method: service-account
      project: YOUR_GCP_PROJECT_ID # e.g., my-company-analytics
      dataset: YOUR_DATASET # e.g., dbt_prod (where models will be created)
      threads: 4
      keyfile: /path/to/bigquery-keyfile.json # Full path to your downloaded JSON key
      location: US # or EU, asia-northeast1, etc.
```

**To find your GCP Project ID:**

- Open Google Cloud Console
- Look at the top of the page, next to the Google Cloud logo
- The Project ID is shown in the dropdown (e.g., `my-company-analytics-123456`)

**Alternative: Using OAuth (for personal use):**

```yaml
growthcues_core:
  target: prod
  outputs:
    prod:
      type: bigquery
      method: oauth
      project: YOUR_GCP_PROJECT_ID
      dataset: YOUR_DATASET
      threads: 4
      location: US
```

### Step 5: Test Your Connection

Run this command to verify your connection is working:

```bash
dbt debug
```

You should see green checkmarks (✓) for all connection tests. If you see errors:

- **Snowflake:** Check your account identifier, username, password, and role
- **BigQuery:** Verify your keyfile path is correct and the service account has proper permissions

### Step 6: Configure Your Data Sources

You can now configure data sources using variables in your `dbt_project.yml`:

```yaml
vars:
  # Required: Point to your Segment data location
  segment_database: "YOUR_RAW_DATABASE" # e.g., "RAW_DATA" (Snowflake) or your project ID (BigQuery)
  segment_schema: "YOUR_SEGMENT_SCHEMA" # e.g., "segment_production", "rudderstack_events"


  # Optional: Override table names if they differ
  # segment_tracks_table: "tracks"
  # segment_pages_table: "pages"
  # segment_identifies_table: "identifies"
  # segment_users_table: "users"
  # segment_groups_table: "groups"

  # Optional: Customize behavior
  # session_timeout_minutes: 30
  # include_pages_in_sessions: false
  # enable_identity_stitching: true
```

**For Snowflake example:**

```yaml
vars:
  segment_database: "RAW_DATA"
  segment_schema: "SEGMENT_PRODUCTION"
```

**For BigQuery example:**

```yaml
vars:
  segment_database: "my-company-analytics" # Your GCP project ID
  segment_schema: "segment_events"
```

**How to find where your Segment data is:**

- **Snowflake:** Log into Snowflake → Databases → Look for your Segment database/schema
- **BigQuery:** Log into BigQuery Console → Look for your Segment dataset

**Note:** The `models/staging/sources.yml` file now uses these variables automatically, so you don't need to edit it directly.

### Step 7: Install Project Dependencies

This project uses `dbt-utils` for compatibility. Install it by running:

```bash
dbt deps
```

You should see a message confirming that packages were installed.

### Step 7.5: Configure Session Timeout (Optional)

By default, user sessions are defined with a 30-minute inactivity timeout. You can customize this in `dbt_project.yml`:

```yaml
vars:
  session_timeout_minutes: 30 # Change to your preferred timeout in minutes
  include_pages_in_sessions: true # Set to false to exclude page views from sessions
```

**What this controls:**

- **Session definition:** Two events by the same user are considered part of the same session if they occur within this time window
- **Incremental lookback:** When running incrementally, the model looks back this many minutes from the last session end to catch sessions that might still be active
- **Page view inclusion:** When `include_pages_in_sessions` is `true` (default), both tracked events AND page views are included in session calculation. When `false`, only tracked events count toward sessions.

**Common values:**

- **30 minutes** (default): Standard for most web applications
- **60 minutes**: For products with longer, more contemplative workflows
- **15 minutes**: For high-frequency, task-based applications

**Page view inclusion:**

- **`true` (default)**: Page views contribute to session duration and help define session boundaries. Useful for content-heavy products where browsing is meaningful engagement.
- **`false`**: Only explicit tracked events count in sessions. Useful for pure SaaS products where page views are navigation noise and only feature usage matters.

After changing these values, run `dbt run --full-refresh` to recalculate all sessions with the new configuration.

### Step 8: Run the Models

Now you're ready to build your metrics tables! Run:

```bash
dbt run
```

**What happens:**

- dbt will create six new tables/views in your warehouse:
  - `fct_product_metrics_daily` - Global product metrics (DAU, MAU, DAA, MAA, etc.)
  - `fct_account_metrics_daily` - Account-level health metrics (stickiness, churn risk, etc.)
  - `fct_user_metrics_daily` - User-level behavioral metrics and lifecycle status
  - `fct_sessions` - Session-level engagement data (duration, events per session, etc.)
  - `dim_accounts` - Master account dimension table
  - `dim_users` - Master user dimension table

**First run will take a few minutes** depending on how much data you have.

### Step 9: Verify the Results

**In Snowflake:**

```sql
SELECT * FROM YOUR_SCHEMA.fct_product_metrics_daily LIMIT 10;
```

**In BigQuery:**

```sql
SELECT * FROM `YOUR_PROJECT.YOUR_DATASET.fct_product_metrics_daily` LIMIT 10;
```

You should see daily metrics with dates, user counts, and account counts.

### Step 10: Schedule Regular Runs (Optional)

To keep your metrics up-to-date, you can:

1. **Use dbt Cloud** (easiest - has a visual scheduler)
2. **Set up a cron job** (Linux/Mac):

   ```bash
   # Edit crontab
   crontab -e

   # Add this line to run daily at 6 AM
   0 6 * * * cd /path/to/growthcues-core && dbt run
   ```

3. **Use GitHub Actions** (see [dbt GitHub Actions guide](https://docs.getdbt.com/docs/deploy/github-actions))
4. **Use Airflow, Prefect, or another orchestration tool**

---

## ❓ Frequently Asked Questions

**Why isn't this on dbt Hub yet?**

We're preparing for dbt Hub publication! This project now supports **both installation methods**:

1. **Package installation** (via `packages.yml`) - recommended for most users who want easy updates
2. **Template/clone** - for users who need full control to customize the SQL

While we finalize our dbt Hub submission (integration tests, CI/CD, etc.), you can install it as a package using the Git method:

```yaml
packages:
  - git: "https://github.com/growthcues/growthcues-core.git"
    revision: main
```

Once published on dbt Hub, you'll be able to use:

```yaml
packages:
  - package: growthcues/growthcues_core
    version: 1.0.0
```

**Which installation method should I use?**

- **Use Package (Method 1)** if you want:
  - Easy updates via `dbt deps`
  - Clean separation between your code and package code
  - Standard dbt package management
- **Use Template/Clone (Method 2)** if you want:
  - Full control to modify the SQL directly
  - Custom business logic that requires deep changes
  - To fork and maintain your own version

**Can I switch between installation methods later?**

Yes, but it requires some migration:

- From Template → Package: Remove the cloned files, add to `packages.yml`, move variables to your `dbt_project.yml`
- From Package → Template: Clone the repo, remove from `packages.yml`, customize as needed

---

## 🔧 Troubleshooting

**"dbt command not found"**

- Make sure you ran `pip install dbt-snowflake` or `dbt-bigquery`
- Restart your terminal after installation

**"Could not find profile named 'growthcues_core'"**

- Check that your `profiles.yml` file is in the right location (`~/.dbt/`)
- Make sure the profile name matches exactly: `growthcues_core`

**"Database/Schema does not exist"**

- Verify the database and schema names in your `dbt_project.yml` variables
- Make sure your user has access to read from those locations

**"Insufficient privileges"**

- Your database user needs permission to CREATE TABLE in the target schema
- Contact your database admin to grant appropriate permissions

**"No tracks/users/groups table found"**

- Confirm Segment/Rudderstack is successfully loading data into your warehouse
- Check the exact table names - they might have prefixes or be in a different schema
- Verify your `segment_database` and `segment_schema` variables are correct

**"Missing context_group_id or account_id is always null"**

- This project requires the Segment B2B SaaS spec where account IDs are passed as `context_group_id`
- Verify your Segment implementation uses `analytics.group()` calls to set the group context
- Check that your tracking calls include the group context: `analytics.track(event, {}, {groupId: 'account_123'})`
- You can customize the field name using the `group_id` variable in `dbt_project.yml`

## 🤖 The "AI-Ready" Advantage

The hardest part of "Self-Serve Analytics" is that AI agents often hallucinate because they don't understand your business context.

This project includes **Prompt-Engineered Documentation** with clear definitions, formulas, and context:

- `models/marts/core/schema.yml` - Technical dbt schema with [Definition], [Formula], and [Context] tags
- `METRICS.md` - User-friendly metrics dictionary in markdown format

### How to use it:

1. Open `models/marts/core/schema.yml` or `METRICS.md`.
2. Copy the entire file content.
3. Paste it into **ChatGPT**, **Claude**, or your internal AI agent with this prompt:
   > "You are a Data Analyst. Here is the metrics documentation for our B2B SaaS data warehouse, including definitions, formulas, and context. Use this context to answer my questions.

> [PASTE DOCUMENTATION HERE]

> Question: Which accounts are currently at risk of churning based on their recent usage trends?"

4. **Result:** The AI will generate accurate SQL or answers based on the specific definitions and context provided, eliminating hallucinations and ensuring queries align with your business logic.

## 📊 Metrics Included

### Product Level (Global)

_Source: `fct_product_metrics_daily`_

| Metric                     | Definition                                                                                                         |
| :------------------------- | :----------------------------------------------------------------------------------------------------------------- |
| **Global DAU / WAU / MAU** | Unique **users** active in the last 1/7/30 days across the entire platform.                                        |
| **Global DAA / WAA / MAA** | Unique **accounts** active in the last 1/7/30 days across the entire platform.                                     |
| **Global Stickiness**      | The ratio of Daily Active entities to Monthly Active entities (DAU/MAU or DAA/MAA).                                |
| **Velocity Trends**        | 7, 14, and 30-day linear trends for all DAU/WAU/MAU and DAA/WAA/MAA metrics. Represents average daily growth rate. |

### Account Level (Per Customer)

_Source: `fct_account_metrics_daily`_

| Metric                      | Definition                                                              | PLG Use Case                                               |
| :-------------------------- | :---------------------------------------------------------------------- | :--------------------------------------------------------- |
| **Account DAU / WAU / MAU** | Active users within this specific account (daily/weekly/monthly).       | Measuring per-account seat utilization.                    |
| **Daily Event Volume**      | Total events performed by this account today.                           | Tracking engagement intensity.                             |
| **Session Metrics**         | Sessions per day/7d/30d, time on platform, average daily sessions/time. | Understanding account engagement depth and usage patterns. |
| **Feature Breadth**         | Count of unique event types used in last 30 days.                       | Measuring product depth and sophistication.                |
| **Active Days (7d/30d)**    | Number of days the account was active.                                  | Frequency indicator for engagement patterns.               |
| **Account Stickiness**      | Ratio of active_days_7d / active_days_30d.                              | Measuring usage consistency and habit formation.           |
| **User Stickiness**         | Ratio of DAU / MAU _within_ that account.                               | Measuring user depth and engagement quality.               |
| **Dormant Risk**            | Active in last 30 days, but 0 events in last 7 days.                    | Early warning for proactive churn prevention.              |
| **Net New Users (7d)**      | Weekly seat velocity (change in active seats).                          | Expansion signals for upsell opportunities.                |
| **Volume Change Ratio**     | Event volume trend (last 7d vs prior 7d).                               | Churn warning when usage is declining.                     |
| **Velocity Trends**         | 7, 14, and 30-day trends for DAU/WAU/MAU.                               | Account growth momentum tracking.                          |

### User Level (Per Person)

_Source: `fct_user_metrics_daily`_

| Metric                       | Definition                                                        | PLG Use Case                                           |
| :--------------------------- | :---------------------------------------------------------------- | :----------------------------------------------------- |
| **Daily/Monthly Events**     | Event volume on snapshot date and over last 30 days.              | Measuring individual user engagement intensity.        |
| **Session Metrics**          | Sessions per day/month, avg session duration, events per session. | Understanding engagement depth and usage patterns.     |
| **Usage Frequency (L7/L14)** | Days active in last 7 and 14 days.                                | Identifying "Power Users" (3+ days in L7, 10+ in L14). |
| **Usage Rank in Account**    | User's ranking by volume within their account.                    | Identifying "Champions" (Rank 1) for customer success. |
| **Admin Proxy Flag**         | First user seen in the account (likely buyer/admin).              | Targeting decision-makers for renewals and expansion.  |
| **Feature Sophistication**   | Count of unique features used in last 30 days.                    | Measuring product depth and power user behavior.       |
| **Lifecycle Status**         | New, Active, Dormant, Resurrected, or Churned.                    | Growth Accounting and retention analysis.              |
| **Latest Account**           | The primary account ID for this user.                             | Mapping users to organizations.                        |

### Dimension Tables

_Sources: `dim_accounts` and `dim_users`_

| Table            | Key Attributes                                                                                            | Use Case                                                                             |
| :--------------- | :-------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------- |
| **dim_accounts** | Account ID, first/last seen timestamps, current active seats, lifetime users, days since first/last seen. | Master account reference for joins, cohort analysis, and churn identification.       |
| **dim_users**    | User ID, first/last seen timestamps, lifetime accounts, latest account, days since first/last seen.       | Master user reference for joins, understanding user tenure and account associations. |

_See `METRICS.md` for full definitions._

## 🔗 How Identity Stitching Works

Identity stitching is the process of linking anonymous visitor activity to known user identities. This is critical for B2B SaaS because it allows you to attribute pre-signup behavior (product exploration, free tier usage) to the accounts that eventually convert.

### What is Identity Stitching?

**Identity stitching** connects anonymous visitor IDs (e.g., `anonymous_id`, `visitor_id`, `device_id`) to authenticated user IDs (e.g., `user_id`, `email`) so that all of a user's activity—both before and after they identify themselves—can be attributed to a single identity.

**Common scenarios:**

- **Anonymous browsing → Signup:** Visitor browses your marketing site anonymously, then creates an account → Their browsing events get mapped to their user_id
- **Multi-device usage:** User browses on mobile (anonymous), then logs in on desktop → Mobile activity gets linked to their authenticated identity
- **Freemium conversion:** User explores your product as anonymous/trial user, then upgrades → Pre-conversion behavior helps predict future conversions

### Why This Matters for B2B SaaS

Without identity stitching:

- You lose visibility into the pre-signup journey
- Product analytics show artificially low engagement (missing anonymous events)
- Attribution is broken (can't connect early interest signals to converted accounts)

With identity stitching:

- Complete customer journey from first touch to conversion
- Accurate product engagement metrics including trial/free tier activity
- Better predictive models (more complete behavioral history)

### The Algorithm

Identity stitching uses a **three-table approach**:

#### Step 1: Build Identity Graph

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

**Why the timestamp filter?** Identity mappings can become stale (e.g., shared devices, recycled IDs). The lookback window (default: 365 days) ensures we only use recent mappings.

#### Step 2: Resolve to Master Identity

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

#### Step 3: Stitch Events

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

### Account Backfilling Logic

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

### Configurable Fields and Lookback Windows

Different tracking implementations use different field names for anonymous identifiers. This project makes both the field name and lookback window configurable in `dbt_project.yml`:

```yaml
vars:
  enable_identity_stitching: true # Set to false to completely disable identity stitching
  identity_anonymous_id_field: "anonymous_id" # Change to visitor_id, device_id, etc.
  identity_lookback_days: 365 # How far back to look for identity mappings
  tracks_lookback_days: 365 # How far back to process tracks data
```

**When to adjust:**

- **`enable_identity_stitching`**: Set to `false` to disable identity stitching entirely
  - **Use case:** Your product always requires authentication (no anonymous users)
  - **Effect:** Skips `stg_identity_resolution` and `stg_user_account_mapping` models, removes JOINs from `stg_segment_tracks`
  - **Performance benefit:** Eliminates identity stitching overhead if not needed
- **`identity_anonymous_id_field`**: Change if your tracking uses a different field name (e.g., `visitor_id`, `device_id`, `client_id`)
- **`identity_lookback_days`**:
  - **Increase (730+ days):** If you have long sales cycles and need historical mappings
  - **Decrease (90-180 days):** For performance optimization if your sales cycle is short
- **`tracks_lookback_days`**:
  - **Decrease (90-180 days):** To limit data processing volume and improve query performance
  - **Increase (730+ days):** If you need long-term historical analysis

After changing these values, run `dbt run --full-refresh` to recalculate with the new configuration.

### What If Users Never Have Anonymous Events?

The identity stitching is **completely optional** and graceful:

- **Users who always authenticate:** Their events already have `user_id` → no stitching needed, events pass through unchanged
- **Users who are always anonymous:** No identify events exist → they remain anonymous, no data corruption
- **Users with mixed behavior:** Anonymous events get stitched to their authenticated identity → complete journey visibility

The `COALESCE()` logic ensures that explicit identities always take precedence over stitched ones.

### Cross-Database Compatibility

The identity stitching logic uses dbt's cross-database macros to work on both BigQuery and Snowflake:

- `dbt.dateadd()` instead of `TIMESTAMP_ADD` or `DATEADD`
- `dbt.current_timestamp()` instead of `CURRENT_TIMESTAMP()` or `CURRENT_TIMESTAMP`
- Standard SQL window functions (supported by both platforms)

This ensures the same SQL compiles correctly on both data warehouses.

### Data Lineage

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

### Performance Considerations

Identity stitching adds two LEFT JOINs to the tracks staging model, which can impact query performance:

**Query Performance:**

- Each tracks query joins with `stg_identity_resolution` (small lookup table) and `stg_user_account_mapping` (user-level aggregation)
- For large event volumes (millions of rows), these joins are the primary performance factor
- **Recommended:** Materialize `stg_identity_resolution` and `stg_user_account_mapping` as **tables** (already configured by default)
- **Optimization:** The lookback windows (`identity_lookback_days`, `tracks_lookback_days`) directly control data volume—decrease them if performance is a concern

**Build Time:**

- Initial `dbt run` processes all historical data within the lookback window
- Subsequent incremental runs are much faster
- **Typical timing:**
  - 1M events: ~30-60 seconds on medium warehouse
  - 10M events: ~3-5 minutes on medium warehouse
  - 100M+ events: Consider decreasing `tracks_lookback_days` to 90-180 days

**Warehouse Costs:**

- Identity stitching adds ~20-30% to staging layer compute time compared to no stitching
- This is a one-time cost at the staging layer—downstream models benefit from clean, stitched data
- **Cost optimization:** Use incremental runs (`dbt run`) instead of full refreshes for production

**When to disable:**

- If your product always requires authentication (no anonymous usage), you can skip identity stitching entirely
- Set `enable_identity_stitching: false` in `dbt_project.yml` to disable all identity stitching models and joins
- All tracks will pass through with their original `user_id` and `account_id` values

## � How Sessionization Works

The `fct_sessions` table uses a sophisticated algorithm to group raw events into meaningful user sessions. Understanding this logic helps you interpret session metrics correctly and customize the timeout if needed.

### What is a Session?

A **session** is a continuous sequence of events by the same user with no more than **30 minutes** (configurable) of inactivity between events.

**Note:** By default, sessions include both **tracked events** (from `stg_segment_tracks`) and **page views** (from `stg_segment_pages`). This can be controlled via the `include_pages_in_sessions` variable in `dbt_project.yml`.

**Examples:**

- User logs in at 9:00 AM, clicks 10 buttons, views 5 pages, logs out at 9:45 AM → **1 session** (45 minutes duration, 15 total interactions)
- User active at 2:00 PM, then inactive until 3:00 PM → **2 sessions** (60-minute gap exceeds timeout)
- User makes 1 click at 4:00 PM, no other activity → **1 session** (0 minutes duration, 1 event)

### The Algorithm

The sessionization logic uses a **three-step window function approach**:

#### Step 1: Detect Session Boundaries

For each event, we look at the **previous event** by the same user and calculate the time gap:

```sql
-- If gap > 30 minutes → new session (flag = 1)
-- If gap ≤ 30 minutes → same session (flag = 0)
CASE
  WHEN DATEDIFF(previous_event, current_event, 'minute') > 30
  THEN 1
  ELSE 0
END AS is_new_session_flag
```

Uses `LAG()` window function to access the previous event timestamp.

#### Step 2: Create Session Groups

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

#### Step 3: Aggregate to Session Level

Finally, we group all events by `(user_id, user_session_index)` and calculate:

- **Session Start:** `MIN(event_timestamp)`
- **Session End:** `MAX(event_timestamp)`
- **Duration:** Time difference between start and end
- **Events in Session:** `COUNT(*)`
- **Account ID:** Taken from the **first event** chronologically in the session

### Account Attribution Logic

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

### Incremental Processing

To optimize warehouse costs, the model uses **incremental materialization**:

```sql
-- On incremental runs, only process NEW events
-- But look back 30 minutes to catch sessions still in progress
WHERE event_at >= (last_session_end - 30 minutes)
```

**Why the lookback?** Without it, a session spanning multiple incremental runs would be split into separate sessions. The lookback ensures we recalculate any session that might still be active.

**Trade-off:** Small amount of duplicate work (last 30 minutes) to ensure correctness.

### Customizing Session Timeout

The default 30-minute timeout works for most web applications, but you can adjust it in `dbt_project.yml`:

```yaml
vars:
  session_timeout_minutes: 60 # Increase for longer workflows
```

**When to change:**

- **Increase (60+ min):** For products with contemplative workflows (e.g., design tools, research platforms)
- **Decrease (15 min):** For high-frequency, task-based apps (e.g., chat tools, quick lookups)

After changing, run `dbt run --full-refresh --models fct_sessions` to recalculate all sessions with the new timeout.

### Cross-Database Compatibility

The logic uses dbt's cross-database macros to work on both BigQuery and Snowflake:

- `dbt.datediff()` instead of `TIMESTAMP_DIFF` or `DATEDIFF`
- `dbt.dateadd()` instead of `TIMESTAMP_ADD` or `DATEADD`
- `dbt_utils.generate_surrogate_key()` for session ID generation

This ensures the same SQL compiles correctly on both platforms.

### Performance Considerations

Sessionization uses window functions (`LAG()`, `ROW_NUMBER()`, `SUM() OVER()`), which are compute-intensive:

**Why It's Expensive:**

- Window functions must process all events per user in order
- Cannot be easily parallelized within a user's event stream
- Performance scales with total event volume and number of unique users

**Incremental Strategy:**

- `fct_sessions` uses **incremental materialization** to minimize reprocessing
- Initial `dbt run --full-refresh` processes all historical data
- Subsequent `dbt run` only processes new events + a lookback window (default: `session_timeout_minutes`)
- The lookback ensures sessions spanning multiple runs aren't split incorrectly

**Optimization Strategies:**

- **Use incremental runs for production:** Avoid `--full-refresh` unless changing `session_timeout_minutes`
- **Reduce input volume:** Decrease `tracks_lookback_days` in staging to limit historical data
- **Warehouse sizing:** Test with your actual data volume to determine appropriate warehouse size
- **Clustering/Partitioning:** Consider adding clustering on `user_id` (Snowflake) or partitioning by date (BigQuery) for very large datasets

**Monitoring:**

- Run `dbt run --models fct_sessions` and check the logs for execution time
- Compare incremental vs full-refresh timing to validate your incremental strategy is working
- If builds are slower than expected, review the dbt docs on incremental model optimization for your warehouse

## ✨🔮 About GrowthCues

This repository handles the Descriptive Layer of your GTM stack (answering "what happened?") and is 100% open source. It contains the foundational metrics every B2B SaaS company needs.

Do you want to go further and to track user or customer journeys, or predict account behavior for sales/CS teams?

I have built GrowthCues as a headless semantic layer for B2B SaaS that runs on top of the same warehouse-native architecture but adds:

- No-Code Journey Modeling: Define complex milestones (e.g., "Onboarding Complete") and journey completion scores without writing SQL.

- Predictive Scoring: AI-generated "Likelihood to Convert" and "Likelihood to Churn" scores.

- Advanced Trends: Detects true trajectory using linear regression and complex windowing (vs. simplified linear velocity in this repo).

- Compute Savings: Calculations run on the GrowthCues engine, eliminating the daily compute costs on your Snowflake/BigQuery warehouse.

- Reverse ETL Ready: Sync signals directly to Salesforce, HubSpot, or Slack.

- AI Ready: Auto-generated dbt schema optimized for LLMs to prevent hallucinations. Includes also the metrics for customer journeys and predictions.

If you need to go beyond standard metrics and start tracking or predicting customer journeys, check out [growthcues.com](https://growthcues.com).

## License

MIT License. See `LICENSE` for details.
