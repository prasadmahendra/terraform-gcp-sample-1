#!/bin/bash
#
# ./model_train_job_create.sh supergoop 20250123
#
#
# This will create a job with 2 hour limit and sleep entrypoint:
# ./model_train_job_create.sh debug yyyymmdd
#
# Modify debug_job.yaml with the image, machine type, and number of GPUs needed.
# See README.md for instructions about how to connect to the running container after the machine has started.
#

org=$1
date=$2

# For env=dev
REGION=us-central1
PROJECT=spiffy-ai-dev
CLUSTER_NAME=gke-dws-secondary-region
NAMESPACE=apps-services-ns

gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT

if [ "$org" == "debug" ]; then
    echo "Creating a debugging job!"
    kubectl apply -f debug_job.yaml --namespace=$NAMESPACE
    exit 0
fi

# fill the template with the job name
uid=`uuidgen | tr A-Z a-z | cut -c1-8`
job_name=ft-$org-$date-$uid

python fill_training_job_template.py --org $org --date $date --job-name $job_name
cat temp_training_job.yaml
echo ""

# https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_job/
#kubectl create job $job_name --from temp_training_job.yaml --namespace=$NAMESPACE
kubectl apply -f temp_training_job.yaml --namespace=$NAMESPACE

#rm temp_training_job.yaml
