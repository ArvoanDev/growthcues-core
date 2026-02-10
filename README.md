# GrowthCues Core

**The Open Source Semantic Layer for B2B SaaS.**

A dbt project to calculate **Account-Level** and **Product-Level** metrics from Segment/Rudderstack data using the **Segment B2B SaaS spec**. Includes AI-ready schema context for LLMs, agentic analytics, and self-serve GTM insights.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![dbt](https://img.shields.io/badge/dbt-1.0%2B-orange) ![Snowflake](https://img.shields.io/badge/Snowflake-Compatible-blue) ![BigQuery](https://img.shields.io/badge/BigQuery-Compatible-blue)

---

## 📖 What is this?

**GrowthCues Core** is an open-source dbt project that acts as the foundational semantic layer for Product-Led Growth (PLG) teams in B2B SaaS organizations.

👉 **Tutorial:** [Building Self-Serve GTM Analytics with Claude, BigQuery, dbt, and MCP](https://growthcues.com/blog/self-serve-analytics-claude-mcp/)

Most analytics tools focus only on Users. B2B businesses need to track **Accounts**. This project handles both.

### Seven Core Tables

It produces seven critical tables in your warehouse:

1. **`fct_product_metrics_daily`** - Global DAU/WAU/MAU and Account volume (DAA/WAA/MAA) with velocity trends
2. **`fct_account_metrics_daily`** - Account-level health metrics: stickiness, feature breadth, churn risk, health scoring
3. **`fct_account_feature_usage_monthly`** - Feature-level adoption and penetration tracking per account
4. **`fct_user_metrics_daily`** - User-level behavior: champions, admin proxy flags, lifecycle status
5. **`fct_sessions`** - Sessionized engagement data with duration and event counts
6. **`dim_accounts`** - Master account dimension table
7. **`dim_users`** - Master user dimension table

See **[METRICS.md](METRICS.md)** for complete definitions and formulas.

---

## 🚀 Features

- **Warehouse Native** - Runs entirely on Snowflake or BigQuery. No data leaves your infrastructure
- **B2B Standard** - Compatible with Segment/Rudderstack. Requires `context_group_id` for account identification (customizable)
- **Identity Stitching** - Links anonymous visitor activity to authenticated users for complete customer journey visibility. [Learn more →](docs/IDENTITY_STITCHING.md)
- **Smart Sessionization** - Groups events into meaningful sessions with configurable timeout windows. [Learn more →](docs/SESSIONIZATION.md)
- **Feature-Level Analysis** - Track which specific features each account uses, adoption rates, and abandonment patterns
- **Health Scoring** - Pre-computed health segments and 0-100 composite scores for prioritizing CS/sales outreach
- **Three-Level Granularity** - Metrics at Product, Account, and User levels
- **AI-Ready Schema** - Specialized documentation designed to ground LLMs and prevent hallucinations

---

## 🛠 Quick Start

### Prerequisites

- dbt Core (v1.0+) or dbt Cloud
- Python 3.10+
- Snowflake or BigQuery warehouse
- Segment/Rudderstack data following the **Segment B2B SaaS spec**

---

### Installation

**Method 1: dbt Package (Recommended)** _[Coming to dbt Hub soon!]_

For now, install via Git:

```yaml
# packages.yml
packages:
  - git: "https://github.com/growthcues/growthcues-core.git"
    revision: main
```

```bash
dbt deps
```

Once published on dbt Hub, you'll use:

```yaml
packages:
  - package: growthcues/growthcues_core
    version: 1.0.0
```

**Method 2: Clone as Template**

```bash
git clone https://github.com/growthcues/growthcues-core.git
cd growthcues-core
dbt deps
```

📖 **Detailed instructions:** [Installation Guide →](docs/INSTALLATION.md)

---

### Configuration

Configure data sources in `dbt_project.yml`:

```yaml
vars:
  growthcues_core: # Omit if using template method
    segment_database: "YOUR_DATABASE"
    segment_schema: "YOUR_SCHEMA"

    # Optional customizations
    # session_timeout_minutes: 30
    # enable_identity_stitching: true
```

⚙️ **All configuration options:** [Configuration Guide →](docs/CONFIGURATION.md)

---

### Run

```bash
# Using Make (recommended)
make setup
make build

# Or using dbt directly
dbt run
dbt test
```

📊 **Query your metrics:**

```sql
-- Snowflake
SELECT * FROM your_schema.fct_product_metrics_daily LIMIT 10;

-- BigQuery
SELECT * FROM `your_project.your_dataset.fct_product_metrics_daily` LIMIT 10;
```

---

## 📚 Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Complete installation instructions for both methods
- **[Configuration Guide](docs/CONFIGURATION.md)** - All configuration options and performance tuning
- **[Metrics Reference](METRICS.md)** - Complete metrics definitions with formulas and context
- **[Identity Stitching](docs/IDENTITY_STITCHING.md)** - How anonymous visitor tracking works
- **[Sessionization](docs/SESSIONIZATION.md)** - Understanding session calculation logic
- **[Unit Tests](models/UNIT_TESTS.md)** - Testing framework and development guide
- **[FAQ](docs/FAQ.md)** - Frequently asked questions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Contributing](CONTRIBUTING.md)** - How to contribute to the project

---

## 🤖 Using with AI Agents

The hardest part of "Self-Serve Analytics" is that AI agents often hallucinate because they don't understand your business context.

This project includes **AI-Ready Documentation** with clear definitions, formulas, and context:

1. Copy the content from [models/marts/core/schema.yml](models/marts/core/schema.yml) or [METRICS.md](METRICS.md)
2. Paste it into ChatGPT/Claude with this prompt:

   > "You are a Data Analyst. Here is the metrics documentation for our B2B SaaS data warehouse. Use this context to answer my questions without hallucinating.
   >
   > [PASTE DOCUMENTATION HERE]
   >
   > Question: Which accounts are currently at risk of churning?"

3. The AI will generate accurate SQL based on your specific business logic.

---

## ✨🔮 About GrowthCues

This repository handles the **Descriptive Layer** of your GTM stack (answering "what happened?") and is **100% open source**. It contains the foundational metrics every B2B SaaS company needs.

### Want to go further?

Do you want to track user or customer journeys, or predict account behavior for sales/CS teams?

I have built **GrowthCues** as a headless semantic layer for B2B SaaS that runs on top of the same warehouse-native architecture (Snowflake and BigQuery) but adds:

- **No-Code Journey Modeling** - Define complex milestones (e.g., "Onboarding Complete") and journey completion scores without writing SQL

- **Predictive Scoring** - AI-generated "Likelihood to Convert" and "Likelihood to Churn" scores

- **Advanced Trends** - Detects true trajectory using linear regression and complex windowing (vs. simplified linear velocity in this repo). Benefit: outliers don't skew your trend analysis.

- **Compute Savings** - Calculations run on the GrowthCues engine, eliminating daily compute costs on your Snowflake/BigQuery warehouse

- **AI Ready** - Auto-generated dbt schema optimized for LLMs to prevent hallucinations, including metrics for customer journeys and predictions

👉 **Learn more:** [growthcues.com](https://growthcues.com)

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Contributing

Contributions are welcome! When submitting PRs:

1. Add unit tests for new transformation logic
2. Update documentation in schema.yml files
3. Run `make test` to ensure all tests pass
4. Run `make docs-generate` to verify documentation builds

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
