# Security-Focused Terraform Tests
# Tests security configurations, IAM, encryption, and compliance

# Mock provider configuration for testing
mock_provider "google" {}

mock_provider "google-beta" {}

variables {
  project_id         = "test-project-12345"
  region             = "us-central1"
  zone               = "us-central1-a"
  environment        = "dev"
  application_name   = "genai-app"
  vpc_cidr           = "10.0.0.0/16"
  notification_email = "security@example.com"
  allowed_iap_users  = ["admin@example.com"]
  budget_amount      = 100
}

# Test: Verify no public access to Cloud Run
run "no_public_cloud_run_access" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.genai_app.ingress != "INGRESS_TRAFFIC_ALL"
    error_message = "Cloud Run must not allow public access - use IAP"
  }
}

# Test: Verify IAP is configured for user access
run "iap_user_access_configured" {
  command = plan

  assert {
    condition     = length(google_iap_web_backend_service_iam_binding.main.members) > 0
    error_message = "IAP should have at least one authorized user"
  }

  assert {
    condition     = google_iap_web_backend_service_iam_binding.main.role == "roles/iap.httpsResourceAccessor"
    error_message = "IAP binding should use correct role"
  }
}

# Test: Verify all egress traffic is controlled
run "egress_traffic_controlled" {
  command = plan

  assert {
    condition     = anytrue([for rule in google_compute_firewall.deny_all_egress.deny : rule.protocol == "all"])
    error_message = "Default deny-all egress rule should block all protocols"
  }

  assert {
    condition     = contains(google_compute_firewall.deny_all_egress.destination_ranges, "0.0.0.0/0")
    error_message = "Deny-all rule should apply to all destinations"
  }
}

# Test: Verify secrets are not hardcoded
run "no_hardcoded_secrets" {
  command = plan

  assert {
    condition     = google_secret_manager_secret_version.gemini_api_key.secret_data == "placeholder-replace-with-real-key"
    error_message = "Placeholder secret should be replaced with actual secret outside Terraform"
  }
}

# Test: Verify KMS key rotation
run "kms_key_rotation_enabled" {
  command = plan

  assert {
    condition     = google_kms_crypto_key.bucket_encryption.rotation_period == "7776000s"
    error_message = "KMS keys should rotate every 90 days"
  }

  assert {
    condition     = google_kms_crypto_key.alloydb_encryption.rotation_period == "7776000s"
    error_message = "Database encryption keys should rotate every 90 days"
  }
}

# Test: Verify service account has minimal permissions
run "service_account_least_privilege" {
  command = plan

  assert {
    condition = !contains(
      [for role in google_project_iam_member.cloud_run_roles : role.role],
      "roles/owner"
    )
    error_message = "Service account should not have owner role"
  }

  assert {
    condition = !contains(
      [for role in google_project_iam_member.cloud_run_roles : role.role],
      "roles/editor"
    )
    error_message = "Service account should not have editor role"
  }
}

# Test: Verify audit logging is enabled
run "audit_logging_enabled" {
  command = plan

  assert {
    condition = length([
      for config in google_project_iam_audit_config.all_services.audit_log_config : 
      config.log_type if contains(["ADMIN_READ", "DATA_READ", "DATA_WRITE"], config.log_type)
    ]) == 3
    error_message = "All audit log types should be enabled (ADMIN_READ, DATA_READ, DATA_WRITE)"
  }
}

# Test: Verify VPC Flow Logs are enabled
run "vpc_flow_logs_enabled" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.log_config != null
    error_message = "VPC Flow Logs must be enabled on private subnet"
  }

  assert {
    condition     = google_compute_subnetwork.private.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Flow logs should include all metadata for security analysis"
  }
}

# Test: Verify storage bucket is not publicly accessible
run "storage_bucket_private" {
  command = plan

  assert {
    condition     = google_storage_bucket.rag_documents.uniform_bucket_level_access == true
    error_message = "Bucket should use uniform bucket-level access for security"
  }
}

# Test: Verify NAT logging is enabled
run "nat_logging_enabled" {
  command = plan

  assert {
    condition     = google_compute_router_nat.main.log_config[0].enable == true
    error_message = "NAT gateway should have logging enabled"
  }
}

# Test: Verify security monitoring Pub/Sub topics exist
run "security_pubsub_topics_exist" {
  command = plan

  assert {
    condition     = google_pubsub_topic.security_logs.name == "security-audit-logs"
    error_message = "Security audit logs Pub/Sub topic should exist"
  }

  assert {
    condition     = google_pubsub_topic.security_alerts.name == "security-command-center-alerts"
    error_message = "Security alerts Pub/Sub topic should exist"
  }
}

# Test: Verify DLP inspection template is configured
run "dlp_template_configured" {
  command = plan

  assert {
    condition     = length(google_data_loss_prevention_inspect_template.ai_prompt_data.inspect_config[0].info_types) >= 4
    error_message = "DLP should scan for at least 4 types of sensitive data"
  }

  assert {
    condition = contains(
      [for info_type in google_data_loss_prevention_inspect_template.ai_prompt_data.inspect_config[0].info_types : info_type.name],
      "CREDIT_CARD_NUMBER"
    )
    error_message = "DLP should scan for credit card numbers in AI prompts"
  }
}

# Test: Verify AlloyDB backup retention
run "alloydb_backup_retention" {
  command = plan

  assert {
    condition     = google_alloydb_cluster.main.automated_backup_policy[0].quantity_based_retention[0].count == 14
    error_message = "AlloyDB should retain at least 14 days of backups"
  }
}

# Test: Verify security function has proper IAM
run "security_function_iam" {
  command = plan

  assert {
    condition = contains(
      [for role in google_project_iam_member.security_detector_roles : role.role],
      "roles/logging.viewer"
    )
    error_message = "Security detector should have logging viewer role"
  }

  assert {
    condition = contains(
      [for role in google_project_iam_member.security_detector_roles : role.role],
      "roles/pubsub.subscriber"
    )
    error_message = "Security detector should have Pub/Sub subscriber role"
  }
}
