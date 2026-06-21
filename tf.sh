#!/bin/bash -e

# Issue with MacOS/Arm64 and async preemption
# https://github.com/hashicorp/terraform-provider-aws/issues/39523
export GODEBUG=asyncpreemptoff=1
TF_ACTION=plan
TF_TARGET=()

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export TF_PLUGIN_CACHE_DIR=${DIR}/.terraform/plugin-cache
export KUBE_CONFIG_PATH=~/.kube/config

log() {
  if [ -n "$_system_type" ] && [ "$_system_type" != 'Darwin' ]; then
    echo -e "$(date --rfc-3339=s) $*"
  else
    echo -e "$(date +"%Y-%m-%dT %H:%M:%S%z") $*"
  fi
}

run_terraform() {
  log "Running: ${1}"
  eval "$1"
}

TF_VARS="-var-file=terraform.tfvars -var-file=secrets.tfvars"

setup_terraform() {
  case $TF_ENVIRONMENT in
    dev | dev-training | prod | prod-training)
      pushd "deployment"
      export TF_DATA_DIR="../environments/${TF_ENVIRONMENT}/.terraform"
      TF_VARS="-var-file=../environments/${TF_ENVIRONMENT}/terraform.tfvars -var-file=../environments/${TF_ENVIRONMENT}/secrets.tfvars"
      local STATE_FILE="${TF_DATA_DIR}/terraform.tfstate"
      export BACKEND_CONFIG="-backend-config=../environments/${TF_ENVIRONMENT}/backend.tfvars"
      ;;
    *)
      local STATE_FILE=".terraform/terraform.tfstate"
      pushd "${TF_ENVIRONMENT}"
      ;;
  esac

  if [ ! -e "${STATE_FILE}" ]; then
    echo "State file not found, running terraform init"
    run_terraform "terraform init ${BACKEND_CONFIG}"
  fi
}

show_help() {
  cat <<EOF
Usage: ${0##*/} [-hv] [-a init|plan|apply|destroy|import|state|upgrade|providers] -e environment-name [-t TARGET] <ARGS>

    -a          terraform action, defaults to plan
    -h          show this help message
    -e          environment to apply
    -t          optional -target - can be repeated for multiple targets

    When specifying '-a import' do not specify a target. i.e. "./tf -e dev -a import <resource> <resource identifier>"
EOF
}

## Main
log "Starting $0"
OPTIND=1
while getopts "a:e:t:h" opt; do
  case "$opt" in
  a)
    TF_ACTION=${OPTARG}
    ;;
  e)
    TF_ENVIRONMENT=${OPTARG}
    ;;
  t)
    TF_TARGET+=("${OPTARG}")
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

REGION=us-west1
PROJECT=spiffy-ai-dev
if [ "$TF_ENVIRONMENT" == "prod" ]; then
  REGION=us-central1
  PROJECT=spiffy-prod
fi

# use bash for linux
if [ "$(uname -s)" == "Linux" ]; then
  bash ./gcloud_login.sh $PROJECT $REGION
else
  sh ./gcloud_login.sh $PROJECT $REGION
fi

setup_terraform

case "$TF_ACTION" in
  init)
    # use apt-get for linux
    if [ "$(uname -s)" == "Linux" ]; then
      apt-get update && apt-get install -y gcloud kubectl terraform
    else
      gcloud components install gke-gcloud-auth-plugin
      gcloud components install kubectl
      gcloud components install terraform-tools
    fi
    run_terraform "terraform init ${BACKEND_CONFIG}"
    ;;
  state|force-unlock|taint|untaint|providers)
    run_terraform "terraform ${TF_ACTION} $*"
    ;;
  upgrade)
    unset TF_PLUGIN_CACHE_DIR
    rm -f .terraform.lock.hcl
    run_terraform "terraform init"
    run_terraform "terraform providers lock -platform=linux_amd64 -platform=darwin_amd64 -platform=darwin_arm64 "
    ;;
  *)
    if [ -n "${TF_TARGET}" ]; then
      for TARGET in "${TF_TARGET[@]}"; do
        TF_TARGETS="${TF_TARGETS} -target ${TARGET} "
      done
    fi
    run_terraform "terraform init ${BACKEND_CONFIG}"
    run_terraform "terraform ${TF_ACTION} ${TF_VARS} $TF_TARGETS $*"
    ;;
esac

popd

log "$0 finished!"

