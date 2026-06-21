# Import blocks for resources that already exist in the cluster but were not in TF state.
# These were identified from the failed apply-prod job #226 on 2026-05-29.
# Once imported, these blocks can be removed after a successful apply.

# ── Persistent Volumes ──────────────────────────────────────────────────────────

import {
  to = module.llm-inference-service-set-default-region[0].module.llm-inference-service-gcs-bucket-pv.kubernetes_persistent_volume.persistent_volume
  id = "llm-inference-svc-us-central1-gcs-pv"
}

# ── Service Accounts ─────────────────────────────────────────────────────────────

import {
  to = module.cdc-streams-processor[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/cdc-streams-processor-k8-sa"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/shopify-intake-k8-sa"
}

# text-generation-service[0] = textembed-default
import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-llm-ns/llm-inference-svc-textembed-default-k8-sa"
}



# ── Deployments ──────────────────────────────────────────────────────────────────

import {
  to = module.api-internal[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/api-internal"
}

import {
  to = module.cdc-main-db[0].module.debezium-service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/cdc-main-db"
}

import {
  to = module.webapp-admin[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/webapp-admin"
}

# ── Services (service_private_lb / *-http-server) ─────────────────────────────────

import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_service_v1.service_private_lb
  id = "apps-llm-ns/llm-inference-svc-textembed-default-http-server"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_service_v1.service_private_lb
  id = "apps-services-ns/shopify-intake-http-server"
}

# ── Ingresses ────────────────────────────────────────────────────────────────────

import {
  to = module.api-internal[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/api-internal-ingress"
}

import {
  to = module.cdc-main-db[0].module.debezium-service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/cdc-main-db-ingress"
}

# ── Persistent Volume Claims ──────────────────────────────────────────────────────

import {
  to = module.llm-inference-service-set-default-region[0].module.llm-inference-service-gcs-bucket-pv.kubernetes_persistent_volume_claim.persistent_volume_claim
  id = "apps-llm-ns/llm-inference-svc-us-central1-gcs-pvc"
}

# ── Additional Deployments (found in apply job 240) ───────────────────────────────

import {
  to = module.cdc-streams-processor[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/cdc-streams-processor"
}

import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-llm-ns/llm-inference-svc-textembed-default"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/shopify-intake"
}

# ── BackendConfig kubernetes_manifest resources ───────────────────────────────────
# These exist in K8s but were not in TF state — force_conflicts only helps for
# resources already in state with field manager conflicts, not for missing state.

import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_manifest.kubernetes_manifest_ingress_backend_config[0]
  id = "apiVersion=cloud.google.com/v1,kind=BackendConfig,namespace=apps-llm-ns,name=llm-inference-svc-textembed-default-nodeport-backend-config"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_manifest.kubernetes_manifest_ingress_backend_config[0]
  id = "apiVersion=cloud.google.com/v1,kind=BackendConfig,namespace=apps-services-ns,name=shopify-intake-nodeport-backend-config"
}

# ── ManagedCertificate kubernetes_manifest resources ─────────────────────────────

import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_manifest.kubernetes_manifest_managed_cert_config[0]
  id = "apiVersion=networking.gke.io/v1,kind=ManagedCertificate,namespace=apps-llm-ns,name=prod-spiffy-env-domain-cert-for-llm-inference-svc-textembed-default"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_manifest.kubernetes_manifest_managed_cert_config[0]
  id = "apiVersion=networking.gke.io/v1,kind=ManagedCertificate,namespace=apps-services-ns,name=prod-spiffy-env-domain-cert-for-shopify-intake"
}

import {
  to = module.webapp-admin[0].module.service.kubernetes_manifest.kubernetes_manifest_managed_cert_config[0]
  id = "apiVersion=networking.gke.io/v1,kind=ManagedCertificate,namespace=apps-services-ns,name=prod-spiffy-env-domain-cert-v2-for-webapp-admin"
}

# ── Pub/Sub Subscriptions ─────────────────────────────────────────────────────────

import {
  to = module.cdc-streams-processor[0].module.cdc-streams-processor[1].google_pubsub_subscription.subscription
  id = "projects/spiffy-prod/subscriptions/cdc-main-db.public.organizations_config-cdc-stream-sub"
}

# ── Additional resources found in apply job 247 ───────────────────────────────────

# GRPC ClusterIP services
import {
  to = module.cdc-streams-processor[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/cdc-streams-processor-grpc-server"
}

# NodePort services (HTTP services use nodeport for GKE Ingress)
import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_service_v1.service_node_port
  id = "apps-llm-ns/llm-inference-svc-textembed-default-nodeport"
}

import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_service_v1.service_node_port
  id = "apps-services-ns/shopify-intake-nodeport"
}

# Ingresses
import {
  to = module.shopify-webhooks-intake-service[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/shopify-intake-ingress"
}

import {
  to = module.webapp-admin[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/webapp-admin-ingress"
}

import {
  to = module.llm-inference-service-set-default-region[0].module.text-generation-service[0].module.text-generation-service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-llm-ns/llm-inference-svc-textembed-default-ingress"
}

# ── Additional resources found in apply job 254 ───────────────────────────────────

# analytics-gateway (HTTP service — full set)
import {
  to = module.analytics-gateway[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/analytics-gateway"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/analytics-gateway-ingress"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_manifest.kubernetes_manifest_ingress_backend_config[0]
  id = "apiVersion=cloud.google.com/v1,kind=BackendConfig,namespace=apps-services-ns,name=analytics-gateway-nodeport-backend-config"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_manifest.kubernetes_manifest_managed_cert_config[0]
  id = "apiVersion=networking.gke.io/v1,kind=ManagedCertificate,namespace=apps-services-ns,name=prod-spiffy-env-domain-cert-for-analytics-gateway"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/analytics-gateway-k8-sa"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_service_v1.service_node_port
  id = "apps-services-ns/analytics-gateway-nodeport"
}
import {
  to = module.analytics-gateway[0].module.service.kubernetes_service_v1.service_private_lb
  id = "apps-services-ns/analytics-gateway-http-server"
}

# mcp (HTTP service — full set)
import {
  to = module.mcp[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/mcp"
}
import {
  to = module.mcp[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/mcp-ingress"
}
import {
  to = module.mcp[0].module.service.kubernetes_manifest.kubernetes_manifest_ingress_backend_config[0]
  id = "apiVersion=cloud.google.com/v1,kind=BackendConfig,namespace=apps-services-ns,name=mcp-nodeport-backend-config"
}
import {
  to = module.mcp[0].module.service.kubernetes_manifest.kubernetes_manifest_managed_cert_config[0]
  id = "apiVersion=networking.gke.io/v1,kind=ManagedCertificate,namespace=apps-services-ns,name=prod-spiffy-env-domain-cert-v2-for-mcp"
}
import {
  to = module.mcp[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/mcp-k8-sa"
}
import {
  to = module.mcp[0].module.service.kubernetes_service_v1.service_node_port
  id = "apps-services-ns/mcp-nodeport"
}
import {
  to = module.mcp[0].module.service.kubernetes_service_v1.service_private_lb
  id = "apps-services-ns/mcp-http-server"
}

# commerce-api (HTTP service — deployment + ingress only; rest already in TF state)
import {
  to = module.commerce-api[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment[0]
  id = "apps-services-ns/commerce-api"
}
import {
  to = module.commerce-api[0].module.service.kubernetes_ingress_v1.service_ingress[0]
  id = "apps-services-ns/commerce-api-ingress"
}

# analytics-streams-processor (GRPC service)
import {
  to = module.analytics-streams-processor[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/analytics-streams-processor"
}
import {
  to = module.analytics-streams-processor[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/analytics-streams-processor-k8-sa"
}
import {
  to = module.analytics-streams-processor[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/analytics-streams-processor-grpc-server"
}

# chat-sessions-service (GRPC service; K8s name is chat-sessions)
import {
  to = module.chat-sessions-service[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/chat-sessions"
}
import {
  to = module.chat-sessions-service[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/chat-sessions-k8-sa"
}
import {
  to = module.chat-sessions-service[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/chat-sessions-grpc-server"
}

# model-training-activities (GRPC service)
import {
  to = module.model-training-activities[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/model-training-activities"
}
import {
  to = module.model-training-activities[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/model-training-activities-k8-sa"
}
import {
  to = module.model-training-activities[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/model-training-activities-grpc-server"
}

# organizations (GRPC service)
import {
  to = module.organizations[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/organizations"
}
import {
  to = module.organizations[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/organizations-k8-sa"
}
import {
  to = module.organizations[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/organizations-grpc-server"
}

# shopify-streams-processor (GRPC service)
import {
  to = module.shopify-streams-processor[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/shopify-streams-processor"
}
import {
  to = module.shopify-streams-processor[0].module.service.kubernetes_service_account.kubernetes_service_account_k8_sa
  id = "apps-services-ns/shopify-streams-processor-k8-sa"
}
import {
  to = module.shopify-streams-processor[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/shopify-streams-processor-grpc-server"
}
