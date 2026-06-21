resource "google_cloudbuild_trigger" "deploy_cloudrun_services" {

  count = length(var.dependent_cloudrun_services)
  project         = var.project_id
  name            = "deploy-cloudrun-${var.dependent_cloudrun_services[count.index].service_name}-svc"
  description     = "CloudRun service update: ${var.dependent_cloudrun_services[count.index].service_name} Trigger"
  location        = var.region
  service_account = var.cloudbuild_service_account

  build {
    images = []
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run", "deploy", var.dependent_cloudrun_services[count.index].service_name, "--image", var.docker_deployment_image,
        "--region", var.region
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }

  # this is a hack to get this trigger's validation logic to let it be created as
  # manual trigger - https://github.com/hashicorp/terraform-provider-google/issues/16295
  repository_event_config {}
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}

resource "google_cloudbuild_trigger" "deploy_cloudrun_jobs" {

  count = length(var.dependent_cloudrun_jobs)
  project         = var.project_id
  name            = "deploy-cloudrunjob-${var.dependent_cloudrun_jobs[count.index].service_name}-svc"
  description     = "CloudRun job update: ${var.dependent_cloudrun_jobs[count.index].service_name} Trigger"
  location        = var.region
  service_account = var.cloudbuild_service_account

  build {
    images = []
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run",
        "jobs",
        "execute",
        var.dependent_cloudrun_jobs[count.index].service_name,
        "--wait",
        "--region", var.region,
        "--update-env-vars", "ENV=${var.environment},_PROMOTE_COMMIT_SHA=$${_PROMOTE_COMMIT_SHA}"
      ]
      env = [
        "PROMOTE_COMMIT_SHA=$_PROMOTE_COMMIT_SHA",
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }

  # this is a hack to get this trigger's validation logic to let it be created as
  # manual trigger - https://github.com/hashicorp/terraform-provider-google/issues/16295
  repository_event_config {}
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}

resource "google_cloudbuild_trigger" "deploy_gke_services" {

  count = length(var.dependent_gke_services)
  project         = var.project_id
  name            = "deploy-gke-${var.dependent_gke_services[count.index].service_name}-svc"
  description     = "GKE service update: ${var.dependent_gke_services[count.index].service_name} Trigger"
  location        = var.region
  service_account = var.cloudbuild_service_account

  build {
    images = []
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "container",
        "clusters",
        "get-credentials",
        var.dependent_gke_services[count.index].cluster_name,
        "--location",
        var.dependent_gke_services[count.index].cluster_region
      ]
    }
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      env = [
        "CLOUDSDK_COMPUTE_REGION=${var.dependent_gke_services[count.index].cluster_region}",
        "CLOUDSDK_CONTAINER_CLUSTER=${var.dependent_gke_services[count.index].cluster_name}",
        #"CLOUDSDK_GET_CREDENTIALS_OPTS=--internal-ip"
      ]
      entrypoint = "kubectl"
      args = [
        "rollout",
        "restart",
        "deployment",
        var.dependent_gke_services[count.index].service_name,
        "-n",
        var.dependent_gke_services[count.index].namespace
      ]
    }
    # Only add rollout status step for vLLM services
    dynamic "step" {
      for_each = can(regex("^llm-inference", var.dependent_gke_services[count.index].service_name)) ? [1] : []
      content {
        name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
        env = [
          "CLOUDSDK_COMPUTE_REGION=${var.dependent_gke_services[count.index].cluster_region}",
          "CLOUDSDK_CONTAINER_CLUSTER=${var.dependent_gke_services[count.index].cluster_name}",
        ]
        entrypoint = "kubectl"
        args = [
          "rollout",
          "status",
          "deployment",
          var.dependent_gke_services[count.index].service_name,
          "-n",
          var.dependent_gke_services[count.index].namespace
        ]
      }
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }
  # this is a hack to get this trigger's validation logic to let it be created as
  # manual trigger - https://github.com/hashicorp/terraform-provider-google/issues/16295
  repository_event_config {}
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}

resource "google_cloudbuild_trigger" "run_custom_deploy_steps" {

  count = length(var.dependent_custom_deploy_steps)
  project         = var.project_id
  name            = "deploy-custom-${var.dependent_custom_deploy_steps[count.index].service_name}-svc"
  description     = "Service update: ${var.dependent_custom_deploy_steps[count.index].service_name} Trigger"
  location        = var.region
  service_account = var.cloudbuild_service_account

  build {
    images = []
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["pull", var.docker_image_prod]
      env = []
    }
    dynamic "step" {
      for_each = var.dependent_custom_deploy_steps[count.index].steps
      content {
        name       = step.value.name != null ? step.value.name : var.docker_image_prod
        entrypoint = step.value.entrypoint
        args       = step.value.args
        script     = step.value.script
      }
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }
  # this is a hack to get this trigger's validation logic to let it be created as
  # manual trigger - https://github.com/hashicorp/terraform-provider-google/issues/16295
  repository_event_config {}
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}