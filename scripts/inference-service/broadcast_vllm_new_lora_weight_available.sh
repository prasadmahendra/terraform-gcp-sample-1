#/bin/bash -e
#
# ./broad_cast_vllm_new_lora_weight_available dev 70b ft-jordan-craig-20250205

ENV=$1
MODELSIZE=$2
MODELNAME=$3

#ENV=dev
#MODELSIZE=70b
#MODELNAME=ft-jordan-craig-20250205

if [ "$ENV" == "dev" ]; then
    PROJECT=spiffy-ai-dev
    NAMESPACE=apps-llm-ns

    REGION=us-central1
    CLUSTER_NAME=gke-us-central1

elif [ "$ENV" == "prod" ]; then
    PROJECT=spiffy-prod
    NAMESPACE=apps-llm-ns

    if [ "$MODELSIZE" == "70b" ]; then
        # 70B
        REGION=us-west1
        CLUSTER_NAME=gke-us-west1
    elif [ "$MODELSIZE" == "8b" ]; then
        # 8B
        REGION=us-central1
        CLUSTER_NAME=gke-default
    else
        echo "MODELSIZE must be 70b or 8b"
        exit 1
    fi
else
    echo "ENV must be dev or prod"
    exit 1
fi

LORA_DIR=/data/llm-service-highperf/llama-3.1-${MODELSIZE}-instruct/lora/${MODELNAME}
JSONPAYLOAD='{"lora_name": "'$MODELNAME'", "lora_path": "'$LORA_DIR'"}'


# Get creds
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT

# Get running pods
kubectl get pods --namespace=$NAMESPACE

# Loop over pods and send load lora request
kubectl get pods --namespace=$NAMESPACE | grep "\-${MODELSIZE}\-" | cut -f 1 -d " " | while IFS= read -r pod_name; do
    echo "Loading weights on Pod: $pod_name"

    kubectl exec --namespace $NAMESPACE $pod_name -- curl -X POST http://localhost:8002/v1/load_lora_adapter \
        -H "Content-Type: application/json" \
        -d "$JSONPAYLOAD"

    # Check last status code
    if [ $? -ne 0 ]; then
        echo "Failed to load weights on Pod: $pod_name"
        exit 1
    fi

    echo "\n"
    echo "--------------------------------------------------------"
done

# kubectl exec -it --namespace $NAMESPACE $pod_name -- /bin/bash