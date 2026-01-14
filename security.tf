# Service Account for Cloud Run
resource "google_service_account" "cloud_run" {
  account_id   = "${var.application_name}-cloud-run"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run GenAI application"
}

# IAM Roles for Cloud Run SA
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# IAP (Identity-Aware Proxy) Setup
# Note: IAP OAuth brand and client require manual setup in GCP Console
# 
# Manual Steps Required:
# 1. Go to: https://console.cloud.google.com/apis/credentials/consent
# 2. Create OAuth consent screen
# 3. Create OAuth 2.0 Client ID for Web application
# 4. Add authorized redirect URIs for IAP
# 5. Update the iap block in compute.tf with your client_id and client_secret
#
# After manual setup, uncomment and configure below:

# IAM Policy for IAP - Grants users access through IAP
resource "google_iap_web_backend_service_iam_binding" "main" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.main.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = formatlist("user:%s", var.allowed_iap_users)
}

# Secret for API keys
resource "google_secret_manager_secret" "gemini_api_key" {
  secret_id = "gemini-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    application = var.application_name
  }
}

# Generate a placeholder secret (in production, use proper secret management)
resource "google_secret_manager_secret_version" "gemini_api_key" {
  secret = google_secret_manager_secret.gemini_api_key.id

  secret_data = "placeholder-replace-with-real-key"
}

# Network security - deny all egress by default, allow specific
resource "google_compute_firewall" "deny_all_egress" {
  name      = "${var.application_name}-${var.environment}-deny-all-egress"
  network   = google_compute_network.main.name
  direction = "EGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_private_egress" {
  name      = "${var.application_name}-${var.environment}-allow-private-egress"
  network   = google_compute_network.main.name
  direction = "EGRESS"
  priority  = 1000

  allow {
    protocol = "all"
  }

  destination_ranges = [var.vpc_cidr]
}

resource "google_compute_firewall" "allow_cloud_apis" {
  name      = "${var.application_name}-${var.environment}-allow-cloud-apis"
  network   = google_compute_network.main.name
  direction = "EGRESS"
  priority  = 1001

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  destination_ranges = ["199.36.153.8/30"] # Restricted Google APIs range
}
