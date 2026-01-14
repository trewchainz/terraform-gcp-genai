# Mock provider configuration for Terraform tests
# This allows tests to run without real GCP credentials

mock_provider "google" {
  # Mock the google provider to avoid needing real credentials
  # Tests will use plan mode which doesn't require actual API calls
}

mock_provider "google-beta" {
  # Mock the google-beta provider
}

mock_provider "random" {
  # Mock the random provider
}
