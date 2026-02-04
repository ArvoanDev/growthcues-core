-- models/marts/core/fct_product_metrics_daily.sql
{{ config(
    materialized='table'
) }}

with tracks as (
    select * from {{ ref('stg_segment_tracks') }}
),

date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2023-01-01' as date)", 
        end_date="current_date"
    ) }}
),

-- Efficiently calculate rolling windows by joining the spine to tracks
-- We join tracks that occurred within the 30-day lookback window of each spine date
-- Replaced standard SQL interval with dbt.dateadd for compatibility
rolling_activity as (
    select
        d.date_day as metric_date,
        t.user_id,
        t.account_id,
        cast(t.event_at as date) as event_date
    from date_spine d
    inner join tracks t
        on cast(t.event_at as date) > {{ dbt.dateadd('day', -30, 'd.date_day') }}
        and cast(t.event_at as date) <= d.date_day
),

base_metrics as (
    select
        metric_date,
        -- Daily Metrics
        count(distinct case when event_date = metric_date then user_id end) as dau,
        count(distinct case when event_date = metric_date then account_id end) as daa,
        -- Weekly Metrics (Last 7 Days)
        count(distinct case when event_date > {{ dbt.dateadd('day', -7, 'metric_date') }} then user_id end) as wau,
        count(distinct case when event_date > {{ dbt.dateadd('day', -7, 'metric_date') }} then account_id end) as waa,
        -- Monthly Metrics (Last 30 Days)
        -- Since rolling_activity is already filtered to 30 days, count(*) is MAU
        count(distinct user_id) as mau,
        count(distinct account_id) as maa
    from rolling_activity
    group by 1
),

metrics_with_lags as (
    select 
        *,
        -- Lags for Trend Calculation
        lag(dau, 7) over (order by metric_date) as dau_lag_7,
        lag(dau, 14) over (order by metric_date) as dau_lag_14,
        lag(dau, 30) over (order by metric_date) as dau_lag_30,
        
        lag(wau, 7) over (order by metric_date) as wau_lag_7,
        lag(wau, 14) over (order by metric_date) as wau_lag_14,
        lag(wau, 30) over (order by metric_date) as wau_lag_30,

        lag(mau, 7) over (order by metric_date) as mau_lag_7,
        lag(mau, 14) over (order by metric_date) as mau_lag_14,
        lag(mau, 30) over (order by metric_date) as mau_lag_30,

        lag(daa, 7) over (order by metric_date) as daa_lag_7,
        lag(daa, 14) over (order by metric_date) as daa_lag_14,
        lag(daa, 30) over (order by metric_date) as daa_lag_30,

        lag(waa, 7) over (order by metric_date) as waa_lag_7,
        lag(waa, 14) over (order by metric_date) as waa_lag_14,
        lag(waa, 30) over (order by metric_date) as waa_lag_30,

        lag(maa, 7) over (order by metric_date) as maa_lag_7,
        lag(maa, 14) over (order by metric_date) as maa_lag_14,
        lag(maa, 30) over (order by metric_date) as maa_lag_30
    from base_metrics
)

select
    metric_date,
    -- Core Metrics
    dau, wau, mau,
    daa, waa, maa,
    -- Ratios
    case when mau > 0 then round(dau / mau, 2) else 0 end as user_stickiness_ratio,
    case when maa > 0 then round(daa / maa, 2) else 0 end as account_stickiness_ratio,
    
    -- Linear Trends (Velocity)
    round((dau - dau_lag_7) / 7.0, 2) as dau_trend_7d,
    round((dau - dau_lag_14) / 14.0, 2) as dau_trend_14d,
    round((dau - dau_lag_30) / 30.0, 2) as dau_trend_30d,

    round((wau - wau_lag_7) / 7.0, 2) as wau_trend_7d,
    round((wau - wau_lag_14) / 14.0, 2) as wau_trend_14d,
    round((wau - wau_lag_30) / 30.0, 2) as wau_trend_30d,

    round((mau - mau_lag_7) / 7.0, 2) as mau_trend_7d,
    round((mau - mau_lag_14) / 14.0, 2) as mau_trend_14d,
    round((mau - mau_lag_30) / 30.0, 2) as mau_trend_30d,

    round((daa - daa_lag_7) / 7.0, 2) as daa_trend_7d,
    round((daa - daa_lag_14) / 14.0, 2) as daa_trend_14d,
    round((daa - daa_lag_30) / 30.0, 2) as daa_trend_30d,

    round((waa - waa_lag_7) / 7.0, 2) as waa_trend_7d,
    round((waa - waa_lag_14) / 14.0, 2) as waa_trend_14d,
    round((waa - waa_lag_30) / 30.0, 2) as waa_trend_30d,

    round((maa - maa_lag_7) / 7.0, 2) as maa_trend_7d,
    round((maa - maa_lag_14) / 14.0, 2) as maa_trend_14d,
    round((maa - maa_lag_30) / 30.0, 2) as maa_trend_30d
from metrics_with_lags