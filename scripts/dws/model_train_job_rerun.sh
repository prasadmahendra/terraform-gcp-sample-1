env=$1

if [ "$env" == "prod" ]; then
  REGION=us-west1
  PROJECT=spiffy-prod
  CLUSTER_NAME=gke-dws-secondary-region
else
  REGION=us-central1
  PROJECT=spiffy-ai-dev
  CLUSTER_NAME=gke-dws-secondary-region
fi

NAMESPACE=apps-services-ns

gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT

kubectl describe job model-train-job --namespace=$NAMESPACE > model-train-job.json

kubectl get job model-train-job --namespace=$NAMESPACE -o json | \
  jq 'del(.spec.selector)' | \
  jq 'del(.spec.template.metadata.labels)' | \
  jq 'del(.spec.template.metadata.annotations)' | \
  kubectl replace --force --namespace=$NAMESPACE -f -

# cleanup
rm model-train-job.json

