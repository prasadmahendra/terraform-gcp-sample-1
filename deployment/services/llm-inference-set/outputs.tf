output "llm-inference-service-gcs-bucket-pv" {
  value = module.llm-inference-service-gcs-bucket-pv.persistent_volume_claim_name
}