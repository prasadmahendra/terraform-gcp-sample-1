module "elastic-search-default-cluster" {
  source      = "../../../modules/create_es_cluster"
  environment = var.environment
  project_id  = var.project_id
#  providers   = {
#    ec = ec.ec-default
#  }
#  providers          = {
#    ec =  elastic/ec.ec-default
#  }
  cluster_name = var.cluster_name
  region       = var.region
}