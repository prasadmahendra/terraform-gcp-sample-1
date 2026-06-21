# https://spacelift.io/blog/restart-kubernetes-pods-with-kubectl
module "cloud_deploy" {
  source  = "GoogleCloudPlatform/cloud-deploy/google"
  version = "~> 0.2"

  pipeline_name = var.pipeline_name
  location      = var.region
  project       = var.project_id
  stage_targets = [
    {
      target_name   = var.stage_targets.target_name
      profiles      = var.stage_targets.profiles
      target_create = var.stage_targets.target_create
      target_type   = var.stage_targets.target_type
      target_spec   = {
        project_id       = var.stage_targets.target_spec.project_id
        location         = var.stage_targets.target_spec.region
        gke_cluster_name = var.stage_targets.target_spec.gke_cluster_name
        gke_cluster_sa   = var.trigger_sa_name
      }
      require_approval   = var.stage_targets.require_approval
      # Optional. Google service account to use for execution. If unspecified, the project execution service account (-compute@developer.gserviceaccount.com) is used.
      exe_config_sa_name = var.trigger_sa_name
      execution_config   = {
        execution_timeout = "3600s"
        # Optional. The resource name of the WorkerPool, with the format projects/{project}/locations/{location}/workerPools/{worker_pool}.
        # If this optional field is unspecified, the default Cloud Build pool will be used.
        worker_pool       = var.stage_targets.execution_config.worker_pool
        # Optional. Cloud Storage location in which to store execution outputs.
        # This can either be a bucket ("gs://my-bucket") or a path within a bucket ("gs://my-bucket/my-dir").
        # If unspecified, a default bucket located in the same region will be used.
        artifact_storage  = "${var.execution_output_artifact_storage_bucket}/deployments/execution_outputs"
      }
      strategy = {
        standard = {
          verify = true
        }
      }
    }
  ]
  trigger_sa_name   = var.trigger_sa_name
  trigger_sa_create = var.trigger_sa_create
}