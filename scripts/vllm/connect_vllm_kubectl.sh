# use interatively to connect to running VLLM instances

NAMESPACE=apps-llm-ns
REGION=us-central1
PROJECT=spiffy-ai-dev
CLUSTER_NAME=gke-us-central1

# prod
NAMESPACE=apps-llm-ns
REGION=us-west1
PROJECT=spiffy-prod
CLUSTER_NAME=gke-us-west1


gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT

kubectl get pods --namespace=$NAMESPACE

POD_NAME=llm-inference-service-llama-3-70b-usc1-657cfc7599-k9c48

kubectl exec -it --namespace=$NAMESPACE $POD_NAME -- /bin/bash


# for prod
POD_NAME=llm-inference-service-llama-3-70b-7d6898b46c-t5kjc
POD_NAME=llm-inference-service-llama-3-70b-7d6898b46c-x4jvf





