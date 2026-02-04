-- models/marts/core/fct_account_metrics_daily.sql
{{ config(
    materialized='table'
) }}

with 

-- 1. Flatten tracks to User + Account + Date + Event Type
daily_activity_granularity as (
    select
        cast(event_at as date) as activity_date,
        account_id,
        user_id,
        event_name -- Crucial for Feature Breadth
    from {{ ref('stg_segment_tracks') }}
    group by 1, 2, 3, 4
),

accounts as ( select account_id, first_seen_at from {{ ref('dim_accounts') }} ),

date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2023-01-01' as date)", 
        end_date="current_date"
    ) }}
),

account_spine as (
    select
        d.date_day as metric_date,
        a.account_id
    from date_spine d
    cross join accounts a
    where d.date_day >= cast(a.first_seen_at as date)
),

rolling_metrics as (
    select
        s.metric_date,
        s.account_id,

        -- CORE VOLUME
        count(*) as n_events_daily, -- Total volume today (approximation from granular)
        
        -- ACTIVE USERS
        count(distinct case when g.activity_date = s.metric_date then g.user_id end) as dau,
        count(distinct case when g.activity_date > {{ dbt.dateadd('day', -7, 's.metric_date') }} then g.user_id end) as wau,
        count(distinct g.user_id) as mau,

        -- FEATURE BREADTH (How many unique things are they doing?)
        -- A proxy for "Product Depth"
        count(distinct case when g.activity_date > {{ dbt.dateadd('day', -30, 's.metric_date') }} then g.event_name end) as distinct_features_used_30d,

        -- STICKINESS FREQUENCY
        count(distinct case when g.activity_date > {{ dbt.dateadd('day', -7, 's.metric_date') }} then g.activity_date end) as active_days_7d
        count(distinct case when g.activity_date > {{ dbt.dateadd('day', -30, 's.metric_date') }} then g.activity_date end) as active_days_30d

    from account_spine s
    left join daily_activity_granularity g
        on g.account_id = s.account_id
        and g.activity_date > {{ dbt.dateadd('day', -30, 's.metric_date') }}
        and g.activity_date <= s.metric_date
    group by 1, 2
),

trends_calculation as (
    select
        *,
        -- Lags for Velocity Calculation
        lag(dau, 7) over (partition by account_id order by metric_date) as dau_lag_7,
        lag(dau, 14) over (partition by account_id order by metric_date) as dau_lag_14,
        lag(dau, 30) over (partition by account_id order by metric_date) as dau_lag_30,

        lag(wau, 7) over (partition by account_id order by metric_date) as wau_lag_7,
        lag(wau, 14) over (partition by account_id order by metric_date) as wau_lag_14,
        lag(wau, 30) over (partition by account_id order by metric_date) as wau_lag_30,

        lag(mau, 7) over (partition by account_id order by metric_date) as mau_lag_7,
        lag(mau, 14) over (partition by account_id order by metric_date) as mau_lag_14,
        lag(mau, 30) over (partition by account_id order by metric_date) as mau_lag_30,

        lag(n_events_daily, 7) over (partition by account_id order by metric_date) as volume_lag_7,
        
        -- For Volumetric Churn calculation (Sum of events last 7 days)
        sum(n_events_daily) over (partition by account_id order by metric_date rows between 6 preceding and current row) as volume_7d
    from rolling_metrics
)

select
    metric_date,
    account_id,
    
    dau, wau, mau,
    
    -- Convenience Flags
    case when dau > 0 then 1 else 0 end as is_active_daily,
    case when wau > 0 then 1 else 0 end as is_active_weekly,
    case when mau > 0 then 1 else 0 end as is_active_monthly,

    distinct_features_used_30d,
    
    -- GTM SIGNALS -------------------------
    
    -- 1. Expansion Signal: Weekly Seat Velocity
    (wau - wau_lag_7) as net_new_users_7d,

    -- 2. Churn Signal: Usage Contraction
    case 
        when lag(volume_7d, 7) over (partition by account_id order by metric_date) > 0 
        then round(volume_7d / nullif(lag(volume_7d, 7) over (partition by account_id order by metric_date),0), 2)
        else 1 
    end as volume_change_ratio_7d,

    -- Standard Ratios
    round(active_days_7d / active_days_30d, 2) as account_stickiness_ratio,
    case when mau > 0 then round(dau / mau, 2) else 0 end as user_stickiness_ratio,
    case when mau > 0 and wau = 0 then 1 else 0 end as is_dormant_risk,

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

from trends_calculation