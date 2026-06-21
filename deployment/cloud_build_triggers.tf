locals {
  worker_pool_name           = var.enable_private_build_worker_pool ? google_cloudbuild_worker_pool.cloudbuild_worker_pool_e2[0].id : null
  repository_connection_name = module.github[0].github-connection_name
  # we use the connection to git hub to link the repositories and produce docker image names (for prod as well)
  cloudbuild_trigger_sa                = var.environment == "dev" || var.environment == "prod" ? google_service_account.cloudbuild_service_account[0].id : null
  cloudbuild_trigger_sa_for_promotions = var.environment == "prod" ? google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].id : null
  shopfiy_webhooks_ingest_enabled      = true # Required to listen for GDPR delete requests
  segment_webhooks_ingest_enabled      = false
  rudderstack_webhooks_ingest_enabled  = false
  simondata_webhooks_ingest_enabled    = false
}

data "google_secret_manager_secret_version" "codecov_token" {
  count   = var.environment == "dev" ? 1 : 0
  secret  = "codecov_token"
  project = google_project.deployment-project.project_id
}

data "google_secret_manager_secret_version" "spiffy_react_components_chromatic_project_token" {
  secret  = "spiffy_react_components_chromatic_project_token"
  project = var.project_id
}

######################################## repo: pymono ########################################

resource "google_cloudbuildv2_repository" "pymono-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "${var.github_org_name}/pymono"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/pymono.git"
}

module "git-repo-pymono-for-shared-libs" {

  count = 0 # no use case for shared-libs atm! so disable it.
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.pymono-repo
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "pymono"
  create_linked_github_repository           = false
  is_mono_repo                              = true
  mono_repo_entrypoint_id                   = "shared-libs"
  linked_github_repository_id               = google_cloudbuildv2_repository.pymono-repo[0].id
  environment                               = var.environment
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  incremental_docker_builder_available      = true
  dockerfile_file_name_base_image           = "docker/pymono/base/Dockerfile"
  dockerfile_file_name                      = "docker/pymono/incremental/Dockerfile"
  docker_base_image_install_pkgs_file       = "conda/environment.yml"
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps = var.environment == "dev" ? [
    {
      image      = null
      entrypoint = "coverage"
      args       = ["run", "--data-file=coverage-report", "-m", "pytest", "spiffy/lib", "-v", "-s"]
    },
    {
      image      = null
      entrypoint = "coverage"
      args       = ["xml", "-i", "--data-file=coverage-report", "-o", "coverage-report.xml"]
    },
    {
      image      = "us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest"
      entrypoint = "codecov"
      args = [
        "--verbose", "upload-process", "--fail-on-error", "-t", # add --fail-on-error back when codecov is fixed
        data.google_secret_manager_secret_version.codecov_token[0].secret_data,
        "-n",
        "pymono-flyte-wf-build-$${COMMIT_SHA}", "-F", "pymono-shared-libs", "-f", "coverage-report.xml"
      ]
    }
  ] : []
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_machine_type                             = "E2_HIGHCPU_32"
}

module "git-repo-pymono-for-flyte-workflows" {

  count = var.union_ai_cloud_enabled ? 1 : 0
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.pymono-repo
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "pymono"
  create_linked_github_repository           = false
  is_mono_repo                              = true
  disable_sonar_checks                      = true
  mono_repo_entrypoint_id                   = "flyte-wf"
  linked_github_repository_id               = google_cloudbuildv2_repository.pymono-repo[0].id
  incremental_docker_builder_available      = true
  dockerfile_file_name_base_image           = "spiffy/service/workflows/docker/base/Dockerfile"
  dockerfile_file_name                      = "spiffy/service/workflows/docker/incremental/Dockerfile"
  docker_base_image_install_pkgs_file       = "spiffy/service/workflows/conda/environment.yml"
  environment                               = var.environment
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps = [
  ]
  additional_environment_vars_on_steps = []
  additional_build_args_on_docker_build = [
    "--build-arg UNION_AUTH_SECRET=${data.google_secret_manager_secret_version.union_cloud_app_secret[0].secret_data}",
  ]
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_machine_type                             = "E2_HIGHCPU_32"
}

data "google_secret_manager_secret_version" "huggingface-access-token" {
  count   = 1
  secret  = "huggingface-access-token"
  project = var.project_id
}

module "git-repo-pymono-for-all-services" {

  count = 1
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.pymono-repo
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "pymono"
  create_linked_github_repository           = false
  is_mono_repo                              = true
  disable_sonar_checks                      = true
  mono_repo_entrypoint_id                   = "svc-common"
  linked_github_repository_id               = google_cloudbuildv2_repository.pymono-repo[0].id
  incremental_docker_builder_available      = true
  dockerfile_file_name_base_image           = "spiffy/service/common/docker/base/Dockerfile"
  dockerfile_file_name                      = "spiffy/service/common/docker/incremental/Dockerfile"
  docker_base_image_install_pkgs_file       = "spiffy/service/common/conda/environment.yml"
  environment                               = var.environment
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  additional_build_args_on_docker_build = [
    "--build-arg CONDA_ENVIRONMENT_YML_FILEPATH=spiffy/service/common/conda/environment.yml"
  ]
  additional_environment_vars_on_steps = [
    "HUGGINGFACE_ACCESS_TOKEN=${data.google_secret_manager_secret_version.huggingface-access-token[0].secret_data}",
  ]
  build_test_steps = var.environment == "dev" ? [
    {
      image      = null
      entrypoint = "pytest"
      args       = [ "spiffy", "-v", "-s","-n","auto","--cov=spiffy","--cov-report=xml:coverage-report.xml"]
    },
    {
      image      = "us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest"
      entrypoint = "codecov"
      args = [
        "--verbose", "upload-process", "-t", # add --fail-on-error back when codecov is fixed
        data.google_secret_manager_secret_version.codecov_token[0].secret_data,
        "-n",
        "pymono-svc-common-build-$${COMMIT_SHA}", "-F", "pymono-svc-common", "-f", "coverage-report.xml"
      ]
    }
  ] : []
  post_build_deployment_steps = [
    {
      enabled        = local.segment_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "segment-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.rudderstack_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "rudderstack-intake",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.segment_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "segment-intake",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.rudderstack_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "rudderstack-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "chat-sessions",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.simondata_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "simondata-intake",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.simondata_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "simondata-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "api-internal",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "commerce-api",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "retrieval-search-indexing",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.shopfiy_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "shopify-intake",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = local.shopfiy_webhooks_ingest_enabled
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "shopify-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "model-training-activities",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "organizations",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "analytics-gateway",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "cdc-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "analytics-streams-processor",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
  ]
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_machine_type                             = "e2_standard_32"
}

######################################## repo: webapp-admin ########################################

resource "google_cloudbuildv2_repository" "spiffy-webapp-mono-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "webapp-mono"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/webapp-mono.git"
}

data "google_secret_manager_secret_version" "datadog-client-token" {
  secret  = "datadog_client_token_for_commerce_chat"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog-app-id" {
  secret  = "datadog_app_id_for_commerce_chat"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-domain" {
  secret  = "webapp-admin-auth0-domain"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-client-id" {
  secret  = "webapp-admin-auth0-client-id"
  project = var.project_id
}

module "git-repo-webapp-admin" {

  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "webapp-mono"
  create_linked_github_repository           = false
  mono_repo_entrypoint_id                   = "admin"
  is_mono_repo                              = true
  linked_github_repository_id               = google_cloudbuildv2_repository.spiffy-webapp-mono-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps = var.environment == "dev" && false ? [
    {
      image      = null
      entrypoint = "npm"
      args       = ["install", "--prefix", "admin"]
    },
    {
      image      = null
      entrypoint = "npm"
      args       = ["run", "--prefix", "admin", "test:coverage"]
    },
    {
      image      = null
      entrypoint = "npm"
      args       = ["run", "--prefix", "admin", "build"]
    },
    {
      image      = "us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest"
      entrypoint = "codecov"
      args = [
        "--verbose", "upload-process", "-t", # add --fail-on-error back when codecov is fixed
        data.google_secret_manager_secret_version.codecov_token[0].secret_data,
        "-n",
        "webapp-mono-$${COMMIT_SHA}", "-F", "webapp-mono", "-f", "admin/coverage/coverage-final.json"
      ]
    },
  ] : []
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "webapp-admin",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_services_apps,
      steps          = null
    },
  ]
  dockerfile_file_name = "admin/Dockerfile"
  additional_build_args_on_docker_build = [
    "--build-arg NEXT_PUBLIC_AUTH0_DOMAIN=${data.google_secret_manager_secret_version.webapp-admin-auth0-domain.secret_data}",
    "--build-arg NEXT_PUBLIC_AUTH0_CLIENT_ID=${data.google_secret_manager_secret_version.webapp-admin-auth0-client-id.secret_data}",
    "--build-arg NEXT_PUBLIC_AUTH0_AUDIENCE=https://api.dev.envive.ai",
    "--build-arg NEXT_PUBLIC_ENV=${var.environment}",
    "--build-arg NEXT_PUBLIC_DATADOG_CLIENT_TOKEN=${data.google_secret_manager_secret_version.datadog-client-token.secret_data}",
    "--build-arg NEXT_PUBLIC_DATADOG_APPLICATION_ID=${data.google_secret_manager_secret_version.datadog-app-id.secret_data}",
    "--build-arg NEXT_PUBLIC_SPIFFY_API_URL=https://api.dev.spiffy.ai",
    "--build-arg NEXT_PUBLIC_COMMERCE_API_URL=https://commerce-api.dev.spiffy.ai",
    "--build-arg NEXT_PUBLIC_GOOGLE_CLOUD_CDN_BUCKET=spiffy-chat-frontend-dev",
  ]
  # Rebuild with prod env vars during promote-to-prod (NEXT_PUBLIC_* are baked in at npm run build time)
  post_pull_rebuild_config = var.environment == "prod" ? {
    rebuild_script = "echo NEXT_PUBLIC_AUTH0_CLIENT_ID=$NEXT_PUBLIC_AUTH0_CLIENT_ID && cd /opt/app && npm run build"
    build_args = [
      "--build-arg NEXT_PUBLIC_AUTH0_DOMAIN=${data.google_secret_manager_secret_version.webapp-admin-auth0-domain.secret_data}",
      "--build-arg NEXT_PUBLIC_AUTH0_CLIENT_ID=${data.google_secret_manager_secret_version.webapp-admin-auth0-client-id.secret_data}",
      "--build-arg NEXT_PUBLIC_AUTH0_AUDIENCE=https://api.envive.ai",
      "--build-arg NEXT_PUBLIC_ENV=${var.environment}",
      "--build-arg NEXT_PUBLIC_DATADOG_CLIENT_TOKEN=${data.google_secret_manager_secret_version.datadog-client-token.secret_data}",
      "--build-arg NEXT_PUBLIC_DATADOG_APPLICATION_ID=${data.google_secret_manager_secret_version.datadog-app-id.secret_data}",
      "--build-arg NEXT_PUBLIC_SPIFFY_API_URL=https://api.spiffy.ai",
      "--build-arg NEXT_PUBLIC_COMMERCE_API_URL=https://commerce-api.spiffy.ai",
      "--build-arg NEXT_PUBLIC_GOOGLE_CLOUD_CDN_BUCKET=spiffy-chat-frontend-prod",
    ]
  } : null
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_timeout                                  = "1600s"
}

######################################## repo: vllm ########################################

module "git-repo-vllm" {

  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "vllm"
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  pre_build_steps                           = []
  build_test_steps                          = []
  additional_environment_vars_on_steps      = ["DOCKER_BUILDKIT=1"]
  #  main_branch_name                               = "upstream-main-20240717-merge"
  main_branch_name     = "upstream-main-20240419-merge"
  dockerfile_file_name = "Dockerfile"
  build_timeout        = "14400s"
  disable_sonar_checks = true
  # roughly takes about 1 hour and 10 mins to build as of 02-19-2024!
  build_machine_type                             = "E2_HIGHCPU_32"
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  post_build_deployment_steps = var.environment == "prod" ? [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-svc-llama-3-8b-usw1",
      cluster_name   = module.container-cluster-secondary-region[0].cluster_name,
      cluster_region = module.container-cluster-secondary-region[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-svc-llama-3-70b-qtz-usw1",
      cluster_name   = module.container-cluster-secondary-region[0].cluster_name,
      cluster_region = module.container-cluster-secondary-region[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-svc-llama-3-70b-qtz-usc1",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-svc-llama-3-70b-qtz-usc1-spot-cap",
      cluster_name   = module.container-cluster-default[0].cluster_name,
      cluster_region = module.container-cluster-default[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-svc-llama-3-70b-qa-usw1",
      cluster_name   = module.container-cluster-secondary-region[0].cluster_name,
      cluster_region = module.container-cluster-secondary-region[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    ] : [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-service-llama-3-70b-usc1",
      cluster_name   = module.container-cluster-secondary-region[0].cluster_name,
      cluster_region = module.container-cluster-secondary-region[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    },
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "gke",
      service_name   = "llm-inference-service-llama-3-8b-usc1",
      cluster_name   = module.container-cluster-secondary-region[0].cluster_name,
      cluster_region = module.container-cluster-secondary-region[0].cluster_region,
      namespace      = local.gke_workload_namespace_for_llm_apps,
      steps          = null
    }
  ]
}

######################################## repo: nwac ########################################

module "git-repo-nwac" {

  count       = 0
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "nwac"
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  pre_build_steps                           = []
  build_test_steps                          = []
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrun",
      service_name   = "nwac-data-api",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    },
  ]
  build_machine_type                             = "E2_MEDIUM"
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
}

######################################## repo: spiffy-react-components ########################################

resource "google_cloudbuildv2_repository" "spiffy-react-components-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "spiffy-react-components"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/spiffy-react-components.git"
}

module "git-repo-for-spiffy-react-components" {
  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_project_iam_member.cloudbuild_service_account_cloud_run_job_invoker[0],
    google_cloudbuildv2_repository.spiffy-react-components-repo[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "spiffy-react-components"
  create_linked_github_repository           = false
  linked_github_repository_id               = google_cloudbuildv2_repository.spiffy-react-components-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  additional_packaging_steps = [
    #     {
    #       # this forces the docker image output to run the entrypoint thus producing the npm build
    #       # for the branch that is being built
    #       on_pull_requests_only = true
    #       entrypoint = null
    #       script = <<EOF
    # #!/bin/bash
    # /opt/spiffy-react-components/docker/scripts/npm-build-for-merchant.sh
    # EOF
    #       args = [
    #       ]
    #     }
  ]
  build_test_steps = var.environment == "dev" ? [
    {
      id         = "npm-install"
      wait_for   = []
      image      = null
      entrypoint = "npm"
      args       = ["install"]
    },
    {
      id         = "build-storybook"
      wait_for   = ["npm-install"]
      image      = null
      entrypoint = "npm"
      args       = ["run", "build-storybook"]
    },
    {
      id         = "run-lost-pixel"
      wait_for   = ["build-storybook"]
      image      = "gcr.io/cloud-builders/docker"
      entrypoint = null
      args = [
        "run", "--platform", "linux/amd64", "-v", "/workspace:/workspace", "-e", "WORKSPACE=/workspace", "-e", "VITE_BASE_URL=https://commerce-api.dev.spiffy.ai", "-e", "VITE_IS_LOCAL_ENV=true", "-e",
        "DOCKER=1", "lostpixel/lost-pixel:v3.22.0"
      ]
    },
    {
      id         = "upload-lost-pixel"
      wait_for   = ["run-lost-pixel"]
      image      = null
      entrypoint = "npm"
      args       = ["run", "lost-pixel:check"]
    },
    {
      id         = "unit-tests"
      wait_for   = ["npm-install"]
      image      = null
      entrypoint = "npm"
      args       = ["run", "test:coverage"]
    },
    {
      id         = "build"
      wait_for   = ["npm-install"]
      image      = null
      entrypoint = "npm"
      args       = ["run", "build"]
    },
    #     {
    #       id         = "upload-to-gcs"
    #       wait_for   = ["build"]
    #       image      = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine"
    #       entrypoint = null # I don't think alpine has bash
    #       script = <<EOF
    # #!/bin/sh
    # # Generate datetime string in the required format
    # # Generate datetime string in the required format
    # DATETIME=$(date +"%B_%d_%Y_%H_%M_%S" | tr '[:upper:]' '[:lower:]')
    #
    # # Create the destination path
    # DEST_PATH="gs://${local.build_artifacts_bucket_name}/builds/spiffy-react-components/$${COMMIT_SHA}/$DATETIME/index.js"
    #
    # echo "Uploading dist/index.js to $DEST_PATH"
    # echo "Build timestamp: $DATETIME"
    # echo "Commit SHA: $${COMMIT_SHA}"
    #
    # # Upload the specific file to the timestamped path
    # gcloud storage cp ./dist/index.js "$DEST_PATH"
    #
    # # Store the path and metadata for potential use in subsequent steps
    # echo "$DEST_PATH" > /workspace/uploaded_bundle_path.txt
    # echo "$DATETIME" > /workspace/build_timestamp.txt
    # echo "Bundle uploaded successfully to: $DEST_PATH"
    #
    # EOF
    #     },
    #     {
    #       id         = "execute-cloudrun-job"
    #       wait_for   = ["upload-to-gcs"]
    #       image      = "gcr.io/google.com/cloudsdktool/cloud-sdk:alpine"
    #       entrypoint = null
    #       script = <<EOF
    # #!/bin/sh
    # # Extract out the bundle path
    # UPLOADED_PATH=$(cat /workspace/uploaded_bundle_path.txt)
    #
    # # Execute the Cloud Run job
    # EXECUTION_NAME=$(gcloud run jobs execute ${local.spiffy_react_components_e2e_tests_cloud_run_job_name} \
    #   --region=${var.region_default} \
    #   --format="value(metadata.name)" \
    #   --update-env-vars=RUN_TYPE=integration,MERCHANT_IDS=${local.spiffy_react_components_e2e_tests_merchant_ids},BUNDLE_PATH=$${UPLOADED_PATH},BUNDLE_BUCKET=${local.build_artifacts_bucket_name})
    #
    # # Print the execution URL for notifications
    # echo "Cloud Run Job Execution URL: https://console.cloud.google.com/run/jobs/executions/details/${var.region_default}/$${EXECUTION_NAME}?project=${var.project_id}"
    #
    # # Store execution info for potential use in subsequent steps
    # echo "$${EXECUTION_NAME}" > /workspace/execution_name.txt
    # echo "https://console.cloud.google.com/run/jobs/executions/details/${var.region_default}/$${EXECUTION_NAME}/logs?project=${var.project_id}" > /workspace/execution_url.txt
    # EOF
    #     },
    {
      id         = "code-coverage"
      wait_for   = ["npm-install"]
      image      = "us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest"
      entrypoint = "codecov"
      args = [
        "--verbose", "upload-process", "--fail-on-error", "-t", # add --fail-on-error back when codecov is fixed
        data.google_secret_manager_secret_version.codecov_token[0].secret_data,
        "-n",
        "spiffy-react-components-$${COMMIT_SHA}", "-F", "spiffy-react-components", "-f", "coverage/coverage-final.json"
      ]
    },
    {
      id         = "chromatic-upload"
      wait_for   = ["build-storybook"]
      image      = null
      entrypoint = "npm"
      args       = ["run", "chromatic"]
    },
    #     {
    #       id         = "message-end-step"
    #       wait_for   = ["chromatic-upload", "code-coverage", "execute-cloudrun-job"]
    #       image      = null
    #       entrypoint = null
    #       script = <<EOF
    # #!/bin/sh
    # EXECUTION_NAME=$(cat /workspace/execution_name.txt)
    # echo "================================================"
    # echo "Finished building spiffy-react-components"
    # echo "Please check the following cloud run job url to find the test results:"
    # echo "https://console.cloud.google.com/run/jobs/executions/details/${var.region_default}/$${EXECUTION_NAME}?project=${var.project_id}"
    # echo "================================================"
    # EOF
    #     }
  ] : []
  additional_environment_vars_on_steps = [
    "DOCKER=1",
    "LOST_PIXEL_DISABLE_TELEMETRY=true",
    "ARTIFACT_BUCKET=spiffy-deployment-artifacts-dev",
    "CHROMATIC_PROJECT_TOKEN=${data.google_secret_manager_secret_version.spiffy_react_components_chromatic_project_token.secret_data}",
  ]
  additional_build_args_on_docker_build = [
    "--build-arg CDN_BUCKET_NAME=spiffy-chat-frontend-prod",
  ]
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrun_job",
      service_name   = "spiffy-react-components",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    }
  ]
  build_machine_type                             = "E2_MEDIUM"
  main_branch_name                               = "main"
  incremental_docker_builder_available           = true
  docker_conditional_build_script_run_cmd        = "sh docker/scripts/docker-build-conditional.sh"
  dockerfile_file_name_base_image                = "docker/base/Dockerfile"
  dockerfile_file_name                           = "docker/incremental/Dockerfile"
  docker_base_image_install_pkgs_file            = "package.json"
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_timeout                                  = "3600s"
}

######################################## repo: merchants-proxy ########################################

resource "google_cloudbuildv2_repository" "spiffy-merchants-proxy-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "merchant-proxy-server"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/merchant-proxy-server.git"
}

module "git-repo-for-merchants-proxy" {
  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.spiffy-merchants-proxy-repo[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "merchant-proxy-server"
  create_linked_github_repository           = false
  linked_github_repository_id               = google_cloudbuildv2_repository.spiffy-merchants-proxy-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps                          = []
  additional_environment_vars_on_steps      = []
  additional_build_args_on_docker_build = [
  ]
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrun",
      service_name   = "merchants-proxy",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    }
  ]
  build_machine_type                             = "E2_MEDIUM"
  main_branch_name                               = "main"
  incremental_docker_builder_available           = false
  docker_conditional_build_script_run_cmd        = null
  dockerfile_file_name_base_image                = null
  dockerfile_file_name                           = "Dockerfile"
  docker_base_image_install_pkgs_file            = null
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
}

######################################## repo: workflows ########################################

resource "google_cloudbuildv2_repository" "spiffy-workflows-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "workflows"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/workflows.git"
}

module "git-repo-for-workflows" {
  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.spiffy-workflows-repo[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "workflows"
  create_linked_github_repository           = false
  linked_github_repository_id               = google_cloudbuildv2_repository.spiffy-workflows-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps                          = []
  additional_environment_vars_on_steps      = []
  additional_build_args_on_docker_build = [
  ]
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrunjob",
      service_name   = "workflows-deploy",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    }
  ]
  build_machine_type                             = "E2_MEDIUM"
  main_branch_name                               = "main"
  incremental_docker_builder_available           = true
  dockerfile_file_name_base_image                = "spiffy/service/common/docker/base/Dockerfile"
  dockerfile_file_name                           = "spiffy/service/common/docker/incremental/Dockerfile"
  docker_base_image_install_pkgs_file            = "spiffy/service/common/conda/requirements.txt"
  docker_conditional_build_script_run_cmd        = null
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
}

######################################## repo: shopify-app ########################################

resource "google_cloudbuildv2_repository" "shopify-app-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "shopify-app"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/shopify-app.git"
}

module "git-repo-for-shopify-app" {
  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.shopify-app-repo[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "shopify-app"
  create_linked_github_repository           = false
  linked_github_repository_id               = google_cloudbuildv2_repository.shopify-app-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps                          = []
  additional_environment_vars_on_steps      = []
  additional_build_args_on_docker_build = [
  ]
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrun",
      service_name   = "shopify-app",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    }
  ]
  build_machine_type                             = "E2_MEDIUM"
  main_branch_name                               = "main"
  incremental_docker_builder_available           = false
  docker_conditional_build_script_run_cmd        = null
  dockerfile_file_name_base_image                = null
  dockerfile_file_name                           = "Dockerfile"
  docker_base_image_install_pkgs_file            = null
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
}

######################################## repo: envive-analytics-sdk ########################################

resource "google_cloudbuildv2_repository" "envive-analytics-sdk-repo" {

  count             = 1
  project           = var.project_id
  location          = var.region_default
  name              = "envive-analytics-sdk"
  parent_connection = local.repository_connection_name
  remote_uri        = "https://github.com/${var.github_org_name}/envive-analytics-sdk.git"
}

module "git-repo-for-envive-analytics-sdk" {
  count       = 1
  environment = var.environment
  depends_on = [
    google_service_account_iam_member.cloudbuild_sa_can_impersonate[0],
    google_project_iam_member.cloudbuild_service_account_logs_writer[0],
    google_cloudbuildv2_repository.envive-analytics-sdk-repo[0]
  ]
  source                                    = "../modules/create_cloudbuild_trigger"
  github_org_name                           = var.github_org_name
  github_repo_name                          = "envive-analytics-sdk"
  create_linked_github_repository           = false
  linked_github_repository_id               = google_cloudbuildv2_repository.envive-analytics-sdk-repo[0].id
  project_id                                = google_project.deployment-project.project_id
  region                                    = var.region_default
  org_name                                  = var.org_name
  repository_connection_name                = local.repository_connection_name
  worker_pool_name                          = local.worker_pool_name
  cloudbuild_service_account                = local.cloudbuild_trigger_sa
  cloudbuild_service_account_for_promotions = local.cloudbuild_trigger_sa_for_promotions
  prod_project_id                           = data.terraform_remote_state.prod.outputs.project_id
  build_test_steps = var.environment == "dev" ? [
    {
      image      = null
      entrypoint = "npm"
      args       = ["install"]
    },
    {
      image      = null
      entrypoint = "npm"
      args       = ["run", "test:coverage"]
    },
    {
      image      = null
      entrypoint = "npm"
      args       = ["run", "build"]
    },
  ] : []
  additional_environment_vars_on_steps = [
    "DOCKER=1",
    "LOST_PIXEL_DISABLE_TELEMETRY=true",
    "ARTIFACT_BUCKET=spiffy-deployment-artifacts-dev",
  ]
  additional_build_args_on_docker_build = [
    "--build-arg CDN_BUCKET_NAME=spiffy-chat-frontend-prod",
  ]
  post_build_deployment_steps = [
    {
      enabled        = true
      step_type      = "gcs_service_deploy",
      service_type   = "cloudrun_job",
      service_name   = "envive-analytics-sdk",
      cluster_name   = null,
      cluster_region = null,
      namespace      = null,
      steps          = null
    }
  ]
  build_machine_type                             = "E2_MEDIUM"
  main_branch_name                               = "main"
  incremental_docker_builder_available           = true
  docker_conditional_build_script_run_cmd        = "sh docker/scripts/docker-build-conditional.sh"
  dockerfile_file_name_base_image                = "docker/base/Dockerfile"
  dockerfile_file_name                           = "docker/incremental/Dockerfile"
  docker_base_image_install_pkgs_file            = "package.json"
  github_deploy_key_secret_manager_version_name  = data.google_secret_manager_secret_version.github-access-ssh-noop-key[0].name
  github_known_hosts_secret_manager_version_name = data.google_secret_manager_secret_version.github-access-ssh-known-hosts[0].name
  build_timeout                                  = "3600s"
}
