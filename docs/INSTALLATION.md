# Installation Guide

Complete installation instructions for GrowthCues Core.

## Prerequisites

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

## 📦 Method 1: Install as dbt Package (Recommended)

Install GrowthCues Core as a package in your existing dbt project. This method gives you automatic updates and clean separation between your code and the package code.

### Step 1: Add to packages.yml

In your dbt project root, create or edit `packages.yml`:

```yaml
packages:
  - package: growthcues/growthcues_core
    version: 1.0.0
```

**Not on dbt Hub yet?** Use the Git method while we finalize Hub submission:

```yaml
packages:
  - git: "https://github.com/growthcues/growthcues-core.git"
    revision: main
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

**That's it!** You now have all six metrics tables available.

---

## 🔧 Method 2: Clone as Template

Use this method if you need to customize the SQL directly or want full control over the code.

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

```bash
python --version
# Should show Python 3.10 or higher
```

### Step 2: Install dbt Core

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

3. **Create or edit the `profiles.yml` file** in that directory:

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

4. **Create or edit the `profiles.yml` file:**

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

```bash
dbt debug
```

You should see green checkmarks (✓) for all connection tests. If you see errors, check the [Troubleshooting Guide](TROUBLESHOOTING.md).

### Step 6: Configure Your Data Sources

Configure data sources using variables in your `dbt_project.yml`:

```yaml
vars:
  # Required: Point to your Segment data location
  segment_database: "YOUR_RAW_DATABASE"
  segment_schema: "YOUR_SEGMENT_SCHEMA"

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

See [Configuration Guide](CONFIGURATION.md) for all available options.

### Step 7: Install Project Dependencies

```bash
dbt deps
```

### Step 8: Run the Models

```bash
# Using Make (Recommended)
make setup  # Install deps + seed data
make build  # Build all models and run tests

# Or using dbt directly
dbt run
```

**What happens:**

- dbt will create six new tables/views in your warehouse:
  - `fct_product_metrics_daily` - Global product metrics
  - `fct_account_metrics_daily` - Account-level health metrics
  - `fct_user_metrics_daily` - User-level behavioral metrics
  - `fct_sessions` - Session-level engagement data
  - `dim_accounts` - Master account dimension table
  - `dim_users` - Master user dimension table

### Step 9: Verify the Results

**In Snowflake:**

```sql
SELECT * FROM YOUR_SCHEMA.fct_product_metrics_daily LIMIT 10;
```

**In BigQuery:**

```sql
SELECT * FROM `YOUR_PROJECT.YOUR_DATASET.fct_product_metrics_daily` LIMIT 10;
```

### Step 10: Schedule Regular Runs (Optional)

To keep your metrics up-to-date:

1. **Use dbt Cloud** (easiest - has a visual scheduler)
2. **Set up a cron job** (Linux/Mac):

   ```bash
   # Edit crontab
   crontab -e

   # Add this line to run daily at 6 AM
   0 6 * * * cd /path/to/growthcues-core && dbt run
   ```

3. **Use GitHub Actions** - See [dbt GitHub Actions guide](https://docs.getdbt.com/docs/deploy/github-actions)
4. **Use Airflow, Prefect, or another orchestration tool**

---

## Which Installation Method Should I Use?

| Factor                 | Package (Method 1)                       | Template (Method 2)                             |
| :--------------------- | :--------------------------------------- | :---------------------------------------------- |
| **Ease of Updates**    | ✅ Easy (`dbt deps`)                     | ❌ Manual (pull from GitHub)                    |
| **Code Customization** | ❌ Limited (via variables only)          | ✅ Full control (edit SQL directly)             |
| **Code Separation**    | ✅ Clean (package in `dbt_packages/`)    | ❌ Mixed (all code in your project)             |
| **Version Management** | ✅ Pin versions in `packages.yml`        | ⚠️ Manual (use git tags/branches)               |
| **Best For**           | Production use, standard implementations | Custom business logic, deep customization needs |

**Recommendation:** Start with **Method 1 (Package)** unless you know you'll need extensive SQL customization.

---

## Next Steps

- **Configure advanced features:** See [Configuration Guide](CONFIGURATION.md)
- **Understand the metrics:** Check [METRICS.md](../METRICS.md)
- **Learn about identity stitching:** Read [Identity Stitching Guide](IDENTITY_STITCHING.md)
- **Understand sessionization:** See [Sessionization Guide](SESSIONIZATION.md)
- **Having issues?** Check [Troubleshooting](TROUBLESHOOTING.md) or [FAQ](FAQ.md)
- **Want to contribute?** See [CONTRIBUTING.md](../CONTRIBUTING.md)
