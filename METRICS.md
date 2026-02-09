# 📊 B2B SaaS Metrics Dictionary

This document serves as the **Data Dictionary** for the GrowthCues Core semantic layer.

These definitions are compatible with the GrowthCues "AI-Ready" standard, optimized to prevent LLM hallucinations.

## 1. Global Product Metrics (`fct_product_metrics_daily`)

**Description:** Aggregates activity across your _entire_ customer base.

**Grain:** One row per Date.

| Metric              | Definition                                                                   |
| :------------------ | :--------------------------------------------------------------------------- |
| **`dau`**           | **Global Daily Active Users.** Unique users active today.                    |
| **`wau`**           | **Global Weekly Active Users.** Unique users active in last 7 days.          |
| **`mau`**           | **Global Monthly Active Users.** Unique users active in last 30 days.        |
| **`daa`**           | **Global Daily Active Accounts.** Unique companies active today.             |
| **`waa`**           | **Global Weekly Active Accounts.** Unique companies active in last 7 days.   |
| **`maa`**           | **Global Monthly Active Accounts.** Unique companies active in last 30 days. |
| **Velocity Trends** | 7, 14, and 30-day linear trends for all metrics above.                       |

## 2. Account Health & GTM Signals Metrics (`fct_account_metrics_daily`)

**Description:** Granular, account-by-account health metrics and sales triggers.

**Grain:** One row per Account per Date.

### Core Metrics

| Column Name       | Type    | Definition                                                    | Context             |
| :---------------- | :------ | :------------------------------------------------------------ | :------------------ |
| **`metric_date`** | Date    | Calendar date.                                                |                     |
| **`account_id`**  | String  | Unique Account ID.                                            |                     |
| **`dau`**         | Integer | **Account DAU.** Active users in this account today.          | Daily seat usage.   |
| **`wau`**         | Integer | **Account WAU.** Active users in this account (Last 7 Days).  | Weekly seat usage.  |
| **`mau`**         | Integer | **Account MAU.** Active users in this account (Last 30 Days). | Monthly seat usage. |

### Volume & Depth Metrics

| Column Name                      | Type    | Definition                                                        | Context                                  |
| :------------------------------- | :------ | :---------------------------------------------------------------- | :--------------------------------------- |
| **`n_events_daily`**             | Integer | **Daily Event Volume.** Total events by this account today.       | Higher volume = higher engagement.       |
| **`distinct_features_used_30d`** | Integer | **Feature Breadth.** Count of unique event types in last 30 days. | More features = deeper product adoption. |
| **`active_days_7d`**             | Integer | **7-Day Frequency.** Number of days active in last 7 days.        | 5-7 days = highly engaged account.       |
| **`active_days_30d`**            | Integer | **30-Day Frequency.** Number of days active in last 30 days.      | Used in stickiness ratio calculation.    |

### Session Metrics

| Column Name                                  | Type    | Definition                                                                  | Context                                   |
| :------------------------------------------- | :------ | :-------------------------------------------------------------------------- | :---------------------------------------- |
| **`n_sessions_daily`**                       | Integer | **Daily Sessions.** Number of sessions on this date.                        | Daily session volume.                     |
| **`time_on_platform_minutes_daily`**         | Float   | **Daily Time.** Total time on platform on this date in minutes.             | Daily engagement depth.                   |
| **`n_sessions_7d`**                          | Integer | **7-Day Sessions.** Total sessions in last 7 days.                          | Short-term session frequency.             |
| **`time_on_platform_minutes_7d`**            | Float   | **7-Day Time.** Total time on platform in last 7 days in minutes.           | Weekly engagement depth.                  |
| **`n_sessions_30d`**                         | Integer | **30-Day Sessions.** Total sessions in last 30 days.                        | Monthly session frequency.                |
| **`time_on_platform_minutes_30d`**           | Float   | **30-Day Time.** Total time on platform in last 30 days in minutes.         | Monthly engagement depth.                 |
| **`avg_daily_sessions_7d`**                  | Float   | **Avg Daily Sessions (7d).** Average sessions per active day (7d window).   | Session intensity. >1 = multiple per day. |
| **`avg_daily_sessions_30d`**                 | Float   | **Avg Daily Sessions (30d).** Average sessions per active day (30d window). | Sustained session intensity.              |
| **`avg_daily_time_on_platform_minutes_7d`**  | Float   | **Avg Daily Time (7d).** Average time per active day in minutes (7d).       | Daily engagement intensity.               |
| **`avg_daily_time_on_platform_minutes_30d`** | Float   | **Avg Daily Time (30d).** Average time per active day in minutes (30d).     | Sustained daily engagement depth.         |

### Flags & Ratios

| Column Name                    | Type  | Definition                                               | Context                                       |
| :----------------------------- | :---- | :------------------------------------------------------- | :-------------------------------------------- |
| **`is_active_daily`**          | Flag  | 1 if DAU > 0.                                            |                                               |
| **`is_active_weekly`**         | Flag  | 1 if WAU > 0.                                            |                                               |
| **`is_active_monthly`**        | Flag  | 1 if MAU > 0.                                            |                                               |
| **`account_stickiness_ratio`** | Float | **Usage Frequency.** (active_days_7d / active_days_30d). | 1.0 = Uses product daily. <0.15 = Churn Risk. |
| **`user_stickiness_ratio`**    | Float | **User Depth.** (DAU / MAU).                             | Measures habit formation within the team.     |
| **`is_dormant_risk`**          | Flag  | **Churn Risk.** 1 if MAU > 0 AND WAU = 0.                | Early warning for churn.                      |

### Account Trends (Velocity)

_Formula: `(Current - Lagged) / Days`. Represents average net daily growth for this specific account._

| Metric           | 7-Day Trend    | 14-Day Trend    | 30-Day Trend    |
| :--------------- | :------------- | :-------------- | :-------------- |
| **DAU Velocity** | `dau_trend_7d` | `dau_trend_14d` | `dau_trend_30d` |
| **WAU Velocity** | `wau_trend_7d` | `wau_trend_14d` | `wau_trend_30d` |
| **MAU Velocity** | `mau_trend_7d` | `mau_trend_14d` | `mau_trend_30d` |

### GTM Signals

| Column                                | Definition                                                       | Use Case                                                           |
| :------------------------------------ | :--------------------------------------------------------------- | :----------------------------------------------------------------- |
| **net_new_users_7d**                  | **Expansion Signal.** Change in active seats vs. last week.      | **Sales:** Identify accounts adding users rapidly.                 |
| **volume_change_ratio_7d**            | **Churn Signal.** Ratio of Event Volume (Last 7d / Prev 7d).     | **Success:** Detect sharp drops in usage intensity (\<0.5).        |
| **time_on_platform_change_ratio_7d**  | **Churn Signal.** Ratio of Time on Platform (Last 7d / Prev 7d). | **Success:** Detect declining engagement depth (\<0.5).            |
| **session_frequency_change_ratio_7d** | **Churn Signal.** Ratio of Session Count (Last 7d / Prev 7d).    | **Success:** Detect users opening product less frequently (\<0.5). |

## 3. User Metrics & Champions (`fct_user_metrics_daily`)

**Description:** Snapshot of individual user behavior.  
**Grain:** One row per User (Latest Snapshot).

### Core User Metrics

| Column                                     | Type    | Definition                                                                 | Context                                           |
| :----------------------------------------- | :------ | :------------------------------------------------------------------------- | :------------------------------------------------ |
| **`metric_date`**                          | Date    | Snapshot date.                                                             | Latest date for this user.                        |
| **`user_id`**                              | String  | Unique User ID.                                                            | Primary identifier.                               |
| **`latest_account_id`**                    | String  | Most recent Account ID.                                                    | Connects user to their organization.              |
| **`n_events_daily`**                       | Integer | Events performed on snapshot date.                                         | Daily usage volume.                               |
| **`n_events_monthly`**                     | Integer | **30-Day Volume.** Total events in last 30 days.                           | Measures overall activity. Used for ranking.      |
| **`is_active_daily`**                      | Flag    | 1 if user was active on snapshot date.                                     |                                                   |
| **`is_active_weekly`**                     | Flag    | 1 if user was active in last 7 days.                                       |                                                   |
| **`is_active_monthly`**                    | Flag    | 1 if user was active in last 30 days.                                      |                                                   |
| **`active_days_last_7`**                   | Integer | **L7 Frequency.** Days active in last 7 days.                              | 3+ indicates a "Power User".                      |
| **`active_days_last_14`**                  | Integer | **L14 Frequency.** Days active in last 14 days.                            | **Champions:** 10+ days = highly engaged user.    |
| **`n_sessions_daily`**                     | Integer | **Daily Sessions.** Number of sessions started on this day.                | Measures distinct usage sessions.                 |
| **`n_sessions_monthly`**                   | Integer | **Monthly Sessions.** Total sessions in last 30 days.                      | Higher counts = more frequent engagement.         |
| **`avg_session_duration_minutes_monthly`** | Float   | **Avg Session Time.** Average session length in minutes over last 30 days. | Longer sessions = deeper engagement.              |
| **`avg_session_length_monthly`**           | Float   | **Avg Session Intensity.** Average events per session over last 30 days.   | More events per session = higher intensity usage. |

### GTM Signals

| Column                         | Definition                                         | Use Case                                               |
| :----------------------------- | :------------------------------------------------- | :----------------------------------------------------- |
| **usage_rank_in_account**      | **Champion Signal.** Rank by monthly volume.       | **Marketing:** Identify Rank 1 users for case studies. |
| **is_admin_proxy**             | **Buyer Signal.** First user ever seen in account. | **Sales:** Target for renewal discussions.             |
| **distinct_features_used_30d** | **Sophistication.** Unique features used.          | **Product:** Identify power users.                     |
| **user_lifecycle_status**      | New, Active, Dormant, Resurrected, Churned.        | **Growth:** Retention analysis.                        |

## 4. Session Engagement Metrics (`fct_sessions`)

**Description:** Sessionized event data showing engagement patterns.  
**Grain:** One row per User Session.

**A session is a sequence of events by the same user with no more than 30 minutes (configurable via `session_timeout_minutes` variable) of inactivity between events.**

### Core Session Metrics

| Column                         | Type      | Definition                        | Context                                                |
| :----------------------------- | :-------- | :-------------------------------- | :----------------------------------------------------- |
| **`session_id`**               | String    | Unique session identifier.        | Primary key for the sessions table.                    |
| **`user_id`**                  | String    | User who performed the session.   | Links sessions back to users.                          |
| **`account_id`**               | String    | Account the session belongs to.   | Links sessions to accounts/companies.                  |
| **`session_start_at`**         | Timestamp | When the session started.         | Table partitioned by this field.                       |
| **`session_end_at`**           | Timestamp | When the session ended.           | Used to calculate duration.                            |
| **`session_duration_seconds`** | Integer   | Length of session in seconds.     | Single-event sessions = 0. Longer = deeper engagement. |
| **`events_in_session`**        | Integer   | Number of events in this session. | Power users have more events per session.              |

## 5. Dimensions

### Account Dimensions (`dim_accounts`)

**Description:** Master record of every company.

**Grain:** One row per Account.

| Column Name                 | Definition                                                        |
| :-------------------------- | :---------------------------------------------------------------- |
| **`account_id`**            | Unique Account ID.                                                |
| **`first_seen_at`**         | Timestamp of first event for this account.                        |
| **`last_seen_at`**          | Timestamp of most recent event for this account.                  |
| **`current_active_seats`**  | **Current Seats Proxy.** Unique users active in the last 30 days. |
| **`lifetime_unique_users`** | Total users ever seen for this account.                           |
| **`days_since_first_seen`** | Account age in days.                                              |
| **`days_since_last_seen`**  | Days since last activity. >30 indicates Churn.                    |

### User Dimensions (`dim_users`)

**Description:** Master record of every user.
**Grain:** One row per User.

| Column Name                      | Definition                                            |
| :------------------------------- | :---------------------------------------------------- |
| **`user_id`**                    | Unique User ID.                                       |
| **`first_seen_at`**              | Timestamp of first event for this user.               |
| **`last_seen_at`**               | Timestamp of most recent event for this user.         |
| **`lifetime_accounts_distinct`** | Number of unique accounts this user has engaged with. |
| **`latest_account_id`**          | Most recent Account ID for this user.                 |
| **`days_since_first_seen`**      | User tenure in days.                                  |
| **`days_since_last_seen`**       | Days since last activity. >30 indicates Churn.        |

## 6. Notes

- All definitions assume a standard activity event log with `user_id`, `account_id`, and `event_timestamp`.
- Adjust definitions as needed to fit your specific product and data model.
- For implementation, use dbt to create models based on these definitions.
