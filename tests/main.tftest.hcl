# Terraform Test Suite for GCP GenAI Infrastructure
# Run with: terraform test

# Mock provider configuration for testing
mock_provider "google" {}

mock_provider "google-beta" {}

# Test variables
variables {
  project_id         = "test-project-12345"
  region             = "us-central1"
  zone               = "us-central1-a"
  environment        = "dev"
  application_name   = "genai-app"
  vpc_cidr           = "10.0.0.0/16"
  notification_email = "test@example.com"
  allowed_iap_users  = ["user1@example.com", "user2@example.com"]
  budget_amount      = 100
  domain             = ""
  billing_account_name = ""
}

# Test 1: Validate VPC Network Configuration
run "validate_vpc_network" {
  command = plan

  assert {
    condition     = google_compute_network.main.name == "genai-app-dev"
    error_message = "VPC network name should follow naming convention: ${var.application_name}-${var.environment}"
  }

  assert {
    condition     = google_compute_network.main.auto_create_subnetworks == false
    error_message = "Auto-create subnetworks should be disabled for security"
  }

  assert {
    condition     = google_compute_network.main.routing_mode == "REGIONAL"
    error_message = "Routing mode should be REGIONAL for cost optimization"
  }
}

# Test 2: Validate Subnet Configuration
run "validate_subnets" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.private_ip_google_access == true
    error_message = "Private subnet should have Google API access enabled"
  }

  assert {
    condition     = google_compute_subnetwork.private.log_config[0].aggregation_interval == "INTERVAL_10_MIN"
    error_message = "VPC Flow Logs should be enabled with 10-minute aggregation"
  }

  assert {
    condition     = google_compute_subnetwork.private.log_config[0].flow_sampling == 0.5
    error_message = "Flow sampling should be set to 50% for cost optimization"
  }
}

# Test 3: Validate Cloud Run Security Configuration
run "validate_cloud_run_security" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.genai_app.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "Cloud Run should only accept traffic from internal load balancer (IAP)"
  }


  assert {
    condition     = google_cloud_run_v2_service.genai_app.template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    error_message = "All Cloud Run traffic should go through VPC for security"
  }
}

# Test 4: Validate IAM Least Privilege
run "validate_cloud_run_iam" {
  command = plan

  assert {
    condition = alltrue([
      for role in google_project_iam_member.cloud_run_roles : 
      contains([
        "roles/aiplatform.user",
        "roles/secretmanager.secretAccessor",
        "roles/storage.objectViewer",
        "roles/cloudsql.client",
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ], role.role)
    ])
    error_message = "Cloud Run service account should only have necessary roles"
  }
}

# Test 5: Validate Encryption at Rest
run "validate_encryption" {
  command = plan


  assert {
    condition     = google_kms_crypto_key.alloydb_encryption.rotation_period == "7776000s"
    error_message = "KMS keys should rotate every 90 days (7776000s)"
  }
}

# Test 6: Validate Secret Management
run "validate_secrets" {
  command = plan

  assert {
    condition     = google_secret_manager_secret.gemini_api_key.replication[0].auto != null
    error_message = "Secrets should use automatic replication"
  }

  assert {
    condition     = google_secret_manager_secret.alloydb_password.replication[0].auto != null
    error_message = "Database password should be stored in Secret Manager"
  }

  assert {
    condition     = random_password.alloydb_password.length == 32
    error_message = "Database password should be at least 32 characters"
  }
}

# Test 7: Validate Monitoring and Alerting
run "validate_monitoring" {
  command = plan

  assert {
    condition     = google_billing_budget.monthly.amount[0].specified_amount[0].units == tostring(var.budget_amount)
    error_message = "Budget should be set to configured amount"
  }

  assert {
    condition     = length(google_billing_budget.monthly.threshold_rules) >= 3
    error_message = "Budget should have multiple threshold alerts (50%, 90%, 100%)"
  }

  assert {
    condition     = google_monitoring_notification_channel.email.type == "email"
    error_message = "Email notification channel should be configured"
  }
}

# Test 8: Validate Network Security
run "validate_firewall_rules" {
  command = plan

  assert {
    condition     = google_compute_firewall.deny_all_egress.priority == 65534
    error_message = "Deny-all egress rule should have lowest priority"
  }

  assert {
    condition     = google_compute_firewall.allow_private_egress.priority < google_compute_firewall.deny_all_egress.priority
    error_message = "Allow rules should have higher priority than deny-all"
  }

  assert {
    condition     = google_compute_firewall.allow_cloud_apis.direction == "EGRESS"
    error_message = "Cloud APIs firewall rule should be egress"
  }
}

# Test 9: Validate Resource Naming Conventions
run "validate_naming_conventions" {
  command = plan

  assert {
    condition = alltrue([
      startswith(google_compute_network.main.name, var.application_name),
      endswith(google_compute_network.main.name, var.environment)
    ])
    error_message = "Resources should follow naming convention: {app}-{env}"
  }

  assert {
    condition     = startswith(google_storage_bucket.rag_documents.name, var.project_id)
    error_message = "Storage buckets should be prefixed with project ID for global uniqueness"
  }
}

# Test 10: Validate AlloyDB Configuration
run "validate_alloydb" {
  command = plan

  assert {
    condition     = google_alloydb_instance.main.instance_type == "PRIMARY"
    error_message = "AlloyDB instance should be PRIMARY type"
  }

  assert {
    condition     = google_alloydb_instance.main.database_flags["cloudsql.iam_authentication"] == "on"
    error_message = "AlloyDB should have IAM authentication enabled"
  }

  assert {
    condition     = google_alloydb_instance.main.database_flags["shared_preload_libraries"] == "pgvector"
    error_message = "AlloyDB should have pgvector extension enabled for RAG"
  }

  assert {
    condition     = google_alloydb_cluster.main.automated_backup_policy[0].enabled == true
    error_message = "AlloyDB should have automated backups enabled"
  }
}

# Test 11: Validate VPC Service Controls (when enabled)
run "validate_vpc_sc_conditional" {
  command = plan

  variables {
    domain = "example.com"
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.main) == 1
    error_message = "VPC Service Controls should be created when domain is provided"
  }
}

run "validate_vpc_sc_disabled" {
  command = plan

  variables {
    domain = ""
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.main) == 0
    error_message = "VPC Service Controls should not be created when domain is empty"
  }
}

# Test 12: Validate Environment-Specific Configuration
run "validate_dev_environment" {
  command = plan

  variables {
    environment = "dev"
  }

  assert {
    condition     = google_storage_bucket.rag_documents.force_destroy == true
    error_message = "Dev environment buckets should allow force destroy"
  }
}

run "validate_prod_environment" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = google_storage_bucket.rag_documents.force_destroy == false
    error_message = "Production buckets should not allow force destroy"
  }
}

# Test 13: Validate API Enablement
run "validate_required_apis" {
  command = plan

  assert {
    condition = alltrue([
      google_project_service.aiplatform.service == "aiplatform.googleapis.com",
      google_project_service.run.service == "run.googleapis.com",
      google_project_service.secretmanager.service == "secretmanager.googleapis.com",
      google_project_service.alloydb.service == "alloydb.googleapis.com"
    ])
    error_message = "All required GCP APIs should be enabled"
  }
}

# Test 14: Validate Storage Lifecycle
run "validate_storage_lifecycle" {
  command = plan

  assert {
    condition     = google_storage_bucket.rag_documents.versioning[0].enabled == true
    error_message = "Storage bucket should have versioning enabled"
  }

  assert {
    condition     = anytrue([for rule in google_storage_bucket.rag_documents.lifecycle_rule : anytrue([for cond in rule.condition : cond.age == 30])])
    error_message = "Old objects should be deleted after 30 days"
  }
}

# Test 15: Validate Labels
run "validate_resource_labels" {
  command = plan

  assert {
    condition = alltrue([
      google_storage_bucket.rag_documents.labels["environment"] == var.environment,
      google_storage_bucket.rag_documents.labels["application"] == var.application_name
    ])
    error_message = "Resources should have consistent labels for environment and application"
  }
}
