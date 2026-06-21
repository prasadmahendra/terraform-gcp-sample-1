locals {
  rebuild_arg_names = var.post_pull_rebuild_config != null ? [
    for arg in var.post_pull_rebuild_config.build_args :
    element(split("=", trimprefix(arg, "--build-arg ")), 0)
  ] : []
  rebuild_build_args_str = var.post_pull_rebuild_config != null ? join(" ", [
    for arg in var.post_pull_rebuild_config.build_args :
    replace(arg, "--build-arg ", "--build-arg _REBUILD_")
  ]) : ""
  rebuild_script = var.post_pull_rebuild_config != null ? var.post_pull_rebuild_config.rebuild_script : ""
  rebuild_arg_echo_cmds = join("\n", [
    for name in local.rebuild_arg_names :
    "echo 'ARG _REBUILD_${name}' >> /workspace/Dockerfile.rebuild\necho 'ENV ${name}=$_REBUILD_${name}' >> /workspace/Dockerfile.rebuild"
  ])
}

resource "google_cloudbuild_trigger" "google_cloudbuild_trigger_promote_docker_images" {

  count           = var.environment == "prod" ? 1 : 0
  project         = var.project_id
  name            = "promote-${var.cloudbuild_trigger_name_partial}-to-prod"
  description     = "Promote latest dev image to prod for ${var.cloudbuild_trigger_name_partial}"
  location        = var.region
  service_account = var.cloudbuild_service_account

  build {
    images = []
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["pull", "${var.docker_image_base}:$_PROMOTE_COMMIT_SHA${var.commit_sha_suffix}"]
      env    = [
        "PROMOTE_COMMIT_SHA=$_PROMOTE_COMMIT_SHA${var.commit_sha_suffix}",
      ]
    }
    # When rebuild is configured: build a new image FROM the pulled one with prod build args
    dynamic "step" {
      for_each = var.post_pull_rebuild_config != null ? [1] : []
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = <<-EOT
          set -e
          echo "FROM ${var.docker_image_base}:$PROMOTE_COMMIT_SHA" > /workspace/Dockerfile.rebuild
          ${local.rebuild_arg_echo_cmds}
          echo 'RUN ${local.rebuild_script}' >> /workspace/Dockerfile.rebuild
          cat /workspace/Dockerfile.rebuild
          docker build --progress=plain -f /workspace/Dockerfile.rebuild ${local.rebuild_build_args_str} -t ${var.docker_image_tag_to} /workspace
        EOT
        env = ["PROMOTE_COMMIT_SHA=$_PROMOTE_COMMIT_SHA${var.commit_sha_suffix}"]
      }
    }
    # When no rebuild: simple re-tag
    dynamic "step" {
      for_each = var.post_pull_rebuild_config == null ? [1] : []
      content {
        name = "gcr.io/cloud-builders/docker"
        args = ["tag", "${var.docker_image_base}:$_PROMOTE_COMMIT_SHA${var.commit_sha_suffix}", var.docker_image_tag_to]
        env  = ["PROMOTE_COMMIT_SHA=$_PROMOTE_COMMIT_SHA${var.commit_sha_suffix}"]
      }
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", var.docker_image_tag_to]
    }
    options {
      logging      = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }
  # this is a hack to get this trigger's validation logic to let it be created as
  # manual trigger - https://github.com/hashicorp/terraform-provider-google/issues/16295
  repository_event_config {}

  # If this is set on a build, it will become pending when it is run,
  # and will need to be explicitly approved to start.
  # approval_config {
  #  approval_required = true
  # }
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}
