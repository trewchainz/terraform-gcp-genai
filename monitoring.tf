# Budget Alert
resource "google_billing_budget" "monthly" {
  billing_account = data.google_billing_account.current.id
  display_name    = "${var.application_name} Monthly Budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.id
    ]
    disable_default_iam_recipients = true
  }
}

# Monitoring Notification Channel
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.application_name} Email Alerts"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# Custom Alert for high API costs
resource "google_monitoring_alert_policy" "gemini_api_cost" {
  display_name = "Gemini API Cost Spike"
  combiner     = "OR"

  conditions {
    display_name = "Vertex AI API cost > $10 per hour"

    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/api/request_count'
        | filter (resource.service == 'aiplatform.googleapis.com')
        | align rate(1h)
        | every 1h
        | group_by [project_id], [value_request_count_aggregate: aggregate(value.request_count)]
        | condition val() > 1000
      EOT
      duration = "60s"
      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "3600s"
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}

# Data source for current billing account
data "google_billing_account" "current" {
  display_name = var.billing_account_name
}
