-- models/marts/core/dim_accounts.sql
{{ config(
    materialized='table'
) }}

with account_activity as (
    select
        account_id,
        min(event_at) as first_seen_at,
        max(event_at) as last_seen_at,
        -- Lifetime Size: Total unique users ever seen for this account
        count(distinct user_id) as lifetime_unique_users,
        -- Current Seats Proxy: Unique users active in the last 30 days
        -- Uses dbt.dateadd for cross-warehouse compatibility
        -- Counts the number of distinct user IDs who have an event date within the last 30 days from the current timestamp.
        count(distinct case 
            when cast(event_at as date) >= {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }}
            then user_id 
        end) as current_active_seats
    from {{ ref('stg_segment_tracks') }}
    where account_id is not null
    group by 1
)

select
    account_id,
    first_seen_at,
    last_seen_at,
    lifetime_unique_users,
    current_active_seats,
    -- Calculate generic "days since" metrics
    {{ dbt.datediff("first_seen_at", dbt.current_timestamp(), "day") }} as days_since_first_seen,
    {{ dbt.datediff("last_seen_at", dbt.current_timestamp(), "day") }} as days_since_last_seen
from account_activity