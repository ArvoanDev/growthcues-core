{{ config(materialized = 'view') }} 

{%- set identity_anonymous_id_field = var('identity_anonymous_id_field', 'anonymous_id') -%}
{%- set pages_lookback_days = var('pages_lookback_days', 365) -%}
{%- set enable_identity_stitching = var('enable_identity_stitching', true) -%}
{%- set group_id_column = var('group_id', 'context_group_id') -%}
{%- set source_relation = source('segment', 'pages') -%}
{%- set source_columns = adapter.get_columns_in_relation(source_relation) | map(attribute='name') | map('lower') | list -%}
{%- set has_group_id = group_id_column | lower in source_columns -%}

with source as (
  select
    *
  from
    {{ source('segment', 'pages') }}
  where
    cast(timestamp as datetime) >= {{ dbt.dateadd('day', -pages_lookback_days, dbt.current_timestamp()) }}
),

{% if enable_identity_stitching %}
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
{% endif %}

renamed as (
  select
    id as page_id,
    {% if enable_identity_stitching %}
    {{ identity_anonymous_id_field }} as anonymous_id,
    {% else %}
    cast(null as {{ dbt.type_string() }}) as anonymous_id,
    {% endif %}
    user_id,
    -- Segment stores the Account ID in 'context_group_id'
    -- We cast to string to ensure consistency across warehouses
    -- For pages, group_id is often null or missing for anonymous traffic
    {% if has_group_id %}
    cast({{ group_id_column }} as {{ dbt.type_string() }}) as account_id,
    {% else %}
    cast(null as {{ dbt.type_string() }}) as account_id,
    {% endif %}
    name as page_name,
    -- Handle timestamp normalization. You can e.g., prefer 'original_timestamp' as it reflects the client-side time
    coalesce(timestamp, timestamp) as page_viewed_at,
    -- Standard page properties automatically sent by Segment
    {{ var('page_title_field', 'properties_title') }} as page_title,
    {{ var('page_path_field', 'properties_path') }} as page_path,
    {{ var('page_url_field', 'properties_url') }} as page_url,
    {{ var('page_referrer_field', 'properties_referrer') }} as page_referrer,
    {{ var('page_search_field', 'properties_search') }} as page_search
    -- Helper for context
    -- context_library_name,
    -- context_library_version
  from
    source
),

{% if enable_identity_stitching %}
stitched as (
  select
    r.page_id,
    r.anonymous_id,
    r.user_id as original_user_id,
    -- Use identity stitching: prefer explicit user_id, fall back to mapped master_user_id
    coalesce(r.user_id, im.master_user_id) as user_id,
    r.account_id as original_account_id,
    -- Backfill account_id for anonymous events using the stitched user's latest account
    coalesce(r.account_id, uam.latest_account_id) as account_id,
    r.page_name,
    r.page_viewed_at,
    r.page_title,
    r.page_path,
    r.page_url,
    r.page_referrer,
    r.page_search
  from
    renamed r
  left join
    identity_mapping im
    on r.anonymous_id = im.anonymous_id
  left join
    user_account_mapping uam
    on coalesce(r.user_id, im.master_user_id) = uam.user_id
)
{% else %}
stitched as (
  select
    page_id,
    anonymous_id,
    user_id as original_user_id,
    user_id,
    account_id as original_account_id,
    account_id,
    page_name,
    page_viewed_at,
    page_title,
    page_path,
    page_url,
    page_referrer,
    page_search
  from
    renamed
)
{% endif %}

select
  *
from
  stitched -- Filter out pages not associated with an account (orphaned user actions)
  -- For B2B metrics, we strictly need account context.
where
  account_id is not null
