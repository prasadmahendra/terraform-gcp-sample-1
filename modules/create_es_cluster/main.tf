terraform {
  required_providers {
    ec = {
      source = "elastic/ec"
    }
  }
}

data "ec_stack" "latest" {
  version_regex = "latest"
  region        = var.region
}

locals {
  zone_count = var.environment == "prod" ? 3 : 2
  cold_and_frozen_zone_count = var.environment == "prod" ? 2 : 1
}

resource "ec_deployment" "ec_deployment_config" {

  name                   = var.cluster_name
  region                 = var.region
  version                = data.ec_stack.latest.version
  deployment_template_id = "gcp-cpu-optimized"
  elasticsearch          = {
    autoscale = "true"

    # If `autoscale` is set, all topology elements that
    # - either set `size` in the plan or
    # - have non-zero default `max_size` (that is read from the deployment templates's `autoscaling_max` value)
    # have to be listed even if their blocks don't specify other fields beside `id`
    master = {
      autoscaling   = {}
      size          = "0g"
      size_resource = "memory"
      zone_count    = local.zone_count
    }
    hot = {
      size        = "8g"
      autoscaling = {
        max_size          = "64g"
        max_size_resource = "memory"
      }
      zone_count = local.zone_count
    }
    warm = {
      autoscaling = {
        max_size          = "8g"
        max_size_resource = "memory"
      }
      size       = "0g"
      zone_count = local.zone_count
    }
    cold = {
      autoscaling = {
        max_size          = "8g"
        max_size_resource = "memory"
      }
      #      instance_configuration_id = "gcp.es.datacold.n2.68x10x190"
      #      node_roles                = [
      #        "data_cold",
      #        "remote_cluster_client",
      #      ]
      size       = "0g"
      zone_count = local.cold_and_frozen_zone_count
    }
    frozen = {
      autoscaling = {
        max_size          = "4g"
        max_size_resource = "memory"
      }
      size       = "0g"
      zone_count = local.cold_and_frozen_zone_count
    }
    ml = {
      autoscaling = {
        max_size          = "64g"
        max_size_resource = "memory"
        min_size          = "0g"
        min_size_resource = "memory"
      }
      size       = "0g"
      zone_count = 1
    }
    config = {
      plugins = []
    }
    coordinating = {
      autoscaling   = {}
      size          = "0g"
      size_resource = "memory"
      zone_count    = local.zone_count
    }
  }

  # Initial size for `hot_content` tier is set to 8g
  # so `hot_content`'s size has to be added to the `ignore_changes` meta-argument to ignore future modifications that can be made by the autoscaler
  lifecycle {
    ignore_changes = [
      version,
      elasticsearch.hot.size,
      enterprise_search
    ]
  }

  enterprise_search = {
    instance_configuration_id = "gcp.enterprisesearch.n2.68x32x45"
    size                      = "2g"
  }
  integrations_server = {
    instance_configuration_id = "gcp.integrationsserver.n2.68x32x45"
    size                      = "1g"
  }
  kibana = {
    instance_configuration_id = "gcp.kibana.n2.68x32x45"
    size                      = "1g"
  }
}