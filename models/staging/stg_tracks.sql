{{ config(materialized='view') }}

{#
  Router model: delegates to the provider-specific tracks staging model
  based on var('tracking_provider', 'segment').

  Downstream marts should reference this model (stg_tracks) rather than
  provider-specific models (stg_segment_tracks / stg_posthog_tracks) so
  that switching data providers requires only a single variable change.
#}

{% if var('tracking_provider', 'segment') == 'posthog' %}
  select * from {{ ref('stg_posthog_tracks') }}
{% else %}
  select * from {{ ref('stg_segment_tracks') }}
{% endif %}
