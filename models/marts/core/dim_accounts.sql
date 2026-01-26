{{ config(materialized = 'table') }} with account_activity as (
  select
    account_id,
    min(event_at) as first_seen_at,
    max(event_at) as last_seen_at,
    -- Lifetime Size: Total unique users ever seen for this account
    count(distinct user_id) as lifetime_unique_users,
    -- Current Seats Proxy: Unique users active in the last 30 days
    -- Uses standard interval syntax compatible with Snowflake & BigQuery
    count(
      distinct case
        when cast(event_at as date) >= {{ dbt.dateadd(datepart='day', interval=-30, from_date_or_timestamp='current_date') }} then user_id
      end
    ) as current_active_seats
  from
    {{ ref('stg_segment_tracks') }}
  where
    account_id is not null
  group by
    1
)
select
  account_id,
  first_seen_at,
  last_seen_at,
  lifetime_unique_users,
  current_active_seats,
  -- Calculate generic "days since" metrics
  {{ dbt.datediff("first_seen_at", "current_timestamp", "day") }} as days_since_first_seen,
  {{ dbt.datediff("last_seen_at", "current_timestamp", "day") }} as days_since_last_seen
from
  account_activity