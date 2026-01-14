variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "application_name" {
  description = "Name of the application"
  type        = string
  default     = "genai-app"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_private_endpoints" {
  description = "Enable private Google access and VPC Service Controls"
  type        = bool
  default     = true
}

variable "allowed_iap_users" {
  description = "List of users allowed to access via IAP (format: user@domain.com)"
  type        = list(string)
  default     = []
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

variable "notification_email" {
  description = "Email for budget and alert notifications"
  type        = string
}

variable "domain" {
  description = "Organization domain for VPC Service Controls (e.g., example.com). Leave empty to disable VPC-SC."
  type        = string
  default     = ""
}

variable "billing_account_name" {
  description = "Display name of the billing account (used to look up billing account ID)"
  type        = string
  default     = ""
}
