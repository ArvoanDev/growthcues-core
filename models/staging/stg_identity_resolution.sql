{{-
    config(
        materialized='table',
        enabled=var('enable_identity_stitching', true)
    )
-}}

{%- set identity_anonymous_id_field = var('identity_anonymous_id_field', 'anonymous_id') -%}
{%- set identity_lookback_days = var('identity_lookback_days', 365) -%}

with identifies as (
    -- 1. Get all explicit links between anonymous_id and user_id
    -- Filter to only recent data based on lookback window
    select
        {{ identity_anonymous_id_field }} as anonymous_id,
        user_id,
        timestamp
    from {{ source('segment', 'identifies') }}
    where user_id is not null
        and cast(timestamp as datetime) >= {{ dbt.dateadd('day', -identity_lookback_days, dbt.current_timestamp()) }}
),

last_touch as (
    -- 2. Find the MOST RECENT user_id for each anonymous_id
    select
        anonymous_id,
        user_id as master_user_id,
        row_number() over (
            partition by anonymous_id 
            order by timestamp desc
        ) as rn
    from identifies
)

-- 3. Expose a simple mapping table
select 
    anonymous_id, 
    master_user_id 
from last_touch 
where rn = 1
