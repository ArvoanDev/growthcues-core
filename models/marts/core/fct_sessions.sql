{{ config(
    materialized='incremental',
    unique_key='session_id',
    partition_by={'field': 'session_start_at', 'data_type': 'timestamp'}
) }}

WITH tracks_session_flags AS (
    SELECT
        user_id,
        event_at as occurred_at,
        -- Generate a session flag: 1 if new session, 0 if same session
        CASE
            WHEN {{ dbt.datediff('LAG(event_at) OVER (PARTITION BY user_id ORDER BY event_at)', 'event_at', 'minute') }} > {{ var('session_timeout_minutes', 30) }} 
            THEN 1
            ELSE 0 
        END AS is_new_session_flag
    FROM {{ ref('stg_segment_tracks') }}
    {% if is_incremental() %}
    -- Only process new data to save costs
    -- Lookback from last session end to catch sessions that might still be active
    -- This prevents splitting sessions across incremental runs
    WHERE event_at >= CAST((SELECT {{ dbt.dateadd('minute', -var('session_timeout_minutes', 30), 'MAX(session_end_at)') }} FROM {{ this }}) AS TIMESTAMP)
    {% endif %}
),

session_grouping AS (
    SELECT
        *,
        -- Cumulative sum of flags creates a unique ID for each user's session
        SUM(is_new_session_flag) OVER (PARTITION BY user_id ORDER BY occurred_at) as user_session_index
    FROM tracks_session_flags
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id', 'user_session_index']) }} as session_id,
    user_id,
    MIN(occurred_at) as session_start_at,
    MAX(occurred_at) as session_end_at,
    {{ dbt.datediff('MIN(occurred_at)', 'MAX(occurred_at)', 'second') }} as session_duration_seconds,
    COUNT(*) as events_in_session
FROM session_grouping
GROUP BY 1, 2
