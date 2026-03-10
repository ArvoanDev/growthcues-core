{{
  config(
    materialized='view',
    enabled=(var('tracking_provider', 'segment') == 'posthog')
  )
}}

{#
  Staging model for PostHog track events (via Batch Exports).

  Filters out $pageview and $identify events, leaving only custom track events.
  Maps PostHog's single-table schema to the standard GrowthCues columns:
    event_id, anonymous_id, user_id, original_user_id,
    account_id, original_account_id, event_name, event_at

  PostHog resolves identities server-side, so distinct_id is used directly
  as user_id — no stg_identity_resolution step is needed.

  Account attribution comes from the PostHog Group identified by
  var('posthog_group_type', 'company') inside the $groups property blob.
#}

{%- set posthog_group_type = var('posthog_group_type', 'company') -%}
{%- set tracks_lookback_days = var('tracks_lookback_days', 365) -%}

with source as (

    select *
    from {{ source('posthog', 'events') }}
    where event not in ('$pageview', '$identify', '$autocapture')
      and cast(timestamp as datetime) >= {{ dbt.dateadd('day', -tracks_lookback_days, dbt.current_timestamp()) }}

),

renamed as (

    select
        uuid                                                                              as event_id,

        -- PostHog resolves identities server-side; distinct_id is the canonical user identity
        cast(null as {{ dbt.type_string() }})                                            as anonymous_id,
        distinct_id                                                                       as user_id,
        distinct_id                                                                       as original_user_id,

        -- Extract account_id from the $groups nested property using the configured group type
        {{ get_json_property('properties', '$groups.' ~ posthog_group_type) }}           as account_id,
        {{ get_json_property('properties', '$groups.' ~ posthog_group_type) }}           as original_account_id,

        event                                                                             as event_name,
        timestamp                                                                         as event_at

    from source

)

select *
from renamed
where account_id is not null
