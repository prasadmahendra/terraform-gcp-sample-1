locals {
  #
  # service tiers:
  # https://cloud.google.com/filestore/docs/service-tiers
  # pricing:
  # https://cloud.google.com/filestore/pricing
  #
  inference_service_config = tolist([for each in var.inference_service_config : each if each.enabled == true])
  text_generation_service_config = tolist([for each in var.text_generation_service_config : each if each.enabled == true])
}

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

module "llm-inference-service-gcs-bucket-pv" {
  source                            = "../../../modules/create_gke_gcs_volume"
  bucket_name                       = var.service_gcs_bucket_name
  environment                       = var.environment
  persistent_volume_capacity        = "5Gi"
  persistent_volume_claim_name      = "${var.service_set_name}-${var.gke_cluster_region}-gcs-pvc"
  persistent_volume_claim_namespace = var.gke_cluster_namespace
  persistent_volume_name            = "${var.service_set_name}-${var.gke_cluster_region}-gcs-pv"
  read_only                         = true
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_service_account" "llm-inference-service-gsa" {
  account_id   = "${var.service_set_name}-gsa-${random_string.suffix.result}"
  display_name = "Managed by Terraform - SA for ${var.service_set_name}"
  project      = var.project_id
}

# Ensure that your IAM service account has the storage roles you need.
module "llm-inference-service-gcs-bucket-perms" {
  source                   = "../../../modules/create_gcs_bucket_perms_for_sa"
  custom_role_id_to_create = "spiffy.llmInferenceSvcRole_${random_string.suffix.result}"
  environment              = var.environment
  project_id               = var.project_id
  service_account_email    = google_service_account.llm-inference-service-gsa.email
  storage_bucket_name      = var.service_gcs_bucket_name

  storage_bucket_permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
    # oddly enough, this is required for the transfer agent to work with this GCS bucket as source!
    "storage.objects.create"
  ]
}

module "llm-inference-service" {

  count = length(local.inference_service_config)
  source            = "../llm-inference"
  service_name      = "${var.service_set_name}-${local.inference_service_config[count.index].service_name_suffix}"
  cluster_namespace = var.gke_cluster_namespace
  docker_image      = local.inference_service_config[count.index].docker_image_override != null ? local.inference_service_config[count.index].docker_image_override : var.docker_image
  docker_image_tag  = local.inference_service_config[count.index].docker_image_tag_override != null ? local.inference_service_config[count.index].docker_image_tag_override : var.docker_image_tag

  environment                    = var.environment
  project_id                     = var.project_id
  project_number                 = var.project_number
  service_directory_namespace_id = var.service_directory_namespace_id
  managed_ssl_certificate_name   = var.managed_ssl_certificate_name
  service_fqdn                   = local.inference_service_config[count.index].service_fqdn
  private_dns_zone_name          = var.private_dns_zone_name
  public_dns_zone_name           = var.public_dns_zone_name
  service_set_name               = var.service_set_name
  subnet                         = var.gke_cluster_subnet.name
  region                         = var.gke_cluster_region

  model_name                           = local.inference_service_config[count.index].model_name
  model_config                         = local.inference_service_config[count.index].model_config
  gpu_accelerator_type                 = local.inference_service_config[count.index].gpu_accelerator_type
  gpu_accelerator_count                = local.inference_service_config[count.index].gpu_accelerator_count
  cpu_alloc_max                        = local.inference_service_config[count.index].cpu_alloc_max
  cpu_alloc_min                        = local.inference_service_config[count.index].cpu_alloc_min
  memory_alloc_max                     = local.inference_service_config[count.index].memory_alloc_max
  memory_alloc_min                     = local.inference_service_config[count.index].memory_alloc_min
  set_shm_to_memory                    = local.inference_service_config[count.index].set_shm_to_memory
  attached_persistent_volume_read_only = false
  container_command_override           = local.inference_service_config[count.index].container_command_override
  container_command_args_override      = local.inference_service_config[count.index].container_command_args_override
  additional_container_command_args    = local.inference_service_config[count.index].additional_container_command_args
  number_of_replicas                   = local.inference_service_config[count.index].number_of_replicas
  number_of_replicas_spot_capacity     = local.inference_service_config[count.index].number_of_replicas_spot_capacity
  spot_capacity_compute_class          = local.inference_service_config[count.index].spot_capacity_compute_class
  service_name_suffix                  = local.inference_service_config[count.index].service_name_suffix
  enable_deep_health_check             = local.inference_service_config[count.index].enable_deep_health_check
  gpu_nodepool                         = local.inference_service_config[count.index].gpu_nodepool
  
  persistent_volume_claim_name_gcs_backed       = module.llm-inference-service-gcs-bucket-pv.persistent_volume_claim_name

  service_account = {
    email      = google_service_account.llm-inference-service-gsa.email
    id         = google_service_account.llm-inference-service-gsa.id
    account_id = google_service_account.llm-inference-service-gsa.account_id
  }
}

module "text-generation-service" {

  count = length(local.text_generation_service_config)
  source            = "../text-generation"
  service_name      = "${var.service_set_name}-${local.text_generation_service_config[count.index].service_name_suffix}"
  cluster_namespace = var.gke_cluster_namespace
  docker_image      = local.text_generation_service_config[count.index].docker_image_override != null ? local.text_generation_service_config[count.index].docker_image_override : var.docker_image
  docker_image_tag  = local.text_generation_service_config[count.index].docker_image_tag_override != null ? local.text_generation_service_config[count.index].docker_image_tag_override : var.docker_image_tag

  environment                    = var.environment
  project_id                     = var.project_id
  project_number                 = var.project_number
  service_directory_namespace_id = var.service_directory_namespace_id
  managed_ssl_certificate_name   = var.managed_ssl_certificate_name
  service_fqdn                   = local.text_generation_service_config[count.index].service_fqdn
  private_dns_zone_name          = var.private_dns_zone_name
  public_dns_zone_name           = var.public_dns_zone_name
  is_public                      = true
  subnet                         = var.gke_cluster_subnet.name
  region                         = var.gke_cluster_region

  model_name                           = local.text_generation_service_config[count.index].model_name
  gpu_accelerator_type                 = local.text_generation_service_config[count.index].gpu_accelerator_type
  gpu_accelerator_count                = local.text_generation_service_config[count.index].gpu_accelerator_count
  cpu_alloc_max                        = local.text_generation_service_config[count.index].cpu_alloc_max
  cpu_alloc_min                        = local.text_generation_service_config[count.index].cpu_alloc_min
  memory_alloc_max                     = local.text_generation_service_config[count.index].memory_alloc_max
  memory_alloc_min                     = local.text_generation_service_config[count.index].memory_alloc_min
  set_shm_to_memory                    = local.text_generation_service_config[count.index].set_shm_to_memory
  number_of_replicas                   = local.text_generation_service_config[count.index].number_of_replicas

  service_account = {
    email      = google_service_account.llm-inference-service-gsa.email
    id         = google_service_account.llm-inference-service-gsa.id
    account_id = google_service_account.llm-inference-service-gsa.account_id
  }
}