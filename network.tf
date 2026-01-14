# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.application_name}-${var.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  delete_default_routes_on_create = false
}

# Subnet for private services
resource "google_compute_subnetwork" "private" {
  name          = "${var.application_name}-${var.environment}-private"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 0)
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = var.enable_private_endpoints

  # Enable VPC Flow Logs for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Subnet for public services (if needed)
resource "google_compute_subnetwork" "public" {
  name          = "${var.application_name}-${var.environment}-public"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, 1)
  region        = var.region
  network       = google_compute_network.main.id
}

# Cloud Router for private Google access
resource "google_compute_router" "main" {
  name    = "${var.application_name}-${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.id

  bgp {
    asn = 64514
  }
}

# NAT Gateway for private instances to access internet
resource "google_compute_router_nat" "main" {
  name                               = "${var.application_name}-${var.environment}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# VPC Service Controls (if enabled) - Critical for AI/security
resource "google_access_context_manager_service_perimeter" "main" {
  count = var.enable_private_endpoints && var.domain != "" ? 1 : 0

  parent = "accessPolicies/${google_access_context_manager_access_policy.main[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.main[0].name}/servicePerimeters/${var.application_name}-${var.environment}"
  title  = "${var.application_name}-${var.environment}-perimeter"

  # Restrict services to only those needed
  status {
    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com",
      "aiplatform.googleapis.com",
      "secretmanager.googleapis.com",
      "run.googleapis.com"
    ]

    # Allow access only from our VPC
    access_levels = [google_access_context_manager_access_level.main[0].name]
  }
}

resource "google_access_context_manager_access_policy" "main" {
  count = var.enable_private_endpoints && var.domain != "" ? 1 : 0

  parent = "organizations/${data.google_organization.current.org_id}"
  title  = "${var.application_name}-${var.environment}-policy"
}

resource "google_access_context_manager_access_level" "main" {
  count = var.enable_private_endpoints && var.domain != "" ? 1 : 0

  parent = "accessPolicies/${google_access_context_manager_access_policy.main[0].name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.main[0].name}/accessLevels/${var.application_name}-${var.environment}"
  title  = "${var.application_name}-${var.environment}-access"

  basic {
    conditions {
      ip_subnetworks = [var.vpc_cidr]
    }
  }
}

# Data source for organization
data "google_organization" "current" {
  domain = var.domain
}
