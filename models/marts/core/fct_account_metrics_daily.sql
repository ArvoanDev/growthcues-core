{{ config(materialized = 'table') }} with -- 1. Flatten tracks to User + Account + Date (Reduces granularity for join)
user_daily_activity as (
  select
    cast(event_at as date) as activity_date,
    account_id,
    user_id
  from
    {{ ref('stg_segment_tracks') }}
  group by
    1,
    2,
    3
),
-- 2. Get all accounts to build the spine
accounts as (
  select
    account_id,
    first_seen_at
  from
    {{ ref('dim_accounts') }}
),
-- 3. Generate date spine
date_spine as (
  {{ dbt_utils.date_spine(
    datepart = "day",
    start_date = "cast('2024-01-01' as date)",
    end_date = "current_date"
  ) }}
),
-- 4. Create Account x Date Spine (Only for days the account existed)
account_spine as (
  select
    d.date_day as metric_date,
    a.account_id
  from
    date_spine d
    cross join accounts a
  where
    d.date_day >= cast(a.first_seen_at as date)
),
-- 5. Rolling Join to calculate Windowed Metrics (Expensive but accurate)
rolling_metrics as (
  select
    s.metric_date,
    s.account_id,
    -- DAU: Active Users Today
    count(
      distinct case
        when u.activity_date = s.metric_date then u.user_id
      end
    ) as dau,
    -- WAU: Active Users Last 7 Days
    count(
      distinct case
        when u.activity_date > {{ dbt.dateadd(datepart='day', interval=-7, from_date_or_timestamp='s.metric_date') }} then u.user_id
      end
    ) as wau,
    -- MAU: Active Users Last 30 Days
    count(distinct u.user_id) as mau,
    -- Active Days (Frequency) for Stickiness
    count(
      distinct case
        when u.activity_date > {{ dbt.dateadd(datepart='day', interval=-7, from_date_or_timestamp='s.metric_date') }} then u.activity_date
      end
    ) as active_days_7d
  from
    account_spine s
    left join user_daily_activity u on u.account_id = s.account_id
    and u.activity_date > {{ dbt.dateadd(datepart='day', interval=-30, from_date_or_timestamp='s.metric_date') }}
    and u.activity_date <= s.metric_date
  group by
    1,
    2
),
-- 6. Calculate Trends and Ratios
final_calcs as (
  select
    *,
    -- Lags for Velocity Calculation
    lag(dau, 7) over (
      partition by account_id
      order by
        metric_date
    ) as dau_lag_7,
    lag(dau, 14) over (
      partition by account_id
      order by
        metric_date
    ) as dau_lag_14,
    lag(dau, 30) over (
      partition by account_id
      order by
        metric_date
    ) as dau_lag_30,
    lag(wau, 7) over (
      partition by account_id
      order by
        metric_date
    ) as wau_lag_7,
    lag(wau, 14) over (
      partition by account_id
      order by
        metric_date
    ) as wau_lag_14,
    lag(wau, 30) over (
      partition by account_id
      order by
        metric_date
    ) as wau_lag_30,
    lag(mau, 7) over (
      partition by account_id
      order by
        metric_date
    ) as mau_lag_7,
    lag(mau, 14) over (
      partition by account_id
      order by
        metric_date
    ) as mau_lag_14,
    lag(mau, 30) over (
      partition by account_id
      order by
        metric_date
    ) as mau_lag_30
  from
    rolling_metrics
)
select
  metric_date,
  account_id,
  -- Core Usage Metrics
  dau,
  wau,
  mau,
  -- Convenience Flags
  case
    when dau > 0 then 1
    else 0
  end as is_active_daily,
  case
    when wau > 0 then 1
    else 0
  end as is_active_weekly,
  case
    when mau > 0 then 1
    else 0
  end as is_active_monthly,
  -- Stickiness Ratios
  -- Account Frequency: How many days per week is the account active?
  round(active_days_7d / 7.0, 2) as account_stickiness_ratio,
  -- User Depth: Ratio of DAU to MAU within the account
  case
    when mau > 0 then round(dau / mau, 2)
    else 0
  end as user_stickiness_ratio,
  -- Churn Risk: Active in Month, but ZERO activity in last week
  case
    when mau > 0
    and wau = 0 then 1
    else 0
  end as is_dormant_risk,
  -- Trends (Velocity)
  round((dau - dau_lag_7) / 7.0, 2) as dau_trend_7d,
  round((dau - dau_lag_14) / 14.0, 2) as dau_trend_14d,
  round((dau - dau_lag_30) / 30.0, 2) as dau_trend_30d,
  round((wau - wau_lag_7) / 7.0, 2) as wau_trend_7d,
  round((wau - wau_lag_14) / 14.0, 2) as wau_trend_14d,
  round((wau - wau_lag_30) / 30.0, 2) as wau_trend_30d,
  round((mau - mau_lag_7) / 7.0, 2) as mau_trend_7d,
  round((mau - mau_lag_14) / 14.0, 2) as mau_trend_14d,
  round((mau - mau_lag_30) / 30.0, 2) as mau_trend_30d
from
  final_calcs