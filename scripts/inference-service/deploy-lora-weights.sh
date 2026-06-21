#!/bin/bash -e

SCRIPT_ACTION=plan
SCRIPT_ENVIRONMENT=dev

log() {
  if [ -n "$_system_type" ] && [ "$_system_type" != 'Darwin' ]; then
    echo -e "$(date --rfc-3339=s) $*"
  else
    echo -e "$(date +"%Y-%m-%dT %H:%M:%S%z") $*"
  fi
}

show_help() {
  cat <<EOF
Usage: ${0##*/} [-hv] [-a deploy-lora] -e environment-name -s source_bucket_path -d dest_bucket_name <ARGS>

    -a          action, defaults to deploy-lora
    -m          model size, one of 70b or 8b
    -s          source bucket name and path (ex: depending on -a must point to valid lora weights folder. eg: gs://spiffy-partners/chord/carawayhome/models/ft-caraway-20240515/ep3step250/)
    -d          destination bucket name (eg: gs://spiffy-llm-inference-service-dev). note just the bucket name only!
    -c          checkpoint version (eg: ft-caraway-20240515)
    -h          show this help message
    -e          environment to apply
EOF
}


## Main
log "Starting $0"
OPTIND=1
while getopts "a:e:m:s:d:p:c:g:h" opt; do
  case "$opt" in
  a)
    SCRIPT_ACTION=${OPTARG}
    ;;
  e)
    SCRIPT_ENVIRONMENT=${OPTARG}
    ;;
  m)
    MODEL_SIZE+=("${OPTARG}")
    ;;
  s)
    SOURCE_PATH+=("${OPTARG}")
    ;;
  d)
    DEST_BUCKET_NAME+=("${OPTARG}")
    ;;
  c)
    CHECKPOINT_VERSION+=("${OPTARG}")
    ;;
  h)
    show_help
    exit 0
    ;;
  '?')
    show_help >&2
    exit 1
    ;;
  esac
done
shift "$((OPTIND - 1))"

# if env is dev then transfer job name is ...
if [ "$SCRIPT_ENVIRONMENT" == "dev" ]; then
  GCS_TO_FILESTORE_TRANSFER_JOB_NAME_1=OPI2151768790479942588
  GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2=OPI6806133107514597845
  GCP_TRIGGERS_REGION=us-west1
  GCP_GKE_CLUSTER_REGION=us-central1
  GKE_SERVICE_NAME=llm-inference-service-llama-3-${MODEL_SIZE}-usc1
else
  GCS_TO_FILESTORE_TRANSFER_JOB_NAME_1=OPI3586427129836030683
  GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2=OPI11211260541415498274
  GCP_TRIGGERS_REGION=us-central1
  GCP_GKE_CLUSTER_REGION=us-central1
  if [ "$MODEL_SIZE" == "70b" ]; then
    GKE_SERVICE_NAME=llm-inference-service-llama-3-70b
  else
    GKE_SERVICE_NAME=llm-inference-svc-llama-3-${MODEL_SIZE}-usw1
  fi
fi



case "$SCRIPT_ACTION" in
  deploy-lora)
    log "Deploying lora weights"
    log "  SOURCE_PATH: ${SOURCE_PATH}"
    log "  DEST_BUCKET_NAME: ${DEST_BUCKET_NAME}"
    all_source_objects=($(gsutil ls "${SOURCE_PATH}*"))
    GCP_PROJECT_ID=spiffy-ai-${SCRIPT_ENVIRONMENT}
    # if SCRIPT_ENVIRONMENT == dev
    if [ "$SCRIPT_ENVIRONMENT" == "dev" ]; then
      GCP_PROJECT_ID=spiffy-ai-dev
    else
      GCP_PROJECT_ID=spiffy-${SCRIPT_ENVIRONMENT}
    fi
    log "  GCP_PROJECT_ID: ${GCP_PROJECT_ID}"

    found_valid_files_count=0
    for element in "${all_source_objects[@]}"
    do
        if [[ $element == *README.md ]] || \
           [[ $element == *adapter_config.json ]] || \
           [[ $element == *adapter_model.safetensors ]] || \
           [[ $element == *adapter_model.bin ]]; then
            log "Checking $element ..."
            found_valid_files_count=$((found_valid_files_count+1))
        fi
    done

    if [ "$found_valid_files_count" -ne 3 ]; then
        log "No valid files found in $SOURCE_PATH $all_source_objects"
        exit 1
    fi

    MODEL_NAME=llama-3.1-${MODEL_SIZE}-instruct
    DEST_PATH="${DEST_BUCKET_NAME}/${MODEL_NAME}/lora/${CHECKPOINT_VERSION}"
    log "  DEST_PATH: ${DEST_PATH}"
    gsutil ls "${DEST_PATH}" || true
    if [ $? -eq 0 ]; then
      log "Destination ${DEST_PATH} exists."
    else
      log "Missing destination ${DEST_PATH} !!!"
    fi

    # Copy all from source to destination
    DEST_PATH_COMPLETE="${DEST_PATH}"
    log "Copy all from ${SOURCE_PATH} -> ${DEST_PATH_COMPLETE}"
    gsutil cp -r "${SOURCE_PATH}/*" "${DEST_PATH_COMPLETE}"


    # # Transferring to Filestore is not needed anymore. The VLLM server will always download the weights from GCS.

    # # Run transfer job (sync GCS -> Filestore)
    # log "Run transfer job ${GCS_TO_FILESTORE_TRANSFER_JOB_NAME_1} from ${DEST_PATH_COMPLETE} to filestore"
    # gcloud transfer jobs run ${GCS_TO_FILESTORE_TRANSFER_JOB_NAME_1} --project=${GCP_PROJECT_ID}

    # # Wait till the transfer job is finished ...
    # while [[ ! -z $(gcloud transfer operations list --operation-statuses=QUEUED,IN_PROGRESS --project=${GCP_PROJECT_ID} --format="value(name)") ]]
    # do
    #   log "GCS -> Filestore transfer job is still running ..."
    #   sleep 2
    # done

    # # if GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2 is not empty then run the transfer job
    # if [ ! -z "$GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2" ]; then
    #   log "Run transfer job ${GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2} from ${DEST_PATH_COMPLETE} to filestore"
    #   gcloud transfer jobs run ${GCS_TO_FILESTORE_TRANSFER_JOB_NAME_2} --project=${GCP_PROJECT_ID}
    # fi

    # # Wait till the transfer job is finished ...
    # while [[ ! -z $(gcloud transfer operations list --operation-statuses=QUEUED,IN_PROGRESS --project=${GCP_PROJECT_ID} --format="value(name)") ]]
    # do
    #   log "GCS -> Filestore transfer job is still running ..."
    #   sleep 2
    # done
    # log "GCS -> Filestore transfer job finished ..."

    # MP: This is the old method for deploying weights that restarts the service.
    GKE_TRIGGER_NAME="deploy-gke-${GKE_SERVICE_NAME}-svc"
    log "Update GKE service = ${GKE_TRIGGER_NAME}"
    gcloud builds triggers run ${GKE_TRIGGER_NAME} --project=${GCP_PROJECT_ID} --region=${GCP_TRIGGERS_REGION}

    # Run the script to individually ping the vllm pods to load the weights
    #SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    #log "Run ${SCRIPT_DIR}/broadcast_vllm_new_lora_weight_available.sh ${SCRIPT_ENVIRONMENT} ${MODEL_SIZE} ${CHECKPOINT_VERSION}"
    #${SCRIPT_DIR}/broadcast_vllm_new_lora_weight_available.sh ${SCRIPT_ENVIRONMENT} ${MODEL_SIZE} ${CHECKPOINT_VERSION}

    ;;
  *)
    show_help >&2
    exit 1
    ;;
esac
log "$0 finished!"
