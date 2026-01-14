# AlloyDB for PostgreSQL with pgvector
resource "google_alloydb_instance" "main" {
  cluster       = google_alloydb_cluster.main.name
  instance_id   = "${var.application_name}-primary"
  instance_type = "PRIMARY"

  database_flags = {
    "cloudsql.iam_authentication" = "on"
    "shared_preload_libraries"    = "pgvector"
  }

  depends_on = [
    google_alloydb_cluster.main,
    google_kms_crypto_key.alloydb_encryption
  ]
}

resource "google_alloydb_cluster" "main" {
  cluster_id = "${var.application_name}-cluster"
  location   = var.region
  network    = google_compute_network.main.id

  initial_user {
    user     = "postgres"
    password = random_password.alloydb_password.result
  }

  encryption_config {
    kms_key_name = google_kms_crypto_key.alloydb_encryption.id
  }

  automated_backup_policy {
    location      = var.region
    backup_window = "18000s" # 5-hour window
    enabled       = true

    weekly_schedule {
      days_of_week = ["MONDAY"]

      start_times {
        hours   = 23
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }

    quantity_based_retention {
      count = 14
    }
  }
}

# KMS for AlloyDB encryption
resource "google_kms_crypto_key" "alloydb_encryption" {
  name            = "${var.application_name}-alloydb-key"
  key_ring        = google_kms_key_ring.database.id
  rotation_period = "7776000s"

  # Note: For production use, manually add prevent_destroy = true to lifecycle block
}

resource "google_kms_key_ring" "database" {
  name     = "${var.application_name}-database"
  location = var.region
}

# Generate secure password
resource "random_password" "alloydb_password" {
  length  = 32
  special = false
}

# Store password in Secret Manager
resource "google_secret_manager_secret" "alloydb_password" {
  secret_id = "alloydb-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "alloydb_password" {
  secret      = google_secret_manager_secret.alloydb_password.id
  secret_data = random_password.alloydb_password.result
}

# Note: AlloyDB uses VPC peering via the network specified in the cluster
# Private Service Access is configured using google_service_networking_connection
# if needed, which should be defined in network.tf
