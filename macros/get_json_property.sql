{% macro get_json_property(column, property_path) %}
  {#
    Extracts a scalar value from a JSON column in a cross-warehouse compatible way.

    Args:
      column        : The column expression containing the JSON data (e.g., 'properties').
      property_path : Dot-separated path to the desired property.
                      Special characters like '$' in PostHog property names are supported.

    Examples:
      {{ get_json_property('properties', '$current_url') }}
      {{ get_json_property('properties', '$groups.company') }}
      {{ get_json_property('properties', 'plan') }}

    Supported adapters: bigquery, snowflake, duckdb (local dev / CI).
  #}
  {%- set parts = property_path.split('.') -%}
  {%- if target.type == 'bigquery' -%}
    {%- set json_path = namespace(value='$') -%}
    {%- for part in parts -%}
      {%- set json_path.value = json_path.value ~ '["' ~ part ~ '"]' -%}
    {%- endfor -%}
    JSON_EXTRACT_SCALAR({{ column }}, '{{ json_path.value }}')
  {%- elif target.type == 'snowflake' -%}
    {{ column }}{%- for part in parts -%}:"{{ part }}"{%- endfor -%}::string
  {%- else -%}
    {#- DuckDB (local dev) and other adapters -#}
    {%- set json_path = namespace(value='$') -%}
    {%- for part in parts -%}
      {%- set json_path.value = json_path.value ~ '["' ~ part ~ '"]' -%}
    {%- endfor -%}
    json_extract_string({{ column }}, '{{ json_path.value }}')
  {%- endif -%}
{% endmacro %}
