{{ config(
    materialized='incremental',
    unique_key='session_id',
    partition_by={'field': 'session_start_at', 'data_type': 'timestamp'}
) }}

WITH tracks_session_flags AS (
    SELECT
        user_id,
        timestamp as occurred_at,
        -- Generate a session flag: 1 if new session, 0 if same session
        CASE
            WHEN {{ dbt.date_diff('LAG(timestamp) OVER (PARTITION BY user_id ORDER BY timestamp)', 'timestamp', 'minute') }} > 30 
            THEN 1
            ELSE 0 
        END AS is_new_session_flag
    FROM {{ ref('stg_segment_tracks') }}
    {% if is_incremental() %}
    -- Only process new data to save costs
    WHERE timestamp >= (SELECT MAX(session_start_at) FROM {{ this }})
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
    {{ dbt.date_diff('MIN(occurred_at)', 'MAX(occurred_at)', 'second') }} as session_duration_seconds,
    COUNT(*) as events_in_session
FROM session_grouping
GROUP BY 1, 2
ORDER BY session_start_at
