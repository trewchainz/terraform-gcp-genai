# ============================================================================
# SECURITY AUDIT & MONITORING
# ============================================================================

# 1. CLOUD AUDIT LOGS CONFIGURATION
# ----------------------------------------------------------------------------
# Enable all audit log types
resource "google_project_iam_audit_config" "all_services" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# 2. LOG ROUTER TO PUB/SUB (For Security Operations)
# ----------------------------------------------------------------------------
# Create Pub/Sub topic for security logs
resource "google_pubsub_topic" "security_logs" {
  name = "security-audit-logs"

  message_retention_duration = "86600s" # 24 hours + buffer

  labels = {
    environment = var.environment
    security    = "critical"
  }
}

# IAM for Log Router service account
resource "google_pubsub_topic_iam_member" "log_router_pub" {
  topic  = google_pubsub_topic.security_logs.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_project.current.number}@gcp-sa-logging.iam.gserviceaccount.com"
}

# Log Router sink to Pub/Sub
resource "google_logging_project_sink" "security_audit" {
  name        = "security-audit-to-pubsub"
  destination = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.security_logs.name}"

  # Comprehensive security filter
  filter = <<-EOT
    (
      # Admin activity
      protoPayload.serviceName="cloudresourcemanager.googleapis.com" OR
      protoPayload.serviceName="iam.googleapis.com" OR
      protoPayload.serviceName="kms.googleapis.com" OR
      protoPayload.serviceName="secretmanager.googleapis.com" OR
      
      # Data access
      protoPayload.serviceName="aiplatform.googleapis.com" OR
      protoPayload.serviceName="alloydb.googleapis.com" OR
      protoPayload.serviceName="storage.googleapis.com" OR
      
      # Network security
      protoPayload.serviceName="compute.googleapis.com" AND
      (
        protoPayload.methodName:"firewall" OR
        protoPayload.methodName:"setIamPolicy" OR
        protoPayload.methodName:"setNetworkPolicy"
      )
    )
    AND
    (
      logName:"activity" OR
      logName:"data_access"
    )
  EOT

  unique_writer_identity = true
}

# 3. VPC FLOW LOGS (Network Security)
# ----------------------------------------------------------------------------
# Flow logs are already enabled in network.tf with enhanced configuration

# 4. DNS LOGGING (Threat Detection)
# ----------------------------------------------------------------------------
resource "google_dns_managed_zone" "internal" {
  count = var.enable_dns_logging ? 1 : 0

  name        = "${var.application_name}-internal"
  dns_name    = "${var.application_name}.internal."
  description = "Internal DNS zone for GenAI application"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.main.id
    }
  }

  # Enable DNS logging
  cloud_logging_config {
    enable_logging = true
  }
}

# 5. SECURITY COMMAND CENTER (Premium)
# ----------------------------------------------------------------------------
# Enable Security Command Center Premium
# resource "google_security_center_notification_config" "high_severity" {
#   config_id    = "high-severity-findings"
#   organization = data.google_organization.current.org_id
# 
#   description  = "Notification config for high severity findings"
#   pubsub_topic = google_pubsub_topic.security_alerts.id
# 
#   streaming_config {
#     filter = "severity=\"HIGH\" OR severity=\"CRITICAL\""
#   }
# }

# Pub/Sub for security alerts
resource "google_pubsub_topic" "security_alerts" {
  name = "security-command-center-alerts"

  message_retention_duration = "604800s" # 7 days for alerts

  labels = {
    environment = var.environment
    security    = "critical"
    source      = "scc"
  }
}

# 6. GOOGLE SECURITY OPERATIONS (Chronicle) INTEGRATION
# ----------------------------------------------------------------------------
# Note: Chronicle integration requires manual setup in console
# but we can prepare the infrastructure

# Service account for Chronicle ingestion
resource "google_service_account" "chronicle_ingestion" {
  account_id   = "chronicle-ingestion"
  display_name = "Chronicle Log Ingestion Service Account"
  description  = "Service account for Google Security Operations log ingestion"
}

# IAM role for Chronicle
resource "google_project_iam_member" "chronicle_log_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.chronicle_ingestion.email}"
}

resource "google_project_iam_member" "chronicle_pubsub_sub" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.chronicle_ingestion.email}"
}

# 7. SECURITY ANALYTICS IN BIGQUERY (Optional - for custom detection)
# ----------------------------------------------------------------------------
# Only for security team custom analytics, not primary audit trail
resource "google_bigquery_dataset" "security_analytics" {
  dataset_id    = "security_analytics"
  friendly_name = "Security Analytics"
  description   = "Security data for custom threat detection and analytics"
  location      = var.region

  labels = {
    environment    = var.environment
    sensitivity    = "high"
    classification = "confidential"
  }

  # Enable CMEK
  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.security_analytics.id
  }

  # Set default table expiration
  default_table_expiration_ms = 30 * 24 * 60 * 60 * 1000 # 30 days
}

# KMS key ring for security data
resource "google_kms_key_ring" "security" {
  name     = "${var.application_name}-security"
  location = var.region
}

# KMS for security analytics dataset
resource "google_kms_crypto_key" "security_analytics" {
  name            = "security-analytics-key"
  key_ring        = google_kms_key_ring.security.id
  rotation_period = "2592000s" # 30 days for security data

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  # Note: For production use, manually add prevent_destroy = true to lifecycle block
}

# 8. REAL-TIME SECURITY DETECTIONS
# ----------------------------------------------------------------------------
# Cloud Function for real-time security event processing
resource "google_cloudfunctions2_function" "security_detector" {
  name        = "security-event-detector"
  location    = var.region
  description = "Real-time security event detection and alerting"

  build_config {
    runtime     = "python311"
    entry_point = "detect_threats"

    source {
      storage_source {
        bucket = google_storage_bucket.security_functions.name
        object = google_storage_bucket_object.security_detector.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds    = 60

    service_account_email = google_service_account.security_detector.email

    environment_variables = {
      SECURITY_TEAM_SLACK_WEBHOOK = var.security_slack_webhook
      CRITICAL_SEVERITY_THRESHOLD = "0.8"
    }

    vpc_connector = google_vpc_access_connector.security_functions.id
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.security_logs.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

# Storage bucket for security Cloud Functions code
resource "google_storage_bucket" "security_functions" {
  name                        = "${var.project_id}-${var.application_name}-security-functions"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.environment != "prod"

  labels = {
    environment = var.environment
    application = var.application_name
    purpose     = "security-functions"
  }
}

# Placeholder for security detector function code
resource "google_storage_bucket_object" "security_detector" {
  name   = "security-detector-source.zip"
  bucket = google_storage_bucket.security_functions.name
  source = "${path.module}/functions/security-detector.zip"
}

# Service account for security detector function
resource "google_service_account" "security_detector" {
  account_id   = "security-detector"
  display_name = "Security Event Detector"
  description  = "Service account for security event detection function"
}

# IAM for security detector
resource "google_project_iam_member" "security_detector_roles" {
  for_each = toset([
    "roles/logging.viewer",
    "roles/pubsub.subscriber",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.security_detector.email}"
}

# VPC connector for security functions
resource "google_vpc_access_connector" "security_functions" {
  name          = "security-functions-connector"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 10) # Dedicated subnet
}

# 9. SECURITY ALERTING & NOTIFICATION
# ----------------------------------------------------------------------------
# Security Notification Channels
resource "google_monitoring_notification_channel" "security_slack" {
  display_name = "Security Team Slack"
  type         = "slack"

  labels = {
    channel_name = "#security-alerts"
  }

  sensitive_labels {
    auth_token = var.slack_auth_token
  }
}

resource "google_monitoring_notification_channel" "security_pagerduty" {
  display_name = "Security PagerDuty"
  type         = "pagerduty"

  labels = {
    routing_key = var.pagerduty_routing_key
  }
}

# Critical Security Alert Policies
resource "google_monitoring_alert_policy" "unusual_iam_activity" {
  display_name = "Unusual IAM Activity Detected"
  combiner     = "OR"

  conditions {
    display_name = "IAM policy changes outside business hours"

    condition_monitoring_query_language {
      query    = <<-EOT
        fetch gce_instance
        | metric 'logging.googleapis.com/user/iam-policy-change'
        | align rate(5m)
        | every 5m
        | condition val() > 0
        | group_by [resource.project_id], [value_iam_changes_mean: mean(value.iam_changes)]
      EOT
      duration = "300s"
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s" # Max 1 notification per hour
    }
    auto_close = "21600s" # 6 hours
  }

  notification_channels = [
    google_monitoring_notification_channel.security_slack.name,
    google_monitoring_notification_channel.email.name
  ]
}

# 10. DATA LOSS PREVENTION (DLP) - For sensitive AI data
# ----------------------------------------------------------------------------
# DLP inspection templates
resource "google_data_loss_prevention_inspect_template" "ai_prompt_data" {
  parent      = "projects/${var.project_id}/locations/${var.region}"
  description = "Inspect AI prompt data for sensitive information"

  inspect_config {
    info_types {
      name = "EMAIL_ADDRESS"
    }

    info_types {
      name = "PERSON_NAME"
    }

    info_types {
      name = "PHONE_NUMBER"
    }

    info_types {
      name = "CREDIT_CARD_NUMBER"
    }

    limits {
      max_findings_per_item    = 10
      max_findings_per_request = 100
    }

    rule_set {
      info_types {
        name = "EMAIL_ADDRESS"
      }

      rules {
        exclusion_rule {
          regex {
            pattern = ".*@example\\.com"
          }
          matching_type = "MATCHING_TYPE_FULL_MATCH"
        }
      }
    }
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "google_project" "current" {}

# ============================================================================
# VARIABLES
# ============================================================================

variable "enable_dns_logging" {
  description = "Enable DNS query logging for threat detection"
  type        = bool
  default     = true
}

variable "security_slack_webhook" {
  description = "Slack webhook URL for security alerts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_auth_token" {
  description = "Slack authentication token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_routing_key" {
  description = "PagerDuty routing key for critical alerts"
  type        = string
  sensitive   = true
  default     = ""
}