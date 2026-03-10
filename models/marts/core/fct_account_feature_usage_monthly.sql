-- models/marts/product/fct_account_feature_usage_monthly.sql
{{ config(
    materialized='table'
) }}

{%- set min_monthly_events = var('min_monthly_feature_events', 0) -%}

with tracks as (
    select * from {{ ref('stg_tracks') }}
),

-- 1. Identify all feature usage per account per month
monthly_usage as (
    select
        {{ dbt.date_trunc('month', 'event_at') }} as metric_month,
        account_id,
        event_name,
        count(*) as n_events,
        count(distinct user_id) as n_users
    from tracks
    where account_id is not null
    group by 1, 2, 3
    {% if min_monthly_events > 0 %}
    -- Optional: Filter out low-volume events to reduce table size
    -- Set via: vars.min_monthly_feature_events in dbt_project.yml
    having count(*) >= {{ min_monthly_events }}
    {% endif %}
),

-- 2. Bring in Account Context (to calculate penetration rates)
account_monthly_totals as (
    select
        {{ dbt.date_trunc('month', 'event_at') }} as metric_month,
        account_id,
        count(distinct user_id) as account_mau
    from tracks
    where account_id is not null
    group by 1, 2
)

select
    u.metric_month,
    u.account_id,
    u.event_name,
    u.n_events as monthly_event_volume,
    u.n_users as monthly_active_users_on_feature,
    a.account_mau,
    
    -- Feature Penetration: % of the account's active users who used this feature
    -- Key for "Expansion Opportunities" analysis
    round(u.n_users / nullif(a.account_mau, 0), 2) as feature_penetration_rate,
    
    -- First/Last usage tracking to help identify "New Adoption" vs "Abandonment"
    min(u.metric_month) over (partition by u.account_id, u.event_name) as first_used_month,
    
    -- Lag for Trend Analysis (Did usage drop?)
    lag(u.n_events, 1) over (partition by u.account_id, u.event_name order by u.metric_month) as prev_month_volume,
    
    -- Month-over-Month Change %
    -- Key for identifying Expanding vs Declining features
    case 
        when lag(u.n_events, 1) over (partition by u.account_id, u.event_name order by u.metric_month) > 0 
        then round(
            (u.n_events - lag(u.n_events, 1) over (partition by u.account_id, u.event_name order by u.metric_month)) 
            / lag(u.n_events, 1) over (partition by u.account_id, u.event_name order by u.metric_month) * 100, 
            1
        )
        else null 
    end as mom_change_pct

from monthly_usage u
left join account_monthly_totals a 
    on u.account_id = a.account_id 
    and u.metric_month = a.metric_month
