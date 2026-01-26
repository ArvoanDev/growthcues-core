{{ config(
    materialized='table'
) }}

with user_activity as (
    select
        user_id,
        min(event_at) as first_seen_at,
        max(event_at) as last_seen_at,
        count(distinct account_id) as lifetime_accounts_distinct
    from {{ ref('stg_segment_tracks') }}
    where user_id is not null
    group by 1
),

last_account as (
    select 
        user_id, 
        account_id as latest_account_id
    from {{ ref('stg_segment_tracks') }}
    where user_id is not null and account_id is not null
    -- Qualify selects the first row of the window function
    -- Supported in Snowflake and BigQuery
    qualify row_number() over (partition by user_id order by event_at desc) = 1
)

select
    u.user_id,
    u.first_seen_at,
    u.last_seen_at,
    u.lifetime_accounts_distinct,
    
    la.latest_account_id,
    
    -- Lifetime Duration
    {{ dbt.datediff("u.first_seen_at", "current_timestamp", "day") }} as days_since_first_seen,
    {{ dbt.datediff("u.last_seen_at", "current_timestamp", "day") }} as days_since_last_seen

from user_activity u
left join last_account la using (user_id)
