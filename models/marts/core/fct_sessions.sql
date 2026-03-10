{{ config(
    materialized='incremental',
    unique_key='session_id',
    partition_by={'field': 'session_start_at', 'data_type': 'timestamp'}
) }}

{%- set include_pages = var('include_pages_in_sessions', true) -%}

WITH tracks AS (
    SELECT
        user_id,
        account_id,
        event_at as occurred_at
    FROM {{ ref('stg_tracks') }}
    {% if is_incremental() %}
    WHERE event_at >= CAST((SELECT {{ dbt.dateadd('minute', -var('session_timeout_minutes', 30), 'MAX(session_end_at)') }} FROM {{ this }}) AS TIMESTAMP)
    {% endif %}
),

{% if include_pages %}
pages AS (
    SELECT
        user_id,
        account_id,
        page_viewed_at as occurred_at
    FROM {{ ref('stg_pages') }}
    {% if is_incremental() %}
    WHERE page_viewed_at >= CAST((SELECT {{ dbt.dateadd('minute', -var('session_timeout_minutes', 30), 'MAX(session_end_at)') }} FROM {{ this }}) AS TIMESTAMP)
    {% endif %}
),

combined_events AS (
    SELECT * FROM tracks
    UNION ALL
    SELECT * FROM pages
),
{% else %}
combined_events AS (
    SELECT * FROM tracks
),
{% endif %}

tracks_session_flags AS (
    SELECT
        user_id,
        account_id,
        occurred_at,
        -- Generate a session flag: 1 if new session, 0 if same session
        CASE
            WHEN {{ dbt.datediff('LAG(occurred_at) OVER (PARTITION BY user_id ORDER BY occurred_at)', 'occurred_at', 'minute') }} > {{ var('session_timeout_minutes', 30) }} 
            THEN 1
            ELSE 0 
        END AS is_new_session_flag
    FROM combined_events
),

session_grouping_base AS (
    SELECT
        *,
        -- Cumulative sum of flags creates a unique ID for each user's session
        SUM(is_new_session_flag) OVER (PARTITION BY user_id ORDER BY occurred_at) as user_session_index
    FROM tracks_session_flags
),

session_grouping AS (
    SELECT
        *,
        -- Mark the first event in each session with ROW_NUMBER
        ROW_NUMBER() OVER (PARTITION BY user_id, user_session_index ORDER BY occurred_at) as event_rank_in_session
    FROM session_grouping_base
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id', 'user_session_index']) }} as session_id,
    user_id,
    user_session_index,
    MIN(occurred_at) as session_start_at,
    MAX(occurred_at) as session_end_at,
    {{ dbt.datediff('MIN(occurred_at)', 'MAX(occurred_at)', 'second') }} as session_duration_seconds,
    COUNT(*) as events_in_session,
    -- Get account_id from the first event (where event_rank_in_session = 1)
    MAX(CASE WHEN event_rank_in_session = 1 THEN account_id END) as account_id
FROM session_grouping
GROUP BY 1, 2, 3
