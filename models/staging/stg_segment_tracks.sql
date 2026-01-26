{{ config(materialized = 'view') }} with source as (
  select
    *
  from
    {{ source('segment', 'tracks') }}
),
renamed as (
  select
    id as event_id,
    user_id,
    -- Segment stores the Account ID in 'context_group_id'
    -- We cast to string to ensure consistency across warehouses
    cast(context_group_id as {{ dbt.type_string() }}) as account_id,
    event as event_name,
    -- Handle timestamp normalization. You can e.g., prefer 'original_timestamp' as it reflects the client-side time
    coalesce(timestamp, timestamp) as event_at,
    -- Helper for context
    -- context_library_name,
    -- context_library_version
  from
    source
)
select
  *
from
  renamed -- Filter out events not associated with an account (orphaned user actions)
  -- For B2B metrics, we strictly need account context.
where
  account_id is not null