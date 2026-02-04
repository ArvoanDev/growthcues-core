# GrowthCues Core

**The Open Source Semantic Layer for B2B SaaS.**

A dbt project to calculate **Account-Level** and **Product-Level** metrics from Segment/Rudderstack data using the **Segment B2B SaaS spec**. Includes AI-ready schema context.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![dbt](https://img.shields.io/badge/dbt-1.0%2B-orange) ![Snowflake](https://img.shields.io/badge/Snowflake-Compatible-blue) ![BigQuery](https://img.shields.io/badge/BigQuery-Compatible-blue)

## 📖 What is this?

**GrowthCues Core** is an open-source dbt project that acts as the foundational semantic layer for Product-Led Growth (PLG) teams in B2B SaaS organizations.

Most analytics tools focus only on Users. B2B businesses need to track **Accounts**. This project handles both.

It produces five critical tables in your warehouse:

1. **`fct_product_metrics_daily`**: The executive view. Global DAU/WAU/MAU and Account volume (DAA/WAA/MAA) across the entire product, with velocity trends.

2. **`fct_account_metrics_daily`**: The operational view. Granular, account-by-account health metrics including Stickiness, Feature Breadth, Seat Velocity, Usage Contraction, and Churn Risk flags.

3. **`fct_user_metrics_daily`**: The behavioral view. Snapshot of individual user activity, frequency, champion identification, admin proxy flags, and lifecycle status.

4. **`dim_accounts`**: A master dimension table for every company, including first/last seen timestamps, current active seats, lifetime users, and days since activity.

5. **`dim_users`**: A master dimension table for every user, including first/last seen timestamps, lifetime account associations, and primary account mapping.

## 🚀 Features

- **Warehouse Native:** Runs entirely on Snowflake or BigQuery. No data leaves your infrastructure.

- **B2B Standard:** Compatible out-of-the-box with Segment and Rudderstack using the **Segment B2B SaaS spec** (requires `context_group_id` in tracks table for account identification).

- **B2B SaaS Granularity:** Calculates metrics at the Global (Product), Account (Customer), and User (Person) levels.

- **Zero Hallucinations:** Includes a specialized `schema.yml` designed to ground LLMs (ChatGPT/Claude) in your specific business logic.

## 🛠 Quick Start

### Prerequisites

Before you begin, ensure you have:

- dbt Core (v1.0+) or dbt Cloud.
- **Python 3.10 or higher** installed on your computer
- Access to a **Snowflake** or **BigQuery** warehouse with appropriate permissions
- Raw data from **Segment** or **Rudderstack** loaded into your warehouse following the **Segment B2B SaaS spec**:
  - `tracks` table with `context_group_id` field (containing the account/group ID)
  - `users` table (identify calls)
  - `groups` table (group/account identify calls)
  - **Note:** This project assumes the B2B SaaS data model where account context is passed via `context_group_id` in event tracking

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

Open `models/staging/sources.yml` in a text editor and update it to point to where your Segment/Rudderstack data lives:

**For Snowflake:**

```yaml
sources:
  - name: segment
    database: YOUR_RAW_DATABASE # e.g., RAW_DATA
    schema: YOUR_SEGMENT_SCHEMA # e.g., SEGMENT_PRODUCTION
    tables:
      - name: tracks
      - name: users
      - name: groups
```

**For BigQuery:**

```yaml
sources:
  - name: segment
    database: YOUR_GCP_PROJECT_ID # e.g., my-company-analytics
    schema: YOUR_SEGMENT_DATASET # e.g., segment_production
    tables:
      - name: tracks
      - name: users
      - name: groups
```

**How to find where your Segment data is:**

- **Snowflake:** Log into Snowflake → Databases → Look for your Segment database/schema
- **BigQuery:** Log into BigQuery Console → Look for your Segment dataset

### Step 7: Install Project Dependencies

This project uses `dbt-utils` for compatibility. Install it by running:

```bash
dbt deps
```

You should see a message confirming that packages were installed.

### Step 8: Run the Models

Now you're ready to build your metrics tables! Run:

```bash
dbt run
```

**What happens:**

- dbt will create five new tables/views in your warehouse:
  - `fct_product_metrics_daily` - Global product metrics (DAU, MAU, DAA, MAA, etc.)
  - `fct_account_metrics_daily` - Account-level health metrics (stickiness, churn risk, etc.)
  - `fct_user_metrics_daily` - User-level behavioral metrics and lifecycle status
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

## 🔧 Troubleshooting

**"dbt command not found"**

- Make sure you ran `pip install dbt-snowflake` or `dbt-bigquery`
- Restart your terminal after installation

**"Could not find profile named 'growthcues_core'"**

- Check that your `profiles.yml` file is in the right location (`~/.dbt/`)
- Make sure the profile name matches exactly: `growthcues_core`

**"Database/Schema does not exist"**

- Verify the database and schema names in `models/staging/sources.yml`
- Make sure your user has access to read from those locations

**"Insufficient privileges"**

- Your database user needs permission to CREATE TABLE in the target schema
- Contact your database admin to grant appropriate permissions

**"No tracks/users/groups table found"**

- Confirm Segment/Rudderstack is successfully loading data into your warehouse
- Check the exact table names - they might have prefixes or be in a different schema

**"Missing context_group_id or account_id is always null"**

- This project requires the Segment B2B SaaS spec where account IDs are passed as `context_group_id`
- Verify your Segment implementation uses `analytics.group()` calls to set the group context
- Check that your tracking calls include the group context: `analytics.track(event, {}, {groupId: 'account_123'})`
- If using a different field name for account ID, you'll need to modify `models/staging/stg_segment_tracks.sql`

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

| Metric                      | Definition                                                        | PLG Use Case                                     |
| :-------------------------- | :---------------------------------------------------------------- | :----------------------------------------------- |
| **Account DAU / WAU / MAU** | Active users within this specific account (daily/weekly/monthly). | Measuring per-account seat utilization.          |
| **Daily Event Volume**      | Total events performed by this account today.                     | Tracking engagement intensity.                   |
| **Feature Breadth**         | Count of unique event types used in last 30 days.                 | Measuring product depth and sophistication.      |
| **Active Days (7d/30d)**    | Number of days the account was active.                            | Frequency indicator for engagement patterns.     |
| **Account Stickiness**      | Ratio of active_days_7d / active_days_30d.                        | Measuring usage consistency and habit formation. |
| **User Stickiness**         | Ratio of DAU / MAU _within_ that account.                         | Measuring user depth and engagement quality.     |
| **Dormant Risk**            | Active in last 30 days, but 0 events in last 7 days.              | Early warning for proactive churn prevention.    |
| **Net New Users (7d)**      | Weekly seat velocity (change in active seats).                    | Expansion signals for upsell opportunities.      |
| **Volume Change Ratio**     | Event volume trend (last 7d vs prior 7d).                         | Churn warning when usage is declining.           |
| **Velocity Trends**         | 7, 14, and 30-day trends for DAU/WAU/MAU.                         | Account growth momentum tracking.                |

### User Level (Per Person)

_Source: `fct_user_metrics_daily`_

| Metric                       | Definition                                           | PLG Use Case                                           |
| :--------------------------- | :--------------------------------------------------- | :----------------------------------------------------- |
| **Daily/Monthly Events**     | Event volume on snapshot date and over last 30 days. | Measuring individual user engagement intensity.        |
| **Usage Frequency (L7/L14)** | Days active in last 7 and 14 days.                   | Identifying "Power Users" (3+ days in L7, 10+ in L14). |
| **Usage Rank in Account**    | User's ranking by volume within their account.       | Identifying "Champions" (Rank 1) for customer success. |
| **Admin Proxy Flag**         | First user seen in the account (likely buyer/admin). | Targeting decision-makers for renewals and expansion.  |
| **Feature Sophistication**   | Count of unique features used in last 30 days.       | Measuring product depth and power user behavior.       |
| **Lifecycle Status**         | New, Active, Dormant, Resurrected, or Churned.       | Growth Accounting and retention analysis.              |
| **Latest Account**           | The primary account ID for this user.                | Mapping users to organizations.                        |

### Dimension Tables

_Sources: `dim_accounts` and `dim_users`_

| Table            | Key Attributes                                                                                            | Use Case                                                                             |
| :--------------- | :-------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------- |
| **dim_accounts** | Account ID, first/last seen timestamps, current active seats, lifetime users, days since first/last seen. | Master account reference for joins, cohort analysis, and churn identification.       |
| **dim_users**    | User ID, first/last seen timestamps, lifetime accounts, latest account, days since first/last seen.       | Master user reference for joins, understanding user tenure and account associations. |

_See `METRICS.md` for full definitions._

## 🔮 About GrowthCues

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
