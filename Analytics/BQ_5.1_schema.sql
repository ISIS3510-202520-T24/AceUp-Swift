# BigQuery Schema for BQ 5.1: User Update Time Analytics
# This schema defines the structure for analyzing how long users take to update information

# Table: analytics_update_sessions
# Description: Tracks individual user update sessions with timing and completion data

CREATE TABLE IF NOT EXISTS `aceup-app-123.aceup_analytics.user_update_sessions` (
  # Session Identification
  sessionId STRING NOT NULL,
  userId STRING NOT NULL,
  updateType STRING NOT NULL,  # availability, schedule, personal_info, profile_image, assignment, course_info, shared_calendar, preferences
  
  # Timing Data
  startTimestamp TIMESTAMP NOT NULL,
  endTimestamp TIMESTAMP,
  durationSeconds FLOAT64,
  
  # Session Status
  completed BOOLEAN NOT NULL,
  abandoned BOOLEAN NOT NULL,
  
  # Interaction Metrics
  interactionCount INT64 NOT NULL,
  fieldsModified ARRAY<STRING>,
  
  # Context
  platform STRING NOT NULL,  # iOS, Android
  appVersion STRING NOT NULL,
  
  # Metadata
  createdAt TIMESTAMP NOT NULL,
  
  # Derived Fields (computed in views)
  # - date: DATE from startTimestamp
  # - hour: INT64 from startTimestamp
  # - dayOfWeek: STRING from startTimestamp
  # - isSlowUpdate: BOOLEAN (duration > threshold)
)
PARTITION BY DATE(startTimestamp)
CLUSTER BY userId, updateType, completed;

# View: Average Update Times by Type
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.avg_update_times_by_type` AS
SELECT
  updateType,
  COUNT(*) as total_sessions,
  COUNT(CASE WHEN completed THEN 1 END) as completed_sessions,
  COUNT(CASE WHEN abandoned THEN 1 END) as abandoned_sessions,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(STDDEV(CASE WHEN completed THEN durationSeconds END), 2) as stddev_duration_seconds,
  ROUND(APPROX_QUANTILES(CASE WHEN completed THEN durationSeconds END, 100)[OFFSET(50)], 2) as median_duration_seconds,
  ROUND(APPROX_QUANTILES(CASE WHEN completed THEN durationSeconds END, 100)[OFFSET(75)], 2) as p75_duration_seconds,
  ROUND(APPROX_QUANTILES(CASE WHEN completed THEN durationSeconds END, 100)[OFFSET(90)], 2) as p90_duration_seconds,
  ROUND(AVG(interactionCount), 2) as avg_interactions,
  ROUND(AVG(ARRAY_LENGTH(fieldsModified)), 2) as avg_fields_modified,
  ROUND(COUNT(CASE WHEN abandoned THEN 1 END) * 100.0 / COUNT(*), 2) as abandonment_rate_percent
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
GROUP BY updateType
ORDER BY avg_duration_seconds DESC;

# View: User Update Patterns Over Time
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.update_patterns_over_time` AS
SELECT
  DATE(startTimestamp) as date,
  updateType,
  EXTRACT(HOUR FROM startTimestamp) as hour,
  FORMAT_TIMESTAMP('%A', startTimestamp) as day_of_week,
  COUNT(*) as session_count,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(COUNT(CASE WHEN abandoned THEN 1 END) * 100.0 / COUNT(*), 2) as abandonment_rate_percent
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
GROUP BY date, updateType, hour, day_of_week
ORDER BY date DESC, hour;

# View: User-Level Update Performance
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.user_update_performance` AS
SELECT
  userId,
  updateType,
  COUNT(*) as total_updates,
  COUNT(CASE WHEN completed THEN 1 END) as completed_updates,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(MIN(CASE WHEN completed THEN durationSeconds END), 2) as min_duration_seconds,
  ROUND(MAX(CASE WHEN completed THEN durationSeconds END), 2) as max_duration_seconds,
  MAX(endTimestamp) as last_update_timestamp,
  DATE_DIFF(CURRENT_DATE(), DATE(MAX(endTimestamp)), DAY) as days_since_last_update
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
WHERE completed = TRUE
GROUP BY userId, updateType;

# View: Slow Updates (exceeding thresholds)
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.slow_updates` AS
WITH thresholds AS (
  SELECT 'availability' as updateType, 120 as threshold_seconds UNION ALL
  SELECT 'schedule', 180 UNION ALL
  SELECT 'personal_info', 120 UNION ALL
  SELECT 'profile_image', 60 UNION ALL
  SELECT 'assignment', 180 UNION ALL
  SELECT 'course_info', 120 UNION ALL
  SELECT 'shared_calendar', 150 UNION ALL
  SELECT 'preferences', 60
)
SELECT
  s.sessionId,
  s.userId,
  s.updateType,
  s.durationSeconds,
  t.threshold_seconds,
  ROUND(s.durationSeconds - t.threshold_seconds, 2) as exceeded_by_seconds,
  ROUND((s.durationSeconds - t.threshold_seconds) * 100.0 / t.threshold_seconds, 2) as exceeded_by_percent,
  s.interactionCount,
  s.fieldsModified,
  s.startTimestamp,
  s.platform,
  s.appVersion
FROM `aceup-app-123.aceup_analytics.user_update_sessions` s
JOIN thresholds t ON s.updateType = t.updateType
WHERE s.completed = TRUE
  AND s.durationSeconds > t.threshold_seconds
ORDER BY exceeded_by_percent DESC;

# View: Update Frequency Analysis (BQ 5.1 insight for notifications)
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.update_frequency_analysis` AS
WITH user_updates AS (
  SELECT
    userId,
    updateType,
    DATE(endTimestamp) as update_date,
    ROW_NUMBER() OVER (PARTITION BY userId, updateType ORDER BY endTimestamp DESC) as recency_rank,
    LAG(DATE(endTimestamp)) OVER (PARTITION BY userId, updateType ORDER BY endTimestamp) as previous_update_date
  FROM `aceup-app-123.aceup_analytics.user_update_sessions`
  WHERE completed = TRUE
)
SELECT
  userId,
  updateType,
  update_date as last_update_date,
  DATE_DIFF(CURRENT_DATE(), update_date, DAY) as days_since_last_update,
  DATE_DIFF(update_date, previous_update_date, DAY) as days_between_updates,
  CASE
    WHEN DATE_DIFF(CURRENT_DATE(), update_date, DAY) >= 7 THEN TRUE
    ELSE FALSE
  END as needs_reminder,
  CASE
    WHEN DATE_DIFF(CURRENT_DATE(), update_date, DAY) >= 7 THEN 'overdue'
    WHEN DATE_DIFF(CURRENT_DATE(), update_date, DAY) >= 5 THEN 'due_soon'
    ELSE 'up_to_date'
  END as update_status
FROM user_updates
WHERE recency_rank = 1
ORDER BY days_since_last_update DESC;

# View: Platform Comparison (iOS vs Android)
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.platform_comparison` AS
SELECT
  platform,
  updateType,
  COUNT(*) as total_sessions,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(AVG(interactionCount), 2) as avg_interactions,
  ROUND(COUNT(CASE WHEN abandoned THEN 1 END) * 100.0 / COUNT(*), 2) as abandonment_rate_percent,
  COUNT(DISTINCT userId) as unique_users
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
GROUP BY platform, updateType
ORDER BY platform, avg_duration_seconds DESC;

# View: Update Complexity Analysis (interactions vs duration)
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.update_complexity_analysis` AS
SELECT
  updateType,
  CASE
    WHEN ARRAY_LENGTH(fieldsModified) <= 1 THEN 'simple'
    WHEN ARRAY_LENGTH(fieldsModified) <= 3 THEN 'moderate'
    ELSE 'complex'
  END as complexity_level,
  COUNT(*) as session_count,
  ROUND(AVG(durationSeconds), 2) as avg_duration_seconds,
  ROUND(AVG(interactionCount), 2) as avg_interactions,
  ROUND(AVG(ARRAY_LENGTH(fieldsModified)), 2) as avg_fields_modified
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
WHERE completed = TRUE
  AND fieldsModified IS NOT NULL
GROUP BY updateType, complexity_level
ORDER BY updateType, complexity_level;

# Query: Weekly Update Trends
# Use this to track changes over time and identify patterns
SELECT
  DATE_TRUNC(DATE(startTimestamp), WEEK) as week_start,
  updateType,
  COUNT(*) as total_sessions,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  COUNT(DISTINCT userId) as unique_users,
  ROUND(COUNT(CASE WHEN abandoned THEN 1 END) * 100.0 / COUNT(*), 2) as abandonment_rate_percent
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
WHERE startTimestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12*7 DAY)
GROUP BY week_start, updateType
ORDER BY week_start DESC, updateType;

# Query: Users Needing Update Reminders (for notification system)
# This identifies users who haven't updated specific information in over 7 days
SELECT
  userId,
  updateType,
  days_since_last_update,
  last_update_date,
  update_status
FROM `aceup-app-123.aceup_analytics.update_frequency_analysis`
WHERE needs_reminder = TRUE
  AND updateType IN ('availability', 'schedule', 'personal_info')
ORDER BY days_since_last_update DESC;

# Query: Top 10 Slowest Update Sessions (for UX improvement)
SELECT
  sessionId,
  userId,
  updateType,
  ROUND(durationSeconds, 2) as duration_seconds,
  interactionCount,
  fieldsModified,
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', startTimestamp) as started_at,
  platform,
  appVersion
FROM `aceup-app-123.aceup_analytics.user_update_sessions`
WHERE completed = TRUE
  AND durationSeconds IS NOT NULL
ORDER BY durationSeconds DESC
LIMIT 10;