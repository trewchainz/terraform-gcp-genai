output "cloud_run_url" {
  description = "URL of the Cloud Run service (behind IAP)"
  value       = google_cloud_run_v2_service.genai_app.uri
  sensitive   = true
}

output "alloydb_connection_name" {
  description = "AlloyDB instance connection name"
  value       = google_alloydb_instance.main.name
  sensitive   = true
}

output "storage_bucket" {
  description = "Name of the RAG documents storage bucket"
  value       = google_storage_bucket.rag_documents.name
}

output "secret_names" {
  description = "Names of created secrets"
  value = {
    gemini_api_key   = google_secret_manager_secret.gemini_api_key.secret_id
    alloydb_password = google_secret_manager_secret.alloydb_password.secret_id
  }
  sensitive = true
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.main.name
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
}

output "iap_access_instructions" {
  description = "Instructions for accessing the application via IAP"
  value       = <<-EOT
    Application is secured with IAP.
    Access URL: ${google_cloud_run_v2_service.genai_app.uri}
    
    To access:
    1. Ensure your email (${join(", ", var.allowed_iap_users)}) is in allowed users
    2. Visit: https://console.cloud.google.com/security/iap
    3. Select the backend service: ${google_compute_backend_service.main.name}
    4. Add your user with 'IAP-secured Web App User' role
    
    Or use the IAP desktop proxy:
    gcloud beta iap web --project=${var.project_id} --resource-type=backend-services --service=${google_compute_backend_service.main.name}
  EOT
}
