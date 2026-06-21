output "service_account_email" {
  description = "The email address of the service account used by the envive-analytics-sdk-publish module"
  value = module.service.service_account_email
}