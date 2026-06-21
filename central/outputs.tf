output "project_id" {
  value = google_project.deployment-central.project_id
}

output "central_env_project_folder_id" {
  value = google_folder.spiffy-org-eng-gcp-env-central-folder.id
}

output "dev_env_project_folder_id" {
  value = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
}

output "prod_env_project_folder_id" {
  value = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
}

output "github_actions_wif_provider" {
  description = "WIF provider resource name — set as WIF_PROVIDER_CENTRAL in GitHub Secrets"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "github_actions_tf_plan_sa_email" {
  description = "SA email — set as SA_EMAIL_CENTRAL in GitHub Secrets"
  value       = google_service_account.github_actions_tf_plan.email
}

