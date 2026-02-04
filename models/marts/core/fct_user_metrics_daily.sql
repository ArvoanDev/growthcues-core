-- models/marts/core/fct_user_metrics_daily.sql
{{ config(
    materialized='table'
) }}

with users as ( select * from {{ ref('dim_users') }} ),
accounts as ( select account_id, first_seen_at as account_created_at from {{ ref('dim_accounts') }} ),

date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2023-01-01' as date)", 
        end_date="current_date"
    ) }}
),

daily_activity as (
    select
        cast(event_at as date) as activity_date,
        user_id,
        count(*) as n_events,
        count(distinct event_name) as n_features
    from {{ ref('stg_segment_tracks') }}
    where user_id is not null
    group by 1, 2
),

user_days as (
    select
        d.date_day as metric_date,
        u.user_id,
        u.first_seen_at
    from date_spine d
    cross join users u
    where d.date_day >= cast(u.first_seen_at as date)
),

joined_data as (
    select
        ud.metric_date,
        ud.user_id,
        ud.first_seen_at,
        coalesce(da.n_events, 0) as n_events_daily,
        coalesce(da.n_features, 0) as n_features_daily,
        case when coalesce(da.n_events, 0) > 0 then 1 else 0 end as is_active_daily
    from user_days ud
    left join daily_activity da 
        on ud.user_id = da.user_id 
        and ud.metric_date = da.activity_date
),

windowed as (
    select
        *,
        -- Rolling 30 Day Activity Volume
        sum(n_events_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 29 preceding and current row
        ) as n_events_monthly,

        -- Rolling 30 Day Feature Usage
        sum(n_features_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 29 preceding and current row
        ) as n_features_monthly,

        -- Standard Flags
        max(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 6 preceding and current row
        ) as is_active_weekly,

        max(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 29 preceding and current row
        ) as is_active_monthly,

        -- Frequency: L7 (Days active in last 7)
        sum(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 6 preceding and current row
        ) as active_days_last_7,

        -- Frequency: L14 (Days active in last 14) - Champion Metric
        sum(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 13 preceding and current row
        ) as active_days_last_14

    from joined_data
),

lifecycle_prep as (
    select
        *,
        lag(is_active_monthly, 1) over (partition by user_id order by metric_date) as was_active_monthly_yesterday
    from windowed
)

select
    w.metric_date,
    w.user_id,
    u.latest_account_id,
    w.n_events_daily,
    w.is_active_daily,
    w.is_active_weekly,
    w.is_active_monthly,
    w.active_days_last_7,
    w.active_days_last_14,
    w.n_events_monthly,
    
    -- GTM SIGNALS
    -- 1. Identifying the "Champion" (Rank 1 = Top User)
    row_number() over (
        partition by u.latest_account_id, w.metric_date 
        order by w.n_events_monthly desc
    ) as usage_rank_in_account,

    -- 2. Identifying the "Admin / Buyer"
    case 
        when cast(u.first_seen_at as date) = cast(a.account_created_at as date) 
        then 1 else 0 
    end as is_admin_proxy,

    -- 3. Sophistication
    w.n_features_monthly as distinct_features_used_30d,

    -- Lifecycle Logic
    case
        when w.metric_date = cast(u.first_seen_at as date) then 'New'
        when w.is_active_daily = 1 and (w.was_active_monthly_yesterday = 0 or w.was_active_monthly_yesterday is null) then 'Resurrected'
        when w.is_active_monthly = 0 then 'Churned'
        when w.is_active_daily = 1 then 'Active'
        else 'Dormant'
    end as user_lifecycle_status

from lifecycle_prep w
left join users u on w.user_id = u.user_id
left join accounts a on u.latest_account_id = a.account_id

-- Optimization: Latest Snapshot Only
qualify row_number() over (partition by w.user_id order by w.metric_date desc) = 1