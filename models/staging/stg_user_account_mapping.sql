{{-
    config(
        materialized='table',
        enabled=var('enable_identity_stitching', true)
    )
-}}

{%- set tracks_lookback_days = var('tracks_lookback_days', 365) -%}

-- Get the most recent account_id for each user_id from tracks with explicit account context
with user_accounts as (
    select
        user_id,
        cast({{ var('group_id') }} as {{ dbt.type_string() }}) as account_id,
        timestamp as event_at
    from {{ source('segment', 'tracks') }}
    where user_id is not null
        and {{ var('group_id') }} is not null
        and cast(timestamp as datetime) >= {{ dbt.dateadd('day', -tracks_lookback_days, dbt.current_timestamp()) }}
),

latest_account_per_user as (
    select
        user_id,
        account_id,
        row_number() over (
            partition by user_id
            order by event_at desc
        ) as rn
    from user_accounts
)

select
    user_id,
    account_id as latest_account_id
from latest_account_per_user
where rn = 1
