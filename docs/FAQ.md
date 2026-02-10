# Frequently Asked Questions (FAQ)

Common questions about GrowthCues Core.

---

## Installation & Setup

### Why isn't this on dbt Hub yet?

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

### Which installation method should I use?

| Factor                 | Package (Method 1)                       | Template (Method 2)                             |
| :--------------------- | :--------------------------------------- | :---------------------------------------------- |
| **Ease of Updates**    | ✅ Easy (`dbt deps`)                     | ❌ Manual (pull from GitHub)                    |
| **Code Customization** | ❌ Limited (via variables only)          | ✅ Full control (edit SQL directly)             |
| **Code Separation**    | ✅ Clean (package in `dbt_packages/`)    | ❌ Mixed (all code in your project)             |
| **Version Management** | ✅ Pin versions in `packages.yml`        | ⚠️ Manual (use git tags/branches)               |
| **Best For**           | Production use, standard implementations | Custom business logic, deep customization needs |

**Recommendation:** Start with **Method 1 (Package)** unless you know you'll need extensive SQL customization.

### Can I switch between installation methods later?

Yes, but it requires some migration:

- **From Template → Package:** Remove the cloned files, add to `packages.yml`, move variables to your `dbt_project.yml`
- **From Package → Template:** Clone the repo, remove from `packages.yml`, customize as needed

---

## Data Requirements

### What data do I need to use GrowthCues Core?

You need event data from Segment or Rudderstack following the **Segment B2B SaaS spec**:

- **`tracks` table:** Event tracking with `context_group_id` field for account identification
- **`pages` table:** Page view tracking (optional but recommended)
- **`identifies` table:** Identity resolution events (for stitching anonymous to authenticated users)
- **`users` table:** User dimension data
- **`groups` table:** Account/organization dimension data

### Can I use this with a CDP other than Segment/Rudderstack?

Yes! The models are designed to work with any CDP that follows a similar event structure. You'll need to:

1. Map your CDP's table/column names using the configuration variables
2. Ensure your data includes account context (group ID) on events
3. Test thoroughly to ensure compatibility

See [Configuration Guide](CONFIGURATION.md) for customization options.

### My Segment implementation uses `group_id` instead of `context_group_id`. Can I still use this?

Yes! Configure the field name in `dbt_project.yml`:

```yaml
vars:
  group_id_field: "group_id" # Default is "context_group_id"
```

### Do I need to have anonymous users for this to work?

No. Identity stitching is **optional and graceful**:

- If your product always requires authentication, you can disable identity stitching entirely:
  ```yaml
  vars:
    enable_identity_stitching: false
  ```
- If you have a mix of anonymous and authenticated users, identity stitching will link them automatically
- If you only have authenticated users, events simply pass through with their original `user_id`

---

## Metrics & Business Logic

### What metrics does GrowthCues Core calculate?

The project produces six core tables:

1. **`fct_product_metrics_daily`**: Global DAU/WAU/MAU, DAA/WAA/MAA, stickiness, velocity trends
2. **`fct_account_metrics_daily`**: Account-level engagement, feature breadth, stickiness, churn risk
3. **`fct_user_metrics_daily`**: User-level behavior, champions, admin proxy flags, lifecycle status
4. **`fct_sessions`**: Sessionized engagement data with duration and event counts
5. **`dim_accounts`**: Master account dimension table
6. **`dim_users`**: Master user dimension table

See [METRICS.md](../METRICS.md) for complete definitions.

### How is "Active" defined?

A user or account is considered **active** if they have at least one tracked event during the specified time window:

- **DAU/DAA:** At least 1 event today
- **WAU/WAA:** At least 1 event in the last 7 days
- **MAU/MAA:** At least 1 event in the last 30 days

### What's the difference between DAU and DAA?

- **DAU (Daily Active Users):** Count of unique **users** active today across all accounts
- **DAA (Daily Active Accounts):** Count of unique **accounts** with at least one active user today

**Example:** If Account A has 5 users who were all active today, that contributes:

- 5 to DAU (5 unique users)
- 1 to DAA (1 unique account)

### How is Stickiness calculated?

Stickiness measures usage consistency:

- **User Stickiness:** DAU / MAU (at account level or globally)
- **Account Stickiness:** active_days_7d / active_days_30d

**Interpretation:**

- 100% = users/accounts are active every single day
- 50% = users/accounts are active about half the days
- Low stickiness (<20%) = weak habit formation

### What is "Champion" status?

A **Champion** is a power user within their account:

- Highest event volume in their account during the analysis window
- Identified using rank-based logic (`usage_rank_in_account = 1`)
- Useful for identifying key users for customer success outreach

### What is "Admin Proxy" flag?

The **Admin Proxy** flag identifies the likely buyer/admin:

- The first user seen in the account (earliest `first_seen_at` timestamp)
- Serves as a proxy for the decision-maker when explicit role data isn't available
- Useful for targeting renewal and expansion conversations

---

## Sessions

### How are sessions defined?

A **session** is a continuous sequence of events by the same user with no more than **30 minutes** (configurable) of inactivity between events.

See [Sessionization Guide](SESSIONIZATION.md) for detailed explanation.

### Can I change the session timeout?

Yes! Configure it in `dbt_project.yml`:

```yaml
vars:
  session_timeout_minutes: 60 # Default: 30
```

After changing, run `dbt run --full-refresh --models fct_sessions`.

### Should I include page views in sessions?

Depends on your product:

- **Include page views (`true`):** For content-heavy products where browsing is meaningful engagement
- **Exclude page views (`false`):** For pure SaaS products where page views are just navigation noise

Configure in `dbt_project.yml`:

```yaml
vars:
  include_pages_in_sessions: false # Default: true
```

---

## Performance & Scale

### How long does it take to run?

Typical timing on a medium warehouse:

- **Initial run (full historical data):**
  - 1M events: ~2-3 minutes
  - 10M events: ~10-15 minutes
  - 100M+ events: ~30-60 minutes

- **Incremental runs (daily updates):**
  - 1M events: ~30-60 seconds
  - 10M events: ~3-5 minutes
  - 100M+ events: ~10-15 minutes

### How can I improve performance?

1. **Use incremental runs:** Avoid `--full-refresh` in production
2. **Reduce lookback windows:**
   ```yaml
   vars:
     tracks_lookback_days: 180 # Default: 365
     identity_lookback_days: 180 # Default: 365
   ```
3. **Disable identity stitching if not needed:**
   ```yaml
   vars:
     enable_identity_stitching: false
   ```
4. **Optimize warehouse size:** Test with your data volume to find the right warehouse tier

See [Configuration Guide](CONFIGURATION.md) for performance tuning options.

### What are the warehouse costs?

Costs scale with:

- **Event volume:** More events = more compute time
- **Lookback windows:** Longer windows = more data to process
- **Identity stitching:** Adds ~20-30% to staging layer compute time
- **Sessionization:** Window functions are compute-intensive

**Cost optimization strategies:**

- Use incremental runs instead of full refreshes
- Reduce lookback windows for reasonable historical coverage
- Schedule runs during off-peak hours (if warehouse charges vary by time)

---

## Development & Testing

### Can I test locally without a data warehouse?

Yes! The project includes seed data that works with DuckDB:

```bash
# Install DuckDB adapter
pip install dbt-duckdb

# Setup and run
make setup  # or: dbt deps && dbt seed --target dev
make build  # or: dbt build --target dev
```

See [INSTALLATION.md](INSTALLATION.md) for local development setup.

### How do I run tests?

```bash
# All tests (unit + data quality)
make test

# Unit tests only (fast - ~0.75 seconds)
make test-unit

# Data quality tests only
make test-data
```

See [models/UNIT_TESTS.md](../models/UNIT_TESTS.md) for testing documentation.

### Can I contribute?

Absolutely! Contributions are welcome. When submitting PRs:

1. Add unit tests for new transformation logic
2. Update documentation in schema.yml files
3. Run `make test` to ensure all tests pass
4. Run `make docs-generate` to verify documentation builds

See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed guidelines.

---

## AI & Integrations

### How do I use this with AI agents (ChatGPT/Claude)?

The project includes **AI-ready schema documentation** designed to prevent hallucinations:

1. Open `models/marts/core/schema.yml` or `METRICS.md`
2. Copy the entire file content
3. Paste it into ChatGPT/Claude with this prompt:

   > "You are a Data Analyst. Here is the metrics documentation for our B2B SaaS data warehouse, including definitions, formulas, and context. Use this context to answer my questions.
   >
   > [PASTE DOCUMENTATION HERE]
   >
   > Question: Which accounts are currently at risk of churning based on their recent usage trends?"

The AI will generate accurate SQL or answers based on the specific definitions and context provided.

### Can I sync this data to Salesforce/HubSpot?

Yes! The tables are designed to work with Reverse ETL tools:

- **Hightouch:** Connect to your warehouse and sync metrics to CRM
- **Census:** Similar workflow
- **Fivetran/Airbyte (reverse):** For custom sync workflows

**Recommended sync patterns:**

- `fct_account_metrics_daily` → Salesforce Accounts (daily health scores)
- `dim_users` with champion/admin flags → CRM Contacts
- Churn risk flags → Slack/email alerts

### What's the difference between GrowthCues Core and GrowthCues (paid product)?

**GrowthCues Core (this repo):**

- 100% open source (MIT License)
- Descriptive metrics (answers "what happened?")
- Runs entirely on your warehouse
- You manage compute and orchestration

**GrowthCues (paid product):**

- Builds on top of Core
- Adds predictive scoring (likelihood to convert/churn)
- No-code journey modeling
- Runs on GrowthCues engine (eliminates daily warehouse compute costs)
- Reverse ETL ready

See [About GrowthCues](#) in README for details.

---

## Troubleshooting

For common issues and solutions, see the [Troubleshooting Guide](TROUBLESHOOTING.md).

---

## Still Have Questions?

- **GitHub Issues:** [Open an issue](https://github.com/growthcues/growthcues-core/issues)
- **Documentation:** Check the [docs](.) folder for detailed guides
- **Community:** Join discussions in GitHub Discussions (coming soon)
