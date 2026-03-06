# Guide: How to Build an Expansion Alert Bot for Your AEs

Dashboards are where data goes to die. We spend weeks building beautiful BI views, but reps don't live in Looker—they live in Slack. If your Sales team is waiting for a monthly report to find expansion opportunities, they are already too late.

You don't need a heavy Customer Success Platform or a five-figure Reverse ETL tool to fix this. You can build a "Headless" expansion monitor for $0 using tools you already have: **BigQuery** and **GitHub Actions**.

---

## The Concept: "Headless" Revenue Architecture

Instead of relying on a human to spot a positive spike in account activity, we build a system that polls your warehouse every morning and pushes high-intent signals directly to your reps.

1. **The Brain (BigQuery):** Your warehouse stores your modeled product metrics.
2. **The Worker (GitHub Actions):** A free, cloud-hosted "Cron job" runs a script every morning.
3. **The Messenger (Slack):** A Python script posts a high-priority alert to your Sales channel.

---

## Step 1: Define the Signal

To build the bot, we first need a signal. In my open-source semantic layer, **growthcues-core**, I calculate a baseline metric called `volume_change_ratio_7d`.

- **1.0**: Stable usage.
- **0.5**: Churn risk (usage dropped by half).
- **1.5**: Expansion signal (usage grew by 50% week-over-week).

While `volume_change_ratio_7d` is a great starter signal, true "Whale" detection usually requires deeper logic, like identifying when a team starts using multi-player features or hits a specific seat-velocity threshold.

---

## Step 2: The Logic (SQL)

The bot runs a simple query against your `fct_account_metrics_daily` table. We want to find accounts where the growth is explosive.

SQL

```
SELECT
    account_id,
    volume_change_ratio_7d,
    wau -- Weekly Active Users
FROM `your_project.your_dataset.fct_account_metrics_daily`
WHERE metric_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND volume_change_ratio_7d > 1.5 -- Usage spiked >50%
  AND wau >= 5 -- Focus on meaningful team sizes
ORDER BY volume_change_ratio_7d DESC
LIMIT 5
```

---

## Step 3: Automate the Execution

We use **GitHub Actions** to trigger this query every morning at 8:00 AM. In this repository, the files are:

- Python script: `examples/expansion-signals/expansion_signal.py`
- Workflow template: `examples/expansion-signals/expansion_signal.yml` (workflow name: **Daily Expansion Signal**)

Copy the workflow template to `.github/workflows/expansion_signal.yml` in your repo to activate it.

By using GitHub’s free tier, you bypass the need for a dedicated server or expensive GTM automation tools.

---

## The Payoff: From Passive to Proactive

Once this is live, your AEs stop "hunting" and start "responding". They get a daily hit-list of accounts that are actively leaning into the product right now.

## Want to go beyond baseline signals?

The $0 expansion alert bot is excellent for catching simple volume spikes, but at the scale of **€10M–€100M ARR**, your biggest expansion opportunities are often hidden in complex behavioral patterns.

I help B2B scaleups deploy **The Expansion Engine**: a 4-week architectural sprint where I mathematically discover your specific "Whale Signals" and build the governed PQA (Product Qualified Account) scoring models your data team will love and your sales team will actually use.

**[See how The Expansion Engine works](https://arvoan.com/services)**
