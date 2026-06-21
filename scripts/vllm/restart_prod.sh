
SCRIPT_ENVIRONMENT=prod
MODEL_SIZE=70b

GCP_TRIGGERS_REGION=us-central1
GCP_GKE_CLUSTER_REGION=us-central1

if [ "$MODEL_SIZE" == "70b" ]; then
    GKE_SERVICE_NAME=llm-inference-service-llama-3-70b
else
    GKE_SERVICE_NAME=llm-inference-svc-llama-3-${MODEL_SIZE}-usc1
fi

GKE_TRIGGER_NAME="deploy-gke-${GKE_SERVICE_NAME}-svc"


GCP_PROJECT_ID=spiffy-ai-${SCRIPT_ENVIRONMENT}
if [ "$SCRIPT_ENVIRONMENT" == "dev" ]; then
    GCP_PROJECT_ID=spiffy-ai-dev
else
   GCP_PROJECT_ID=spiffy-${SCRIPT_ENVIRONMENT}
fi



echo "Update GKE service = ${GKE_TRIGGER_NAME}"
gcloud builds triggers run ${GKE_TRIGGER_NAME} --project=${GCP_PROJECT_ID} --region=${GCP_TRIGGERS_REGION}

