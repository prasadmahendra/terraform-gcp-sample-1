locals {
  gke_cluster_enabled                      = true
  gke_workload_namespace_for_llm_apps      = "apps-llm-ns"
  gke_workload_namespace_for_services_apps = "apps-services-ns"
  gke_all_workload_namespaces = [
    local.gke_workload_namespace_for_llm_apps,
    local.gke_workload_namespace_for_services_apps,
  ]
}

resource "google_service_account" "gke_node_pool_service_account" {
  account_id   = "gke-nodepool-default-sa"
  display_name = "GKE node pool default SA"
}

# Give GKE node pool service account the ability to create log entries and others

resource "google_project_iam_custom_role" "gke_node_pool_service_account_custom_role" {
  role_id     = "spiffy.gkeNodePoolServiceAccountRole"
  project     = var.project_id
  title       = "Spiffy - GKE node pool role"
  description = "Spiffy - GKE node pool role (Managed by Terraform)"
  permissions = [
    "logging.logEntries.create",
    "monitoring.timeSeries.create",
    "monitoring.metricDescriptors.create",
    "storage.objects.list",
    "storage.objects.get",
    #"storage.objects.update",
    #"storage.objects.create",
  ]
}

resource "google_project_iam_member" "gke_node_pool_service_account_custom_role_member" {

  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.gke_node_pool_service_account_custom_role.id
  member  = "serviceAccount:${google_service_account.gke_node_pool_service_account.email}"
}

resource "google_project_iam_member" "gke_node_pool_service_account_custom_role_member_traffic_dir" {

  project = google_project.deployment-project.project_id
  role    = "roles/trafficdirector.client"
  member  = "serviceAccount:${google_service_account.gke_node_pool_service_account.email}"
}

resource "google_project_iam_member" "gke_node_pool_service_account_default_node_service_account" {
  project = google_project.deployment-project.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node_pool_service_account.email}"
}

# PROJECT_NUMBER-compute@developer.gserviceaccount.com
# allow cluster autoscaler the same permissions as the default node service account
resource "google_project_iam_member" "gke_node_pool_default_service_account_custom_role_member" {

  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.gke_node_pool_service_account_custom_role.id
  member  = "serviceAccount:${google_project.deployment-project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "gke_node_pool_default_service_account_custom_role_member_traffic_dir" {

  project = google_project.deployment-project.project_id
  role    = "roles/trafficdirector.client"
  member  = "serviceAccount:${google_project.deployment-project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "gke_node_pool_default_service_account_default_node_service_account" {
  project = google_project.deployment-project.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_project.deployment-project.number}-compute@developer.gserviceaccount.com"
}

resource "google_gke_hub_fleet" "default" {
  depends_on   = [google_project_service.all]
  display_name = "${var.environment} gke fleet"
  default_cluster_config {
    security_posture_config {
      mode               = "BASIC"
      vulnerability_mode = "VULNERABILITY_ENTERPRISE"
    }
  }
}
