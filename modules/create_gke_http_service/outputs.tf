output "kubernetes_service_account" {
  value = kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name
}

output "kubernetes_deployment_target_ref" {
  value = kubernetes_deployment_v1.kubernetes_app_deployment[0].metadata[0].name
}