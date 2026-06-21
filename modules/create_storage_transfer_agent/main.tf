terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

module "storage-transfer-agent-gke-service" {
  source               = "../create_gke_http_service"
  kubernetes_namespace = var.cluster_namespace
  service_name         = var.service_name
  container_dns_label  = var.service_name
  container_port       = 9000
  docker_image         = "gcr.io/cloud-ingest/tsop-agent"
  docker_image_tag     = "no-new-use-public-image-da2c87a122c34def68ca56ae336ee61dccf1163393f6cdc61902b6835430864c"
  environment          = var.environment
  service_port         = 9000
  number_of_replicas   = var.number_of_replicas

  google_service_account_for_the_service = var.service_account

  persistent_volumes = [
    {
      name                         = "gcs-fuse-csi-filestore-static"
      mount_path                   = var.persistent_volume_mount_path
      read_only                    = var.persistent_volume_mount_path_read_only
      persistent_volume_claim_name = var.persistent_volume_claim_name
    }
  ]
  project_id     = var.project_id
  project_number = var.project_number

  # /usr/bin/python3 python3 ./autoupdate.py --agent-pool=llm-inference-service-model-transfer-agent-pool --creds-file=/tmp/tmp.creds.json --hostname=PRASAD-MAHENDRA.local --log-dir=/tmp --project-id=spiffy-ai-dev --agent-id-prefix=test
  container_command      = ["python3"]
  container_command_args = [
    "./autoupdate.py",
    "--agent-pool=${var.agent_pool_name}",
    "--hostname=$$HOSTNAME",
    "--project-id=${var.project_id}",
    "--agent-id-prefix=${var.environment}"
  ]

  # Each Storage Transfer Service agent needs 4 vCPU and 8 GB RAM. For best performance, run multiple agents per VM.
  # For the purposes of this guide, provision an e2-standard-32 Compute Engine virtual machine instance.
  limits_cpus                       = 4
  limits_memory                     = "8Gi"
  limits_nvidia_gpus                = null
  requests_cpus                     = 4
  requests_memory                   = "8Gi"
  requests_nvidia_gpus              = null
  gpu_accelerator_type              = null
  is_public                         = false
  managed_ssl_certificate_name      = null
  enable_service_directory_registry = false
  liveness_probe                    = null
  readiness_probe                   = null
  apm_enabled                       = false
}

# Based on - https://cloud.google.com/storage-transfer/docs/access-control
resource "google_project_iam_member" "project_iam_member_transfer_agent_role_member" {
  project = var.project_id
  role    = "roles/storagetransfer.transferAgent"
  member  = "serviceAccount:${var.service_account.email}"
}

# Based on - https://cloud.google.com/storage-transfer/docs/access-control
resource "google_project_iam_member" "project_iam_member_service_agent_role_member" {
  project = var.project_id
  role    = "roles/storagetransfer.serviceAgent"
  member  = "serviceAccount:${var.service_account.email}"
}
