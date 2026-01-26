{{ config(
    materialized='table'
) }}

with 

-- 1. Get Users
users as (
    select * from {{ ref('dim_users') }}
),

-- 2. Date Spine
-- Note: dbt_utils.date_spine excludes the end_date, so this generates dates up to Yesterday.
-- This ensures we are analyzing full, completed days.
date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2022-01-01' as date)", 
        end_date="current_date"
    ) }}
),

-- 3. Flatten daily activity (User x Date)
daily_activity as (
    select
        cast(event_at as date) as activity_date,
        user_id,
        count(*) as n_events
    from {{ ref('stg_segment_tracks') }}
    where user_id is not null
    group by 1, 2
),

-- 4. Cross Join (User x Date)
user_days as (
    select
        d.date_day as metric_date,
        u.user_id,
        u.first_seen_at
    from date_spine d
    cross join users u
    where d.date_day >= cast(u.first_seen_at as date)
),

-- 5. Join Activity
joined_data as (
    select
        ud.metric_date,
        ud.user_id,
        coalesce(da.n_events, 0) as n_events_daily,
        case when coalesce(da.n_events, 0) > 0 then 1 else 0 end as is_active_daily
    from user_days ud
    left join daily_activity da 
        on ud.user_id = da.user_id 
        and ud.metric_date = da.activity_date
),

-- 6. Window Functions for Lifecycle (Part 1: Calculate rolling windows)
windowed_base as (
    select
        metric_date,
        user_id,
        n_events_daily,
        is_active_daily,
        -- Active in last 7 days (WAU flag)
        max(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 6 preceding and current row
        ) as is_active_weekly,

        -- Active in last 30 days (MAU flag)
        max(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 29 preceding and current row
        ) as is_active_monthly,

        -- Frequency: Days active in last 7
        sum(is_active_daily) over (
            partition by user_id 
            order by metric_date 
            rows between 6 preceding and current row
        ) as active_days_last_7

    from joined_data
),

-- 7. Window Functions for Lifecycle (Part 2: Add lagged values)
windowed as (
    select
        *,
        -- Previous day activity (for Resurrection logic)
        lag(is_active_daily, 1) over (partition by user_id order by metric_date) as was_active_yesterday,
        
        -- Previous 30 day activity status (Lagged MAU)
        -- Now we can safely LAG the pre-calculated is_active_monthly
        lag(is_active_monthly, 1) over (partition by user_id order by metric_date) as was_active_monthly_yesterday

    from windowed_base
)

select
    w.metric_date,
    w.user_id,
    u.latest_account_id,
    
    w.n_events_daily,
    w.is_active_daily,
    w.is_active_weekly,
    w.is_active_monthly,
    
    -- Frequency (0-7)
    w.active_days_last_7,
    
    -- LIFECYCLE STATE LOGIC
    case
        -- New: First day ever seen
        when w.metric_date = cast(u.first_seen_at as date) then 'New'
        
        -- Resurrected: Active today, but was NOT active in previous 30 days
        when w.is_active_daily = 1 and (w.was_active_monthly_yesterday = 0 or w.was_active_monthly_yesterday is null) then 'Resurrected'
        
        -- Churned: Not active in last 30 days
        when w.is_active_monthly = 0 then 'Churned'
        
        -- Active: Standard active user
        when w.is_active_daily = 1 then 'Active'
        
        -- Dormant: In the 30-day window, but not active today
        else 'Dormant'
    end as user_lifecycle_status

from windowed w
left join users u on w.user_id = u.user_id

-- OPTIMIZATION: Only materialize the LATEST snapshot for each user.
-- This reduces the table size from (Users * Days) to just (Users),
-- effectively giving you the "Current State" of your userbase.
qualify row_number() over (partition by w.user_id order by w.metric_date desc) = 1