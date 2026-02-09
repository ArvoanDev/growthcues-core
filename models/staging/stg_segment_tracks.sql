{{ config(materialized = 'view') }} 

{%- set identity_anonymous_id_field = var('identity_anonymous_id_field', 'anonymous_id') -%}
{%- set tracks_lookback_days = var('tracks_lookback_days', 365) -%}

with source as (
  select
    *
  from
    {{ source('segment', 'tracks') }}
  where
    timestamp >= {{ dbt.dateadd('day', -tracks_lookback_days, dbt.current_timestamp()) }}
),

identity_mapping as (
  select
    anonymous_id,
    master_user_id
  from
    {{ ref('stg_identity_resolution') }}
),

user_account_mapping as (
  select
    user_id,
    latest_account_id
  from
    {{ ref('stg_user_account_mapping') }}
),

renamed as (
  select
    id as event_id,
    {{ identity_anonymous_id_field }} as anonymous_id,
    user_id,
    -- Segment stores the Account ID in 'context_group_id'
    -- We cast to string to ensure consistency across warehouses
    cast({{ var('group_id') }} as {{ dbt.type_string() }}) as account_id,
    event as event_name,
    -- Handle timestamp normalization. You can e.g., prefer 'original_timestamp' as it reflects the client-side time
    coalesce(timestamp, timestamp) as event_at
    -- Helper for context
    -- context_library_name,
    -- context_library_version
  from
    source
),

stitched as (
  select
    r.event_id,
    r.anonymous_id,
    r.user_id as original_user_id,
    -- Use identity stitching: prefer explicit user_id, fall back to mapped master_user_id
    coalesce(r.user_id, im.master_user_id) as user_id,
    r.account_id as original_account_id,
    -- Backfill account_id for anonymous events using the stitched user's latest account
    coalesce(r.account_id, uam.latest_account_id) as account_id,
    r.event_name,
    r.event_at
  from
    renamed r
  left join
    identity_mapping im
    on r.anonymous_id = im.anonymous_id
  left join
    user_account_mapping uam
    on coalesce(r.user_id, im.master_user_id) = uam.user_id
)

select
  *
from
  stitched -- Filter out events not associated with an account (orphaned user actions)
  -- For B2B metrics, we strictly need account context.
where
  account_id is not null