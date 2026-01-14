# VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "main" {
  name          = "${var.application_name}-connector"
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 2)
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "genai_app" {
  name     = "${var.application_name}-service"
  location = var.region

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      # Environment variables
      env {
        name  = "GEMINI_API_KEY_SECRET"
        value = google_secret_manager_secret.gemini_api_key.secret_id
      }

      env {
        name  = "DATABASE_SECRET"
        value = google_secret_manager_secret.alloydb_password.secret_id
      }

      env {
        name  = "DATABASE_HOST"
        value = google_alloydb_instance.main.ip_address
      }

      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.rag_documents.name
      }

      # Resource limits
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    # Service account
    service_account = google_service_account.cloud_run.email

    # VPC Access
    vpc_access {
      connector = google_vpc_access_connector.main.id
      egress    = "ALL_TRAFFIC"
    }

    # Max instances for cost control
    max_instance_request_concurrency = 80
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Disallow public access - only via IAP
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
}

# Backend service for IAP
resource "google_compute_backend_service" "main" {
  name      = "${var.application_name}-backend"
  port_name = "http"
  protocol  = "HTTP"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.self_link
  }

  # IAP configuration - Uncomment after creating OAuth credentials manually
  # See security.tf for manual setup instructions
  # iap {
  #   oauth2_client_id     = "YOUR_CLIENT_ID_HERE"
  #   oauth2_client_secret = "YOUR_CLIENT_SECRET_HERE"
  # }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "${var.application_name}-cloud-run-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.genai_app.name
  }
}
