# Bucket for RAG documents
resource "google_storage_bucket" "rag_documents" {
  name                        = "${var.project_id}-${var.application_name}-rag-docs"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.environment != "prod"

  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_encryption.id
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    application = var.application_name
  }
}

# CMEK for bucket encryption
resource "google_kms_key_ring" "storage" {
  name     = "${var.application_name}-storage"
  location = var.region
}

resource "google_kms_crypto_key" "bucket_encryption" {
  name            = "${var.application_name}-bucket-key"
  key_ring        = google_kms_key_ring.storage.id
  rotation_period = "7776000s" # 90 days

  # Note: For production use, manually add prevent_destroy = true to lifecycle block
}

# IAM for bucket access
resource "google_storage_bucket_iam_member" "cloud_run_access" {
  bucket = google_storage_bucket.rag_documents.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_run.email}"
}
