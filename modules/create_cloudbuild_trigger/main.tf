resource "random_string" "random_branch_suffix" {
  length  = 4
  special = false
}

locals {

  repo_url                                          = "us-docker.pkg.dev"
  prod_project_id                                   = var.prod_project_id
  org_name                                          = var.org_name
  github_org_name                                   = var.github_org_name
  github_repo_name                                  = var.github_repo_name
  mono_repo_entrypoint_name                         = "${var.github_repo_name}-base" # ex: pymono-base
  mono_repo_entrypoint_name_partial                 = var.is_mono_repo ? "-${var.mono_repo_entrypoint_id}" : ""
  repo_branch_name_suffix                           = var.main_branch_name == "main" ? local.mono_repo_entrypoint_name_partial : "${local.mono_repo_entrypoint_name_partial}-branch-${replace(var.main_branch_name, "/", "-")}"
  cloudbuild_trigger_name_partial                   = "${var.github_repo_name}${local.mono_repo_entrypoint_name_partial}${local.repo_branch_name_suffix}"
  docker_image                                      = "${local.repo_url}/${local.prod_project_id}/${local.org_name}/${local.github_repo_name}"
  docker_image_latest_tag_name                      = "latest${local.repo_branch_name_suffix}"
  docker_image_prod_tag_name                        = "prod${local.repo_branch_name_suffix}"
  docker_image_latest                               = "${local.docker_image}:${local.docker_image_latest_tag_name}"
  docker_image_prod                                 = "${local.docker_image}:${local.docker_image_prod_tag_name}"
  docker_image_commit_sha                           = "${local.docker_image}:$${COMMIT_SHA}${local.mono_repo_entrypoint_name_partial}"
  docker_deployment_image                           = var.environment == "prod" ? local.docker_image_prod : local.docker_image_latest
  additional_packaging_steps_on_pull_requests       = [
    for packaging_step in var.additional_packaging_steps : packaging_step
    if packaging_step.on_pull_requests_only == true
  ]
  additional_packaging_steps_on_merge_to_main       = [
    for packaging_step in var.additional_packaging_steps : packaging_step
    if packaging_step.on_pull_requests_only == false
  ]
  dependent_cloudrun_services                       = [
    for gke_service in var.post_build_deployment_steps : gke_service
    if gke_service.step_type == "gcs_service_deploy" && gke_service.service_type == "cloudrun" && gke_service.enabled == true
  ]
  dependent_cloudrun_jobs                           = [
    for gke_service in var.post_build_deployment_steps : gke_service
    if gke_service.step_type == "gcs_service_deploy" && gke_service.service_type == "cloudrun_job" && gke_service.enabled == true
  ]
  dependent_gke_services                            = [
    for gke_service in var.post_build_deployment_steps : gke_service
    if gke_service.step_type == "gcs_service_deploy" && gke_service.service_type == "gke" && gke_service.enabled == true
  ]
  dependent_custom_deploy_steps                     = [
    for gke_service in var.post_build_deployment_steps : gke_service
    if gke_service.step_type == "custom_deploy_step" && gke_service.enabled == true
  ]
  additional_build_args_on_docker_build_reformatted = join(" ", concat(var.additional_build_args_on_docker_build, [
    "--build-arg ENV=${var.environment}",
    "--build-arg BRANCH_NAME=$BRANCH_NAME",
    "--build-arg COMMIT_SHA=$COMMIT_SHA",
    "--build-arg DD_GIT_COMMIT_SHA=$COMMIT_SHA", # for DD APM to link to source code
  ]))
  docker_base_image_install_pkgs_file               = var.docker_base_image_install_pkgs_file != null ? var.docker_base_image_install_pkgs_file : "docker/conda-environment.yml"
  docker_conditional_build_script_run_cmd           = var.docker_conditional_build_script_run_cmd != null ? var.docker_conditional_build_script_run_cmd : "sh docker/scripts/docker-build-conditional.sh"
  default_environment_vars_on_steps                 = [
    "ENV=${var.environment}",
    "COMMIT_SHA=$COMMIT_SHA",
    "SHORT_SHA=$SHORT_SHA",
    "BRANCH_NAME=$BRANCH_NAME",
    "BUILD_ID=$BUILD_ID",
    "PROJECT_ID=$PROJECT_ID",
    "PROJECT_NUMBER=$PROJECT_NUMBER",
    "LOCATION=$LOCATION",
  ]
}

resource "google_cloudbuildv2_repository" "cloud-build-linked-repo" {

  count             = var.environment == "dev" && var.create_linked_github_repository == true ? 1 : 0
  project           = var.project_id
  location          = var.region
  name              = "${var.github_org_name}/${var.github_repo_name}"
  parent_connection = var.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/${var.github_repo_name}.git"
}

data "google_secret_manager_secret_version" "sonarcloud-token-for-sonarqube" {

  count   = var.environment == "dev" ? 1 : 0
  secret  = "sonarcloud-token-for-sonarqube"
  project = var.project_id
}

resource "google_cloudbuild_trigger" "app_build_trigger_every_pr_to_main" {

  count              = var.environment == "dev" ? 1 : 0
  project            = var.project_id
  name               = "bld-${local.cloudbuild_trigger_name_partial}-pr"
  description        = "Build PR trigger - ${var.github_org_name}/${local.cloudbuild_trigger_name_partial}"
  location           = var.region
  service_account    = var.cloudbuild_service_account
  # You are able to view your build logs in GitHub and GitHub Enterprise with
  # INCLUDE_BUILD_LOGS_WITH_STATUS
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"

  build {
    images = [local.docker_image_commit_sha]
    dynamic "step" {
      for_each = length(var.pre_build_steps) > 0 ? ["ssh"] : []
      content {
        name       = "gcr.io/cloud-builders/git"
        secret_env = ["GITHUB_DEPLOY_KEY", "GITHUB_KNOWN_HOSTS"]
        script     = <<EOT
          echo "$GITHUB_DEPLOY_KEY" >> /root/.ssh/id_rsa
          chmod 400 /root/.ssh/id_rsa
          echo "$GITHUB_KNOWN_HOSTS" >> /root/.ssh/known_hosts
      EOT
        volumes {
          name = step.value
          path = "/root/.ssh"
        }
      }
    }
    dynamic "step" {
      for_each = var.pre_build_steps
      content {
        name       = step.value.name
        entrypoint = step.value.entrypoint
        args       = step.value.args
        volumes {
          name = "ssh"
          path = "/root/.ssh"
        }
      }
    }
    step {
      name   = "gcr.io/cloud-builders/gcloud"
      script = "gcloud auth print-access-token > _CLOUDSDK_AUTH_ACCESS_TOKEN && echo $(date +%Y%m.%d%H%M.%S)dev$(date +%S) > _VERSION"
      # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
      env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
    }

    ## INCREMENTAL BUILD
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : []
      content {
        name   = "gcr.io/cloud-builders/gcloud"
        script = "git log -1 --format=format:%H -- ${var.dockerfile_file_name} > _DOCKERFILE_COMMIT_SHA"
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : []
      content {
        name   = "gcr.io/cloud-builders/docker"
        # Script takes as args <ENV> <VERSION> <COMMIT_SHA> <CLOUDSDK_AUTH_ACCESS_TOKEN> <PACKAGE.JSON OR CONDA_ENVIRONMENT_YML_FILEPATH> <DOCKERFILE_PATH> <BASE_IMAGE_NAME>
        script = "${local.docker_conditional_build_script_run_cmd} ${var.environment} $(cat _VERSION) $COMMIT_SHA $(cat _CLOUDSDK_AUTH_ACCESS_TOKEN) ${local.docker_base_image_install_pkgs_file} ${var.dockerfile_file_name_base_image} ${local.mono_repo_entrypoint_name}${local.mono_repo_entrypoint_name_partial} $(cat _DOCKERFILE_COMMIT_SHA)"
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : [0]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "set -eufx; docker build --progress=plain -t ${local.docker_image_commit_sha} --network host --build-arg VERSION=\"$(cat _VERSION)\" --build-arg CLOUDSDK_AUTH_ACCESS_TOKEN=\"$(cat _CLOUDSDK_AUTH_ACCESS_TOKEN)\" --build-arg INCREMENTAL_BUILD_BASE_IMAGE_NAME=${local.mono_repo_entrypoint_name}${local.mono_repo_entrypoint_name_partial} --build-arg INCREMENTAL_BUILD_BASE_IMAGE_TAG=\"$(cat _DOCKER_BASE_IMAGE_COND_BUILD_OUTPUT)\" ${local.additional_build_args_on_docker_build_reformatted} --cache-from ${local.docker_image_latest} -f ${var.dockerfile_file_name} ."
        # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    ## INCREMENTAL BUILD END
    ## ELSE REGULAR BUILD
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [] : [1]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "docker pull ${local.docker_image_latest} || exit 0"
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [] : [1]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "docker build --progress=plain -t ${local.docker_image_commit_sha} --network host --build-arg VERSION=\"$(cat _VERSION)\" --build-arg CLOUDSDK_AUTH_ACCESS_TOKEN=\"$(cat _CLOUDSDK_AUTH_ACCESS_TOKEN)\" ${local.additional_build_args_on_docker_build_reformatted} --cache-from ${local.docker_image_latest} -f ${var.dockerfile_file_name} ."
        # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    ## ELSE REGULAR BUILD END

    dynamic "step" {
      for_each = var.build_test_steps
      content {
        name       = step.value.image != null ? step.value.image : local.docker_image_commit_sha
        entrypoint = step.value.entrypoint
        args       = step.value.args
        env        = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    # static analysis
    step {
      id   = "sonar-scanner"
      wait_for = ["-"]
      name = "gcr.io/spiffy-prod/sonar-scanner:latest"
      args = [
        "-Dsonar.host.url=https://sonarcloud.io",
        "-Dsonar.login=${data.google_secret_manager_secret_version.sonarcloud-token-for-sonarqube[0].secret_data}",
        "-Dsonar.projectKey=spiffy-ai",
        "-Dsonar.organization=spiffy-ai",
        "-Dsonar.sources=."
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.docker_image_commit_sha]
    }
    # step {
    #   # prasad
    #   name   = "gcr.io/cloud-builders/docker"
    #   script = "BRANCH_NAME_CLEAN=$(echo $BRANCH_NAME | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g') && docker tag ${local.docker_image_commit_sha} ${local.docker_image}:$BRANCH_NAME_CLEAN && docker push ${local.docker_image}:$BRANCH_NAME_CLEAN"
    #   env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
    # }
    step {
      name   = "gcr.io/cloud-builders/docker"
      script = "VERSION=\"${local.docker_image}:br-$(cat _VERSION)${local.repo_branch_name_suffix}\" && echo $VERSION && docker tag ${local.docker_image_commit_sha} $VERSION && docker push $VERSION"
      env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
    }
    dynamic "step" {
      for_each = local.additional_packaging_steps_on_pull_requests
      content {
        name       = local.docker_image_commit_sha
        entrypoint = step.value.entrypoint
        args       = step.value.args
        script     = step.value.script
        env        = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    dynamic "available_secrets" {
      for_each = length(var.pre_build_steps) > 0 ? ["ssh"] : []
      content {
        dynamic "secret_manager" {
          for_each = var.github_deploy_key_secret_manager_version_name != null ? [
            var.github_deploy_key_secret_manager_version_name
          ] : []
          content {
            version_name = secret_manager.value
            env          = "GITHUB_DEPLOY_KEY"
          }
        }
        secret_manager {
          env          = "GITHUB_KNOWN_HOSTS"
          version_name = var.github_known_hosts_secret_manager_version_name
        }
      }
    }
    options {
      logging      = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }

  repository_event_config {
    repository = var.environment == "dev" && var.create_linked_github_repository == true ? google_cloudbuildv2_repository.cloud-build-linked-repo[0].id : var.linked_github_repository_id
    pull_request {
      branch = var.main_branch_name
    }
  }
}

resource "google_cloudbuild_trigger" "app_build_trigger_every_merge_to_main" {

  count              = var.environment == "dev" ? 1 : 0
  project            = var.project_id
  name               = "bld-${local.cloudbuild_trigger_name_partial}"
  description        = "Build main branch trigger - ${var.github_org_name}/${local.cloudbuild_trigger_name_partial}"
  location           = var.region
  service_account    = var.cloudbuild_service_account
  # You are able to view your build logs in GitHub and GitHub Enterprise with
  # INCLUDE_BUILD_LOGS_WITH_STATUS
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"

  build {
    images = [local.docker_image_commit_sha]
    dynamic "step" {
      for_each = length(var.pre_build_steps) > 0 ? ["ssh"] : []
      content {
        name       = "gcr.io/cloud-builders/git"
        secret_env = ["GITHUB_DEPLOY_KEY", "GITHUB_KNOWN_HOSTS"]
        script     = <<EOT
          echo "$GITHUB_DEPLOY_KEY" >> /root/.ssh/id_rsa
          chmod 400 /root/.ssh/id_rsa
          echo "$GITHUB_KNOWN_HOSTS" >> /root/.ssh/known_hosts
      EOT
        volumes {
          name = step.value
          path = "/root/.ssh"
        }
      }
    }
    dynamic "step" {
      for_each = var.pre_build_steps
      content {
        name       = step.value.name
        entrypoint = step.value.entrypoint
        args       = step.value.args
        volumes {
          name = "ssh"
          path = "/root/.ssh"
        }
      }
    }
    step {
      name   = "gcr.io/cloud-builders/gcloud"
      script = "gcloud auth print-access-token > _CLOUDSDK_AUTH_ACCESS_TOKEN && echo $(date +%Y%m.%d%H%M.%S) > _VERSION"
      # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
      env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
    }

    ## INCREMENTAL BUILD
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : []
      content {
        name   = "gcr.io/cloud-builders/gcloud"
        script = "git log -1 --format=format:%H -- ${var.dockerfile_file_name} > _DOCKERFILE_COMMIT_SHA"
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : []
      content {
        name   = "gcr.io/cloud-builders/docker"
        # Script takes as args <ENV> <VERSION> <COMMIT_SHA> <CLOUDSDK_AUTH_ACCESS_TOKEN> <PACKAGE.JSON OR CONDA_ENVIRONMENT_YML_FILEPATH> <DOCKERFILE_PATH> <BASE_IMAGE_NAME>
        script = "${local.docker_conditional_build_script_run_cmd} ${var.environment} $(cat _VERSION) $COMMIT_SHA $(cat _CLOUDSDK_AUTH_ACCESS_TOKEN) ${local.docker_base_image_install_pkgs_file} ${var.dockerfile_file_name_base_image} ${local.mono_repo_entrypoint_name}${local.mono_repo_entrypoint_name_partial} $(cat _DOCKERFILE_COMMIT_SHA)"
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [1] : [0]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "set -eufx; docker build --progress=plain -t ${local.docker_image_commit_sha} --network host --build-arg VERSION=\"$(cat _VERSION)\" --build-arg CLOUDSDK_AUTH_ACCESS_TOKEN=\"$(cat _CLOUDSDK_AUTH_ACCESS_TOKEN)\" --build-arg INCREMENTAL_BUILD_BASE_IMAGE_NAME=${local.mono_repo_entrypoint_name}${local.mono_repo_entrypoint_name_partial} --build-arg INCREMENTAL_BUILD_BASE_IMAGE_TAG=\"$(cat _DOCKER_BASE_IMAGE_COND_BUILD_OUTPUT)\" ${local.additional_build_args_on_docker_build_reformatted} --cache-from ${local.docker_image_latest} -f ${var.dockerfile_file_name} ."
        # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    ## INCREMENTAL BUILD END
    ## ELSE REGULAR BUILD
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [] : [1]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "docker pull ${local.docker_image_latest} || exit 0"
      }
    }
    dynamic "step" {
      for_each = var.incremental_docker_builder_available ? [] : [1]
      content {
        name   = "gcr.io/cloud-builders/docker"
        script = "docker build --progress=plain -t ${local.docker_image_commit_sha} --network host --build-arg VERSION=\"$(cat _VERSION)\" --build-arg CLOUDSDK_AUTH_ACCESS_TOKEN=\"$(cat _CLOUDSDK_AUTH_ACCESS_TOKEN)\" ${local.additional_build_args_on_docker_build_reformatted} --cache-from ${local.docker_image_latest} -f ${var.dockerfile_file_name} ."
        # https://cloud.google.com/build/docs/configuring-builds/substitute-variable-values
        env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    ## ELSE REGULAR BUILD END

    dynamic "step" {
      for_each = var.build_test_steps
      content {
        name       = step.value.image != null ? step.value.image : local.docker_image_commit_sha
        entrypoint = step.value.entrypoint
        args       = step.value.args
        env        = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    # static analysis
    dynamic "step" {
      for_each = var.disable_sonar_checks ? [] : [1]
      content {
        name = "gcr.io/spiffy-prod/sonar-scanner:latest"
        args = [
          "-Dsonar.host.url=https://sonarcloud.io",
          "-Dsonar.login=${data.google_secret_manager_secret_version.sonarcloud-token-for-sonarqube[0].secret_data}",
          "-Dsonar.projectKey=spiffy-ai",
          "-Dsonar.organization=spiffy-ai",
          "-Dsonar.sources=.",
          "-Dsonar.cfamily.build-wrapper-output=bw-output"
        ]
      }
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["tag", local.docker_image_commit_sha, local.docker_image_latest]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.docker_image_commit_sha]
    }
    step {
      name   = "gcr.io/cloud-builders/docker"
      script = "VERSION=\"${local.docker_image}:latest-$(cat _VERSION)${local.repo_branch_name_suffix}\" && echo $VERSION && docker tag ${local.docker_image_commit_sha} $VERSION && docker push $VERSION"
      env    = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.docker_image_latest]
    }
    dynamic "step" {
      for_each = local.additional_packaging_steps_on_merge_to_main
      content {
        name       = local.docker_image_commit_sha
        entrypoint = step.value.entrypoint
        args       = step.value.args
        script     = step.value.script
        env        = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    # dependent_cloudrun_services
    dynamic "step" {
      for_each = local.dependent_cloudrun_services
      content {
        name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
        entrypoint = "gcloud"
        args       = [
          "run",
          "deploy",
          step.value.service_name,
          "--image", local.docker_image_latest,
          "--region", var.region
        ]
      }
    }
    # dependent_cloudrun_jobs
    dynamic "step" {
      for_each = local.dependent_cloudrun_jobs
      content {
        name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
        entrypoint = "gcloud"
        args       = [
          "run",
          "jobs",
          "execute",
          step.value.service_name,
          "--wait",
          "--region", var.region,
          "--update-env-vars", "ENV=${var.environment}"
        ]
        env = concat(local.default_environment_vars_on_steps, var.additional_environment_vars_on_steps)
      }
    }
    # dependent_gke_services
    dynamic "step" {
      for_each = local.dependent_gke_services
      content {
        name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
        entrypoint = "gcloud"
        args       = [
          "container",
          "clusters",
          "get-credentials",
          step.value.cluster_name,
          "--location",
          step.value.cluster_region
        ]
      }
    }
    dynamic "step" {
      for_each = local.dependent_gke_services
      content {
        name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
        env  = [
          "CLOUDSDK_COMPUTE_REGION=${local.dependent_gke_services[count.index].cluster_region}",
          "CLOUDSDK_CONTAINER_CLUSTER=${local.dependent_gke_services[count.index].cluster_name}",
          #"CLOUDSDK_GET_CREDENTIALS_OPTS=--internal-ip"
        ]
        entrypoint = "kubectl"
        args       = [
          "rollout",
          "restart",
          "deployment",
          step.value.service_name,
          "-n",
          step.value.namespace
        ]
      }
    }
    dynamic "available_secrets" {
      for_each = length(var.pre_build_steps) > 0 ? ["ssh"] : []
      content {
        dynamic "secret_manager" {
          for_each = var.github_deploy_key_secret_manager_version_name != null ? [
            var.github_deploy_key_secret_manager_version_name
          ] : []
          content {
            version_name = secret_manager.value
            env          = "GITHUB_DEPLOY_KEY"
          }
        }
        secret_manager {
          env          = "GITHUB_KNOWN_HOSTS"
          version_name = var.github_known_hosts_secret_manager_version_name
        }
      }
    }
    options {
      logging      = "CLOUD_LOGGING_ONLY"
      # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
      machine_type = var.worker_pool_name == null ? var.build_machine_type : null
      worker_pool  = var.worker_pool_name
    }
    timeout = var.build_timeout
  }

  repository_event_config {
    repository = var.environment == "dev" && var.create_linked_github_repository == true ? google_cloudbuildv2_repository.cloud-build-linked-repo[0].id : var.linked_github_repository_id
    push {
      branch = var.main_branch_name
    }
  }
}

module "promote-dev-tags-to-prod-triggers" {

  count                           = var.environment == "prod" ? 1 : 0
  source                          = "../create_cloudbuild_promote_tags_trigger"
  cloudbuild_service_account      = var.cloudbuild_service_account_for_promotions
  cloudbuild_trigger_name_partial = local.cloudbuild_trigger_name_partial
  docker_image_base               = local.docker_image
  docker_image_tag_from           = local.docker_image_latest
  docker_image_tag_to             = local.docker_image_prod
  environment                     = var.environment
  github_org_name                 = var.github_org_name
  github_repo_name                = var.github_repo_name
  project_id                      = var.project_id
  region                          = var.region
  repository_connection_name      = var.repository_connection_name
  worker_pool_name                = var.worker_pool_name
  post_pull_rebuild_config        = var.post_pull_rebuild_config
}

module "deploy-services-triggers" {

  source                        = "../create_cloudbuild_promote_services_trigger"
  cloudbuild_service_account    = var.environment == "dev" ? var.cloudbuild_service_account : var.cloudbuild_service_account_for_promotions
  environment                   = var.environment
  github_org_name               = var.github_org_name
  github_repo_name              = var.github_repo_name
  project_id                    = var.project_id
  region                        = var.region
  repository_connection_name    = var.repository_connection_name
  worker_pool_name              = var.worker_pool_name
  dependent_cloudrun_services   = local.dependent_cloudrun_services
  dependent_cloudrun_jobs       = local.dependent_cloudrun_jobs
  dependent_gke_services        = local.dependent_gke_services
  dependent_custom_deploy_steps = local.dependent_custom_deploy_steps
  docker_deployment_image       = local.docker_deployment_image
  docker_image_prod             = local.docker_image_prod
}