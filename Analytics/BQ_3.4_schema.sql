# BigQuery Schema for BQ 3.4: Quick Task Creation Feature Analytics
# This schema tracks the adoption and effectiveness of quick task creation features
# Author: Ángel Farfán Arcila

# Table: task_creation_sessions
# Description: Tracks each task creation attempt with method, timing, and completion data

CREATE TABLE IF NOT EXISTS `aceup-app-123.aceup_analytics.task_creation_sessions` (
  # Session Identification
  sessionId STRING NOT NULL,
  userId STRING NOT NULL,
  creationMethod STRING NOT NULL,  # standard, quick_create, voice_input, template, import
  
  # Timing Data
  startTimestamp TIMESTAMP NOT NULL,
  endTimestamp TIMESTAMP,
  durationSeconds FLOAT64,
  
  # Session Status
  completed BOOLEAN NOT NULL,
  abandoned BOOLEAN NOT NULL,
  
  # Interaction Metrics
  interactionCount INT64 NOT NULL,
  fieldsCompleted ARRAY<STRING>,
  fieldCount INT64,  # Number of fields filled
  
  # Task Details
  taskType STRING,  # assignment, exam, reminder, personal
  hasSubtasks BOOLEAN,
  subtaskCount INT64,
  usedTemplate BOOLEAN,
  templateId STRING,
  
  # Quality Metrics
  validationErrors INT64,  # Number of validation errors encountered
  retryCount INT64,  # Number of retry attempts
  
  # Context
  platform STRING NOT NULL,  # iOS, Android
  appVersion STRING NOT NULL,
  entryPoint STRING,  # fab, today_view, assignments_view, quick_action, widget
  
  # User Experience
  satisfactionImplicit FLOAT64,  # Derived from behavior (0.0-1.0)
  
  # Metadata
  createdAt TIMESTAMP NOT NULL
)
PARTITION BY DATE(startTimestamp)
CLUSTER BY userId, creationMethod, completed;

# Table: quick_feature_adoption
# Description: Tracks user adoption patterns of quick creation features

CREATE TABLE IF NOT EXISTS `aceup-app-123.aceup_analytics.quick_feature_adoption` (
  # User Identification
  userId STRING NOT NULL,
  
  # Adoption Metrics
  firstStandardCreate TIMESTAMP,
  firstQuickCreate TIMESTAMP,
  firstVoiceInput TIMESTAMP,
  firstTemplateUse TIMESTAMP,
  
  # Usage Counts (lifetime)
  totalStandardCreates INT64 DEFAULT 0,
  totalQuickCreates INT64 DEFAULT 0,
  totalVoiceInputs INT64 DEFAULT 0,
  totalTemplateUses INT64 DEFAULT 0,
  
  # Adoption Status
  hasAdoptedQuickCreate BOOLEAN DEFAULT FALSE,
  hasAdoptedVoiceInput BOOLEAN DEFAULT FALSE,
  hasAdoptedTemplates BOOLEAN DEFAULT FALSE,
  
  # Primary Method
  primaryCreationMethod STRING,  # Determined by most frequent use
  
  # Efficiency Gains
  avgStandardDuration FLOAT64,
  avgQuickCreateDuration FLOAT64,
  avgVoiceInputDuration FLOAT64,
  avgTemplateDuration FLOAT64,
  
  # Last Activity
  lastActivityTimestamp TIMESTAMP,
  
  # Metadata
  updatedAt TIMESTAMP NOT NULL
)
CLUSTER BY userId, primaryCreationMethod;

# View: Creation Method Comparison
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.creation_method_comparison` AS
SELECT
  creationMethod,
  COUNT(*) as total_sessions,
  COUNT(CASE WHEN completed THEN 1 END) as completed_sessions,
  COUNT(CASE WHEN abandoned THEN 1 END) as abandoned_sessions,
  ROUND(COUNT(CASE WHEN completed THEN 1 END) * 100.0 / COUNT(*), 2) as completion_rate_percent,
  ROUND(COUNT(CASE WHEN abandoned THEN 1 END) * 100.0 / COUNT(*), 2) as abandonment_rate_percent,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(STDDEV(CASE WHEN completed THEN durationSeconds END), 2) as stddev_duration_seconds,
  ROUND(APPROX_QUANTILES(CASE WHEN completed THEN durationSeconds END, 100)[OFFSET(50)], 2) as median_duration_seconds,
  ROUND(AVG(CASE WHEN completed THEN interactionCount END), 2) as avg_interactions,
  ROUND(AVG(CASE WHEN completed THEN fieldCount END), 2) as avg_fields_completed,
  ROUND(AVG(CASE WHEN completed THEN validationErrors END), 2) as avg_validation_errors,
  ROUND(AVG(CASE WHEN completed THEN satisfactionImplicit END), 2) as avg_satisfaction_score,
  COUNT(DISTINCT userId) as unique_users
FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
GROUP BY creationMethod
ORDER BY avg_duration_seconds ASC;

# View: Quick Feature Adoption Rate
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.quick_feature_adoption_rate` AS
WITH user_cohorts AS (
  SELECT
    DATE(firstStandardCreate) as cohort_date,
    COUNT(DISTINCT userId) as cohort_size,
    COUNT(DISTINCT CASE WHEN hasAdoptedQuickCreate THEN userId END) as adopted_quick_create,
    COUNT(DISTINCT CASE WHEN hasAdoptedVoiceInput THEN userId END) as adopted_voice_input,
    COUNT(DISTINCT CASE WHEN hasAdoptedTemplates THEN userId END) as adopted_templates
  FROM `aceup-app-123.aceup_analytics.quick_feature_adoption`
  GROUP BY cohort_date
)
SELECT
  cohort_date,
  cohort_size,
  adopted_quick_create,
  adopted_voice_input,
  adopted_templates,
  ROUND(adopted_quick_create * 100.0 / cohort_size, 2) as quick_create_adoption_percent,
  ROUND(adopted_voice_input * 100.0 / cohort_size, 2) as voice_input_adoption_percent,
  ROUND(adopted_templates * 100.0 / cohort_size, 2) as template_adoption_percent,
  ROUND((adopted_quick_create + adopted_voice_input + adopted_templates) * 100.0 / (cohort_size * 3), 2) as overall_feature_adoption_percent
FROM user_cohorts
WHERE cohort_date IS NOT NULL
ORDER BY cohort_date DESC;

# View: Efficiency Gains Analysis
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.efficiency_gains_analysis` AS
SELECT
  userId,
  primaryCreationMethod,
  totalStandardCreates,
  totalQuickCreates,
  totalVoiceInputs,
  totalTemplateUses,
  ROUND(avgStandardDuration, 2) as avg_standard_duration_sec,
  ROUND(avgQuickCreateDuration, 2) as avg_quick_create_duration_sec,
  ROUND(avgVoiceInputDuration, 2) as avg_voice_input_duration_sec,
  ROUND(avgTemplateDuration, 2) as avg_template_duration_sec,
  ROUND((avgStandardDuration - avgQuickCreateDuration) / avgStandardDuration * 100, 2) as quick_create_time_saved_percent,
  ROUND((avgStandardDuration - avgVoiceInputDuration) / avgStandardDuration * 100, 2) as voice_input_time_saved_percent,
  ROUND((avgStandardDuration - avgTemplateDuration) / avgStandardDuration * 100, 2) as template_time_saved_percent,
  ROUND(
    (totalQuickCreates * (avgStandardDuration - avgQuickCreateDuration) +
     totalVoiceInputs * (avgStandardDuration - avgVoiceInputDuration) +
     totalTemplateUses * (avgStandardDuration - avgTemplateDuration)) / 60, 2
  ) as total_minutes_saved,
  lastActivityTimestamp
FROM `aceup-app-123.aceup_analytics.quick_feature_adoption`
WHERE avgStandardDuration IS NOT NULL
  AND avgStandardDuration > 0
  AND (avgQuickCreateDuration IS NOT NULL OR avgVoiceInputDuration IS NOT NULL OR avgTemplateDuration IS NOT NULL)
ORDER BY total_minutes_saved DESC;

# View: Entry Point Analysis
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.entry_point_analysis` AS
SELECT
  entryPoint,
  creationMethod,
  COUNT(*) as session_count,
  ROUND(COUNT(CASE WHEN completed THEN 1 END) * 100.0 / COUNT(*), 2) as completion_rate_percent,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  COUNT(DISTINCT userId) as unique_users
FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
GROUP BY entryPoint, creationMethod
ORDER BY session_count DESC;

# View: Template Effectiveness
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.template_effectiveness` AS
SELECT
  templateId,
  COUNT(*) as usage_count,
  COUNT(CASE WHEN completed THEN 1 END) as completed_count,
  ROUND(COUNT(CASE WHEN completed THEN 1 END) * 100.0 / COUNT(*), 2) as completion_rate_percent,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(AVG(CASE WHEN completed THEN interactionCount END), 2) as avg_interactions,
  ROUND(AVG(CASE WHEN completed THEN satisfactionImplicit END), 2) as avg_satisfaction,
  COUNT(DISTINCT userId) as unique_users,
  MAX(startTimestamp) as last_used_timestamp
FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
WHERE usedTemplate = TRUE
  AND templateId IS NOT NULL
GROUP BY templateId
ORDER BY usage_count DESC;

# View: User Effort Comparison (BQ 3.4 Core Metric)
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.user_effort_comparison` AS
WITH method_stats AS (
  SELECT
    userId,
    creationMethod,
    COUNT(*) as session_count,
    AVG(CASE WHEN completed THEN durationSeconds END) as avg_duration,
    AVG(CASE WHEN completed THEN interactionCount END) as avg_interactions,
    AVG(CASE WHEN completed THEN validationErrors END) as avg_errors,
    COUNT(CASE WHEN abandoned THEN 1 END) as abandon_count
  FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
  GROUP BY userId, creationMethod
),
user_metrics AS (
  SELECT
    userId,
    MAX(CASE WHEN creationMethod = 'standard' THEN avg_duration END) as standard_duration,
    MAX(CASE WHEN creationMethod = 'quick_create' THEN avg_duration END) as quick_duration,
    MAX(CASE WHEN creationMethod = 'standard' THEN avg_interactions END) as standard_interactions,
    MAX(CASE WHEN creationMethod = 'quick_create' THEN avg_interactions END) as quick_interactions,
    MAX(CASE WHEN creationMethod = 'standard' THEN avg_errors END) as standard_errors,
    MAX(CASE WHEN creationMethod = 'quick_create' THEN avg_errors END) as quick_errors,
    SUM(CASE WHEN creationMethod = 'standard' THEN session_count ELSE 0 END) as standard_count,
    SUM(CASE WHEN creationMethod = 'quick_create' THEN session_count ELSE 0 END) as quick_count
  FROM method_stats
  GROUP BY userId
)
SELECT
  userId,
  standard_duration,
  quick_duration,
  ROUND((standard_duration - quick_duration) / standard_duration * 100, 2) as time_reduction_percent,
  standard_interactions,
  quick_interactions,
  ROUND((standard_interactions - quick_interactions) / standard_interactions * 100, 2) as interaction_reduction_percent,
  standard_errors,
  quick_errors,
  standard_count,
  quick_count,
  ROUND(quick_count * 100.0 / (standard_count + quick_count), 2) as quick_usage_percent,
  CASE
    WHEN quick_count > standard_count AND time_reduction_percent > 20 THEN 'strong_adopter'
    WHEN quick_count > 0 AND time_reduction_percent > 10 THEN 'moderate_adopter'
    WHEN quick_count > 0 THEN 'light_adopter'
    ELSE 'non_adopter'
  END as adoption_segment
FROM user_metrics
WHERE standard_duration IS NOT NULL
  AND quick_duration IS NOT NULL
ORDER BY time_reduction_percent DESC;

# View: Daily Feature Usage Trends
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.daily_feature_usage_trends` AS
SELECT
  DATE(startTimestamp) as date,
  creationMethod,
  COUNT(*) as session_count,
  COUNT(CASE WHEN completed THEN 1 END) as completed_count,
  COUNT(DISTINCT userId) as unique_users,
  ROUND(AVG(CASE WHEN completed THEN durationSeconds END), 2) as avg_duration_seconds,
  ROUND(COUNT(CASE WHEN completed THEN 1 END) * 100.0 / COUNT(*), 2) as completion_rate_percent
FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
WHERE startTimestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
GROUP BY date, creationMethod
ORDER BY date DESC, session_count DESC;

# View: Cross-Feature Adoption Patterns
CREATE OR REPLACE VIEW `aceup-app-123.aceup_analytics.cross_feature_adoption_patterns` AS
SELECT
  CASE
    WHEN hasAdoptedQuickCreate AND hasAdoptedVoiceInput AND hasAdoptedTemplates THEN 'all_features'
    WHEN hasAdoptedQuickCreate AND hasAdoptedVoiceInput THEN 'quick_and_voice'
    WHEN hasAdoptedQuickCreate AND hasAdoptedTemplates THEN 'quick_and_template'
    WHEN hasAdoptedVoiceInput AND hasAdoptedTemplates THEN 'voice_and_template'
    WHEN hasAdoptedQuickCreate THEN 'quick_only'
    WHEN hasAdoptedVoiceInput THEN 'voice_only'
    WHEN hasAdoptedTemplates THEN 'template_only'
    ELSE 'standard_only'
  END as adoption_pattern,
  COUNT(DISTINCT userId) as user_count,
  ROUND(AVG(totalQuickCreates + totalVoiceInputs + totalTemplateUses), 2) as avg_quick_method_uses,
  ROUND(AVG(totalStandardCreates), 2) as avg_standard_uses,
  ROUND(AVG(
    COALESCE(avgQuickCreateDuration, 0) + 
    COALESCE(avgVoiceInputDuration, 0) + 
    COALESCE(avgTemplateDuration, 0)
  ) / 3, 2) as avg_quick_duration,
  ROUND(AVG(avgStandardDuration), 2) as avg_standard_duration
FROM `aceup-app-123.aceup_analytics.quick_feature_adoption`
GROUP BY adoption_pattern
ORDER BY user_count DESC;

# Query: Feature Adoption Success Metric (BQ 3.4 KPI)
# Answers: "Would adding quick task creation reduce effort and increase adoption?"
SELECT
  'Overall Metrics' as metric_category,
  COUNT(DISTINCT CASE WHEN hasAdoptedQuickCreate OR hasAdoptedVoiceInput OR hasAdoptedTemplates THEN userId END) as users_adopted_quick_features,
  COUNT(DISTINCT userId) as total_users,
  ROUND(
    COUNT(DISTINCT CASE WHEN hasAdoptedQuickCreate OR hasAdoptedVoiceInput OR hasAdoptedTemplates THEN userId END) * 100.0 / 
    COUNT(DISTINCT userId), 2
  ) as adoption_rate_percent,
  ROUND(AVG(CASE 
    WHEN avgQuickCreateDuration IS NOT NULL OR avgVoiceInputDuration IS NOT NULL OR avgTemplateDuration IS NOT NULL
    THEN avgStandardDuration - COALESCE(avgQuickCreateDuration, avgVoiceInputDuration, avgTemplateDuration)
    ELSE 0 
  END), 2) as avg_time_saved_per_task_seconds,
  ROUND(SUM(
    COALESCE(totalQuickCreates, 0) * COALESCE((avgStandardDuration - avgQuickCreateDuration), 0) +
    COALESCE(totalVoiceInputs, 0) * COALESCE((avgStandardDuration - avgVoiceInputDuration), 0) +
    COALESCE(totalTemplateUses, 0) * COALESCE((avgStandardDuration - avgTemplateDuration), 0)
  ) / 3600, 2) as total_hours_saved_across_all_users
FROM `aceup-app-123.aceup_analytics.quick_feature_adoption`;

# Query: Identify Users Who Would Benefit from Quick Features
SELECT
  userId,
  totalStandardCreates,
  avgStandardDuration as avg_time_spent_seconds,
  ROUND(avgStandardDuration * totalStandardCreates / 60, 2) as total_time_spent_minutes,
  CASE
    WHEN avgStandardDuration > 120 THEN 'high_friction'
    WHEN avgStandardDuration > 60 THEN 'moderate_friction'
    ELSE 'low_friction'
  END as friction_level,
  CASE
    WHEN totalStandardCreates > 20 AND avgStandardDuration > 90 THEN 'priority_candidate'
    WHEN totalStandardCreates > 10 AND avgStandardDuration > 60 THEN 'good_candidate'
    ELSE 'potential_candidate'
  END as quick_feature_candidate_priority
FROM `aceup-app-123.aceup_analytics.quick_feature_adoption`
WHERE hasAdoptedQuickCreate = FALSE
  AND totalStandardCreates > 5
  AND avgStandardDuration IS NOT NULL
ORDER BY total_time_spent_minutes DESC
LIMIT 100;

# Query: ROI Calculation for Quick Features Development
WITH feature_impact AS (
  SELECT
    creationMethod,
    COUNT(DISTINCT userId) as users,
    AVG(CASE WHEN completed THEN durationSeconds END) as avg_duration,
    COUNT(*) as total_uses
  FROM `aceup-app-123.aceup_analytics.task_creation_sessions`
  GROUP BY creationMethod
),
standard_baseline AS (
  SELECT avg_duration as standard_avg FROM feature_impact WHERE creationMethod = 'standard'
)
SELECT
  f.creationMethod,
  f.users as user_count,
  f.total_uses,
  ROUND(f.avg_duration, 2) as avg_duration_seconds,
  ROUND(s.standard_avg - f.avg_duration, 2) as time_saved_per_task_seconds,
  ROUND((s.standard_avg - f.avg_duration) * f.total_uses / 3600, 2) as total_hours_saved,
  ROUND(((s.standard_avg - f.avg_duration) / s.standard_avg) * 100, 2) as efficiency_improvement_percent
FROM feature_impact f
CROSS JOIN standard_baseline s
WHERE f.creationMethod != 'standard'
ORDER BY total_hours_saved DESC;
