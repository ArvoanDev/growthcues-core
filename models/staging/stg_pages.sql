{{ config(materialized='view', enabled=var('include_pages_in_sessions', true)) }}

{#
  Router model: delegates to the provider-specific pages staging model
  based on var('tracking_provider', 'segment').

  Downstream marts should reference this model (stg_pages) rather than
  provider-specific models (stg_segment_pages / stg_posthog_pages) so
  that switching data providers requires only a single variable change.
#}

{% if var('tracking_provider', 'segment') == 'posthog' %}
  select * from {{ ref('stg_posthog_pages') }}
{% else %}
  select * from {{ ref('stg_segment_pages') }}
{% endif %}
