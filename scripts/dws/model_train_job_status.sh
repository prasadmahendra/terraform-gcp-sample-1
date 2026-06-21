#!/bin/bash
#
# ./model_train_job_status.sh dev model-train-job

env=$1
job_name=$2

if [ "$env" == "prod" ]; then
  REGION=us-west1
  PROJECT=spiffy-prod
  CLUSTER_NAME=gke-dws-secondary-region
else
  REGION=us-central1
  PROJECT=spiffy-ai-dev
  CLUSTER_NAME=gke-dws-secondary-region
fi


gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT
#kubectl describe job model-train-job --namespace=apps-services-ns
kubectl describe job $job_name --namespace=apps-services-ns

# kubectl describe provreq dws-config --namespace=apps-services-ns
