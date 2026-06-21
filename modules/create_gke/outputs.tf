output "cluster_id" {
  value = google_container_cluster.container-cluster.id
}

output "cluster_project_id" {
  value =google_container_cluster.container-cluster.project
}

output "cluster_region" {
  value = google_container_cluster.container-cluster.location
}

output "cluster_name" {
  value = google_container_cluster.container-cluster.name
}

output "cluster_name_short" {
  value = var.cluster_name_short
}

output "cluster_subnet" {
  value = var.subnet
}
