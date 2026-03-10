{{
  config(
    materialized='view',
    enabled=(var('tracking_provider', 'segment') == 'posthog') and var('include_pages_in_sessions', true)
  )
}}

{#
  Staging model for PostHog pageview events (via Batch Exports).

  Filters to $pageview events only and maps PostHog's single-table schema to
  the standard GrowthCues page columns:
    page_id, anonymous_id, user_id, original_user_id,
    account_id, original_account_id, page_name, page_viewed_at,
    page_title, page_path, page_url, page_referrer, page_search

  URL and path properties are extracted from the JSON properties blob using
  the get_json_property macro for cross-warehouse compatibility.
#}

{%- set posthog_group_type = var('posthog_group_type', 'company') -%}
{%- set pages_lookback_days = var('pages_lookback_days', 365) -%}

with source as (

    select *
    from {{ source('posthog', 'events') }}
    where event = '$pageview'
      and cast(timestamp as datetime) >= {{ dbt.dateadd('day', -pages_lookback_days, dbt.current_timestamp()) }}

),

renamed as (

    select
        uuid                                                                              as page_id,

        -- PostHog resolves identities server-side; distinct_id is the canonical user identity
        cast(null as {{ dbt.type_string() }})                                            as anonymous_id,
        distinct_id                                                                       as user_id,
        distinct_id                                                                       as original_user_id,

        -- Extract account_id from the $groups nested property using the configured group type
        {{ get_json_property('properties', '$groups.' ~ posthog_group_type) }}           as account_id,
        {{ get_json_property('properties', '$groups.' ~ posthog_group_type) }}           as original_account_id,

        -- PostHog does not have a named page field; null for interface compatibility
        cast(null as {{ dbt.type_string() }})                                            as page_name,
        timestamp                                                                         as page_viewed_at,

        -- PostHog does not capture page title natively; null for interface compatibility
        cast(null as {{ dbt.type_string() }})                                            as page_title,
        {{ get_json_property('properties', '$pathname') }}                               as page_path,
        {{ get_json_property('properties', '$current_url') }}                            as page_url,
        {{ get_json_property('properties', '$referrer') }}                               as page_referrer,
        cast(null as {{ dbt.type_string() }})                                            as page_search

    from source

)

select *
from renamed
where account_id is not null
