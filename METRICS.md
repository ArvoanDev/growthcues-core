# 📊 B2B SaaS Metrics Dictionary

This document serves as the **Data Dictionary** for the GrowthCues Core semantic layer.

These definitions are compatible with the GrowthCues "AI-Ready" standard, optimized to prevent LLM hallucinations.

## 1. Global Product Metrics (`fct_product_metrics_daily`)

**Description:** Aggregates activity across your _entire_ customer base.

**Grain:** One row per Date.

| Metric    | Definition                                                                   |
| :-------- | :--------------------------------------------------------------------------- |
| **`dau`** | **Global Daily Active Users.** Unique humans active today.                   |
| **`wau`** | **Global Weekly Active Users.** Unique humans active in last 7 days.         |
| **`mau`** | **Global Monthly Active Users.** Unique humans active in last 30 days.       |
| **`daa`** | **Global Daily Active Accounts.** Unique companies active today.             |
| **`waa`** | **Global Weekly Active Accounts.** Unique companies active in last 7 days.   |
| **`maa`** | **Global Monthly Active Accounts.** Unique companies active in last 30 days. |

_Note: All Global Metrics include 7, 14, and 30-day velocity trends (e.g., `dau_trend_7d`)._

## 2. Account Health Metrics (`fct_account_metrics_daily`)

**Description:** Granular, account-by-account health metrics.

**Grain:** One row per Account per Date.

### Core Metrics

| Column Name                    | Type    | Definition                                                    | Context                                   |
| :----------------------------- | :------ | :------------------------------------------------------------ | :---------------------------------------- |
| **`metric_date`**              | Date    | Calendar date.                                                |                                           |
| **`account_id`**               | String  | Unique Account ID.                                            |                                           |
| **`dau`**                      | Integer | **Account DAU.** Active users in this account today.          | Daily seat usage.                         |
| **`wau`**                      | Integer | **Account WAU.** Active users in this account (Last 7 Days).  | Weekly seat usage.                        |
| **`mau`**                      | Integer | **Account MAU.** Active users in this account (Last 30 Days). | Monthly seat usage.                       |
| **`is_active_daily`**          | Flag    | 1 if DAU > 0.                                                 |                                           |
| **`is_active_weekly`**         | Flag    | 1 if WAU > 0.                                                 |                                           |
| **`is_active_monthly`**        | Flag    | 1 if MAU > 0.                                                 |                                           |
| **`account_stickiness_ratio`** | Float   | **Usage Frequency.** (Active Days / 7).                       | 1.0 = Uses product daily.                 |
| **`user_stickiness_ratio`**    | Float   | **User Depth.** (DAU / MAU).                                  | Measures habit formation within the team. |
| **`is_dormant_risk`**          | Flag    | **Churn Risk.** (MAU > 0 AND WAU = 0).                        | Account stopped using product this week.  |

### Account Trends (Velocity)

_Formula: `(Current - Lagged) / Days`. Represents average net daily growth for this specific account._

| Metric           | 7-Day Trend    | 14-Day Trend    | 30-Day Trend    |
| :--------------- | :------------- | :-------------- | :-------------- |
| **DAU Velocity** | `dau_trend_7d` | `dau_trend_14d` | `dau_trend_30d` |
| **WAU Velocity** | `wau_trend_7d` | `wau_trend_14d` | `wau_trend_30d` |
| **MAU Velocity** | `mau_trend_7d` | `mau_trend_14d` | `mau_trend_30d` |

## 3. Account Dimensions (`dim_accounts`)

**Description:** Master record of every company.

**Grain:** One row per Account.

| Column Name                 | Definition                                                        |
| :-------------------------- | :---------------------------------------------------------------- |
| **`account_id`**            | Unique Account ID.                                                |
| **`current_active_seats`**  | **Current Seats Proxy.** Unique users active in the last 30 days. |
| **`lifetime_unique_users`** | Total users ever seen for this account.                           |
| **`days_since_last_seen`**  | Days since last activity. >30 indicates Churn.                    |
