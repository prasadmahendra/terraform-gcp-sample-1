#/bin/bash

# ./connect_to_running_job.sh test-debug
#

job_name=$1

# For env=dev
REGION=us-central1
PROJECT=spiffy-ai-dev
CLUSTER_NAME=gke-dws-secondary-region
NAMESPACE=apps-services-ns

gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT

kubectl get pods --namespace=$NAMESPACE

# Get running pods
running_pods=`kubectl get pods --namespace=$NAMESPACE | grep $job_name | grep Running | cut -d ' ' -f 1`

# Loop through the running pods
for pod in $running_pods
do
    read -p "Connect? $pod (y/n): " connect
    if [ "$connect" == "y" ]; then
        kubectl exec -it $pod --namespace=$NAMESPACE -- /bin/bash
    fi
done


