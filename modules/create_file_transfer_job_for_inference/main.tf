data "google_storage_transfer_project_service_account" "storage_transfer_project_service_account" {
  project = var.project_id
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

module "llm-inference-service-gcs-bucket-perms-for-transfer-agent" {
  source                   = "../../modules/create_gcs_bucket_perms_for_sa"
  custom_role_id_to_create = "spiffy.llmInferenceSvcStorageTransferAgentGcsAccessRole_${random_string.suffix.result}"
  environment              = var.environment
  project_id               = var.project_id
  service_account_email    = data.google_storage_transfer_project_service_account.storage_transfer_project_service_account.email
  storage_bucket_name      = var.service_gcs_bucket_name

  storage_bucket_permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create"
  ]
}

# create a transfer agent pool to move model, lora weights and config data from GCS to Filestore
module "llm-inference-service-gcs-filestore-transfer-agent-pool" {
  source                                  = "../../../modules/create_storage_transfer_agent_pool"
  agent_pool_name                         = "${var.service_set_name}-model-transfer-agent-pool-${var.gke_cluster_name}"
  agent_pool_description                  = "${var.service_set_name} - ${var.service_gcs_bucket_name} to ${var.filestore_instance_name} transfer agent pool"
  agent_pool_service_account_id_to_create = "${var.service_set_name}-transfer-agentpool-sa-${var.gke_cluster_name}}"
  bandwidth_limit_mbps                    = 1000
  environment                             = var.environment
  project_name                            = var.project_id
}

# Run a transfer agent to routinely sync model data from GCS to Filestore
module "llm-inference-service-gcs-filestore-transfer-agent" {

  source                                 = "../../../modules/create_storage_transfer_agent"
  service_name                           = "${var.service_set_name}-mta-${var.region_codes[var.gke_cluster_region]}"
  agent_pool_name                        = module.llm-inference-service-gcs-filestore-transfer-agent-pool.storage_transfer_agent_pool_name
  environment                            = var.environment
  cluster_name                           = var.gke_cluster_name
  cluster_namespace                      = var.gke_cluster_namespace
  persistent_volume_claim_name           = var.persistent_volume_claim_name
  persistent_volume_mount_path           = "/mnt/filestore"
  persistent_volume_mount_path_read_only = false
  project_id                             = var.project_id
  project_number                         = var.project_number
  region                                 = var.gke_cluster_region
  service_account                        = var.service_account
  number_of_replicas                     = var.environment == "prod" ? 3 : 1
}

resource "google_storage_transfer_job" "gcs-to-filestore-transfer-job" {
  description = "${var.service_set_name} (${var.gke_cluster_name}): gcs -> nfs transfer job"
  project     = var.project_id

  transfer_spec {
    transfer_options {
      delete_objects_unique_in_sink              = true
      overwrite_objects_already_existing_in_sink = false
      overwrite_when                             = "DIFFERENT"
    }
    gcs_data_source {
      bucket_name = var.service_gcs_bucket_name
    }
    posix_data_sink {
      root_directory = "/mnt/filestore"
    }
    #source_agent_pool_name = module.llm-inference-service-gcs-filestore-transfer-agent-pool.storage_transfer_agent_pool_id
    sink_agent_pool_name = module.llm-inference-service-gcs-filestore-transfer-agent-pool.storage_transfer_agent_pool_id
  }

  schedule {
    schedule_start_date {
      year  = 2018
      month = 10
      day   = 1
    }
    schedule_end_date {
      year  = 2025
      month = 1
      day   = 15
    }
    start_time_of_day {
      hours   = 23
      minutes = 30
      seconds = 0
      nanos   = 0
    }
    repeat_interval = "3600s"
  }
}