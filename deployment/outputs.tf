output "project_id" {
  value = google_project.deployment-project.project_id
}

output "project_number" {
  value = google_project.deployment-project.number
}

output "cloudbuild_service_account_id" {
  value = var.environment == "dev" ? google_service_account.cloudbuild_service_account[0].id : null
}

output "cloudbuild_service_account_email" {
  value = var.environment == "dev" ? google_service_account.cloudbuild_service_account[0].email : null
}

output "gke_node_pool_service_account_email" {
  value = google_service_account.gke_node_pool_service_account.email
}

output "spiffy_react_components_publisher_service_account_email" {
  value = module.spiffy-react-components-publisher[0].service_account_email
}

output "google_dns_managed_public_zone_name_servers" {
  value = google_dns_managed_zone.public-zone.name_servers
}

output "google_dns_managed_envive_public_zone_name_servers" {
  value = google_dns_managed_zone.public-zone-envive.name_servers
}

output "envive_analytics_sdk_publisher_service_account_email" {
  value = module.envive-analytics-sdk-publisher[0].service_account_email
}

output "api_internal_service_account_email" {
  value = module.api-internal[0].google_service_account_email
}

output "github_actions_wif_provider" {
  description = "WIF provider resource name — set as WIF_PROVIDER_DEV or WIF_PROVIDER_PROD in GitHub Secrets"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "github_actions_tf_plan_sa_email" {
  description = "SA email — set as SA_EMAIL_DEV or SA_EMAIL_PROD in GitHub Secrets"
  value       = google_service_account.github_actions_tf_plan.email
}
