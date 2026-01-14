# Integration Test Example
# This test actually creates resources (use with caution and cleanup)
# Run with: terraform test -filter=integration

# Mock provider configuration for testing
mock_provider "google" {}

mock_provider "google-beta" {}

variables {
  project_id         = "your-test-project-id"  # Replace with actual test project
  region             = "us-central1"
  zone               = "us-central1-a"
  environment        = "dev"
  application_name   = "genai-test"
  vpc_cidr           = "10.10.0.0/16"
  notification_email = "test@example.com"
  allowed_iap_users  = []
  budget_amount      = 10
}

# Integration test - creates actual resources
run "integration_test_vpc" {
  command = apply

  # This will actually create resources in GCP
  # Make sure to run terraform destroy after!

  assert {
    condition     = google_compute_network.main.id != ""
    error_message = "VPC should be created successfully"
  }

  assert {
    condition     = google_compute_subnetwork.private.id != ""
    error_message = "Private subnet should be created"
  }
}

# Note: After running integration tests, manually destroy resources with:
# terraform destroy -auto-approve
