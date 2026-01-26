{{ config(
    materialized='table'
) }}

with 

tracks as (
    select * from {{ ref('stg_segment_tracks') }}
),

date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2022-01-01' as date)", 
        end_date="current_date"
    ) }}
),

-- Efficiently calculate rolling windows by joining the spine to tracks
-- We join tracks that occurred within the 30-day lookback window of each spine date
rolling_activity as (
    select
        d.date_day as metric_date,
        t.user_id,
        t.account_id,
        cast(t.event_at as date) as event_date
    from date_spine d
    inner join tracks t
        on cast(t.event_at as date) > {{ dbt.dateadd(datepart='day', interval=-30, from_date_or_timestamp='d.date_day') }}
        and cast(t.event_at as date) <= d.date_day
),

base_metrics as (
    select
        metric_date,

        -- Daily Metrics (Activity on the exact date)
        count(distinct case when event_date = metric_date then user_id end) as dau,
        count(distinct case when event_date = metric_date then account_id end) as daa,

        -- Weekly Metrics (Activity in last 7 days)
        count(distinct case when event_date > {{ dbt.dateadd(datepart='day', interval=-7, from_date_or_timestamp='metric_date') }} then user_id end) as wau,
        count(distinct case when event_date > {{ dbt.dateadd(datepart='day', interval=-7, from_date_or_timestamp='metric_date') }} then account_id end) as waa,

        -- Monthly Metrics (Activity in last 30 days)
        -- Since rolling_activity is already filtered to 30 days, count(*) is MAU
        count(distinct user_id) as mau,
        count(distinct account_id) as maa

    from rolling_activity
    group by 1
),

metrics_with_lags as (
    select 
        *,
        -- DAU Lags
        lag(dau, 7) over (order by metric_date) as dau_lag_7,
        lag(dau, 14) over (order by metric_date) as dau_lag_14,
        lag(dau, 30) over (order by metric_date) as dau_lag_30,
        
        -- WAU Lags
        lag(wau, 7) over (order by metric_date) as wau_lag_7,
        lag(wau, 14) over (order by metric_date) as wau_lag_14,
        lag(wau, 30) over (order by metric_date) as wau_lag_30,

        -- MAU Lags
        lag(mau, 7) over (order by metric_date) as mau_lag_7,
        lag(mau, 14) over (order by metric_date) as mau_lag_14,
        lag(mau, 30) over (order by metric_date) as mau_lag_30,

        -- DAA Lags
        lag(daa, 7) over (order by metric_date) as daa_lag_7,
        lag(daa, 14) over (order by metric_date) as daa_lag_14,
        lag(daa, 30) over (order by metric_date) as daa_lag_30,

        -- WAA Lags
        lag(waa, 7) over (order by metric_date) as waa_lag_7,
        lag(waa, 14) over (order by metric_date) as waa_lag_14,
        lag(waa, 30) over (order by metric_date) as waa_lag_30,

        -- MAA Lags
        lag(maa, 7) over (order by metric_date) as maa_lag_7,
        lag(maa, 14) over (order by metric_date) as maa_lag_14,
        lag(maa, 30) over (order by metric_date) as maa_lag_30

    from base_metrics
)

select
    metric_date,
    
    -- User Metrics
    dau, wau, mau,
    
    -- Account Metrics
    daa, waa, maa,

    -- Stickiness Ratios
    case when mau > 0 then round(dau / mau, 2) else 0 end as user_stickiness_ratio,
    case when maa > 0 then round(daa / maa, 2) else 0 end as account_stickiness_ratio,

    -- ==========================================
    -- LINEAR TRENDS (Slope = (y2-y1)/(x2-x1))
    -- Represents "Avg Daily Growth" over period
    -- ==========================================

    -- DAU Trends
    round((dau - dau_lag_7) / 7.0, 2) as dau_trend_7d,
    round((dau - dau_lag_14) / 14.0, 2) as dau_trend_14d,
    round((dau - dau_lag_30) / 30.0, 2) as dau_trend_30d,

    -- WAU Trends
    round((wau - wau_lag_7) / 7.0, 2) as wau_trend_7d,
    round((wau - wau_lag_14) / 14.0, 2) as wau_trend_14d,
    round((wau - wau_lag_30) / 30.0, 2) as wau_trend_30d,

    -- MAU Trends
    round((mau - mau_lag_7) / 7.0, 2) as mau_trend_7d,
    round((mau - mau_lag_14) / 14.0, 2) as mau_trend_14d,
    round((mau - mau_lag_30) / 30.0, 2) as mau_trend_30d,

    -- DAA Trends
    round((daa - daa_lag_7) / 7.0, 2) as daa_trend_7d,
    round((daa - daa_lag_14) / 14.0, 2) as daa_trend_14d,
    round((daa - daa_lag_30) / 30.0, 2) as daa_trend_30d,

    -- WAA Trends
    round((waa - waa_lag_7) / 7.0, 2) as waa_trend_7d,
    round((waa - waa_lag_14) / 14.0, 2) as waa_trend_14d,
    round((waa - waa_lag_30) / 30.0, 2) as waa_trend_30d,

    -- MAA Trends
    round((maa - maa_lag_7) / 7.0, 2) as maa_trend_7d,
    round((maa - maa_lag_14) / 14.0, 2) as maa_trend_14d,
    round((maa - maa_lag_30) / 30.0, 2) as maa_trend_30d

from metrics_with_lags