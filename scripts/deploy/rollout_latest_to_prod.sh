#!/bin/bash
set -e

SERVICE_GROUP=$1
PROMOTE_COMMIT_SHA=$2
REPOSITORY=$SERVICE_GROUP
if [ -z "$SERVICE_GROUP" ]; then
  echo "SERVICE_GROUP is not set. Exiting..."
  exit 1
fi

TRIGGER_NAMES_FILTER_CLOUDRUN="cloudrun-$SERVICE_GROUP"
TRIGGER_NAMES_FILTER_CLOUDRUN_JOB="cloudrunjob-$SERVICE_GROUP"
TRIGGER_NAMES_FILTER_GKE="gke-$SERVICE_GROUP"
TRIGGER_NAMES_FILTER_CUSTOM="custom-$SERVICE_GROUP"

# SERVICE_GROUP must be one of the following: pymono, webapp-admin, spiffy-react-components or envive-analytics-sdk"
if [ "$SERVICE_GROUP" != "pymono" ] && [ "$SERVICE_GROUP" != "webapp-admin" ] && [ "$SERVICE_GROUP" != "spiffy-react-components" ] && [ "$SERVICE_GROUP" != "shopify-app" ] && [ "$SERVICE_GROUP" != "envive-analytics-sdk" ]; then
  echo "SERVICE_GROUP must be one of the following: pymono, webapp-admin, shopify-app, spiffy-react-components or envive-analytics-sdk"
  exit 1
fi

PROD_TAG="prod"
DEV_TAG="latest"
MONO_REPO_ENTRYPOINT_ID=""
# Mono-repo overrides
if [ "$SERVICE_GROUP" == "pymono" ]; then
  MONO_REPO_ENTRYPOINT_ID="-svc-common"
  PROD_TAG="prod$MONO_REPO_ENTRYPOINT_ID"
  DEV_TAG="latest$MONO_REPO_ENTRYPOINT_ID"
  REPOSITORY="pymono"
fi
if [ "$SERVICE_GROUP" == "webapp-admin" ]; then
  MONO_REPO_ENTRYPOINT_ID="-admin"
  PROD_TAG="prod$MONO_REPO_ENTRYPOINT_ID"
  DEV_TAG="latest$MONO_REPO_ENTRYPOINT_ID"
  REPOSITORY="webapp-mono"
fi

PROMOTABLE_TAG="$PROMOTE_COMMIT_SHA$MONO_REPO_ENTRYPOINT_ID"

if [ -z "$PROMOTE_COMMIT_SHA" ]; then
  echo "PROMOTE_COMMIT_SHA is not set. Exiting..."
  exit 1
fi

# verify $PROMOTE_COMMIT_SHA is a valid commit sha
echo "Looking for [$PROMOTE_COMMIT_SHA] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
all_prod_tags=$(gcloud container images list-tags us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY --filter="tags:$PROMOTABLE_TAG*" --format="get(tags)" --limit=unlimited)
# if no tags are found, look for the latest tag
if [ -z "$all_prod_tags" ]; then
  echo "Unable to locate [$PROMOTABLE_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
  exit 1
fi

# pymono is a special case, we need to deploy all gke-* triggers
if [ "$SERVICE_GROUP" == "pymono" ]; then
  TRIGGER_NAMES_FILTER_GKE="gke-"
fi

# ---------------- Handling cloudrun services deploy triggers ----------------

# rollout all cloudrun services ...
if [ ! "$all_trigger_names_condensed" ]; then
  all_trigger_names=$(gcloud builds triggers list --region=us-central1 --project=spiffy-prod --filter="name:deploy-cloudrun-" --format="json" | jq '[.[].name]')
  all_trigger_names_condensed=$(echo $all_trigger_names | jq -r '.[] | select(test("'$TRIGGER_NAMES_FILTER_CLOUDRUN'"))')

  # if found all_trigger_names_condensed
  if [ "$all_trigger_names_condensed" ]; then
    echo "\nFound CloudRun triggers:\n"
    counter=1
    for name in $all_trigger_names_condensed; do
      echo "$counter. $all_trigger_names_condensed for SERVICE_GROUP=$SERVICE_GROUP\n"
      counter=$((counter+1))
    done
  fi
fi

# ---------------- Handling cloudrun-jobs deploy triggers ----------------

# rollout all cloudrun services ...
if [ ! "$all_trigger_names_condensed" ]; then
  all_trigger_names=$(gcloud builds triggers list --region=us-central1 --project=spiffy-prod --filter="name:deploy-cloudrunjob-" --format="json" | jq '[.[].name]')
  all_trigger_names_condensed=$(echo $all_trigger_names | jq -r '.[] | select(test("'$TRIGGER_NAMES_FILTER_CLOUDRUN_JOB'"))')

  # if found all_trigger_names_condensed
  if [ "$all_trigger_names_condensed" ]; then
    echo "\nFound CloudRun triggers:\n"
    counter=1
    for name in $all_trigger_names_condensed; do
      echo "$counter. $all_trigger_names_condensed for SERVICE_GROUP=$SERVICE_GROUP\n"
      counter=$((counter+1))
    done
  fi
fi

# ---------------- Handling GKE service deploy Triggers ----------------

# rollout all GKE services ...
if [ ! "$all_trigger_names_condensed" ]; then
  all_trigger_names=$(gcloud builds triggers list --region=us-central1 --project=spiffy-prod --filter="name:deploy-gke-" --format="json" | jq '[.[].name]')
  all_trigger_names_condensed=$(echo $all_trigger_names | jq -r '.[] | select(test("'$TRIGGER_NAMES_FILTER_GKE'"))')

  # if found all_trigger_names_condensed
  if [ "$all_trigger_names_condensed" ]; then
    echo "\nFound GKE triggers:\n"
    counter=1
    for name in $all_trigger_names_condensed; do
      echo "$counter. $all_trigger_names_condensed for SERVICE_GROUP=$SERVICE_GROUP\n"
      counter=$((counter+1))
    done
  fi
fi

# ---------------- Handling Custom Deploy Triggers ----------------

# rollout all custom deploy steps based packages/services ...
if [ ! "$all_trigger_names_condensed" ]; then
  all_trigger_names=$(gcloud builds triggers list --region=us-central1 --project=spiffy-prod --filter="name:deploy-custom-" --format="json" | jq '[.[].name]')
  all_trigger_names_condensed=$(echo $all_trigger_names | jq -r '.[] | select(test("'$TRIGGER_NAMES_FILTER_CUSTOM'"))')

  # if found all_trigger_names_condensed
  if [ "$all_trigger_names_condensed" ]; then
    echo "\nFound custom triggers:\n"
    counter=1
    for name in $all_trigger_names_condensed; do
      echo "$counter. $all_trigger_names_condensed for SERVICE_GROUP=$SERVICE_GROUP\n"
      counter=$((counter+1))
    done
  fi
fi

# ---------------- Run Found Triggers ----------------

# Extract each name and iterate
echo "Running triggers... $all_trigger_names_condensed"
results="["
for name in $all_trigger_names_condensed; do
  echo "Running $name with _PROMOTE_COMMIT_SHA=$PROMOTABLE_TAG"
  # if name starts with gke-llm-inference-service then skip it
  # inferences services follow a different deployment process
  # the script for those is under scripts/inference-service folder.
  if [[ $name == deploy-gke-llm-inference-service* ]]; then
    echo "************ Skipping $name..."
    continue
  fi
  if [[ $name == deploy-gke-llm-inference-svc* ]]; then
    echo "************ Skipping $name..."
    continue
  fi

  # Run the gcloud command and capture the output
  output=$(gcloud builds triggers run "$name" --substitutions=_PROMOTE_COMMIT_SHA=$PROMOTABLE_TAG --region=us-central1 --project=spiffy-prod --format="json")
  echo "Running [finished] $name"
  # Append the output to a new array variable
  if [ "$results" = "[" ]; then
    results="[$output"
  else
    results="$results, $output"
  fi
  # echo "Running [results ....] $name output=$results"
done

results="$results]"
echo "results=$results"

# ---------------- Wait trigger runs to complete ----------------


# status changes go from QUEUED -> WORKING -> SUCCESS
all_done=0
build_ids=$(echo $results | jq -r '.[].metadata.build.id')
while [ $all_done -ne 1 ]; do
  # Assume all builds are done unless we find one that isn't
  all_done=1

  for build_id in $build_ids; do
    # get build status
    status=$(gcloud builds describe $build_id --project=spiffy-prod --region=us-central1 --format="json" | jq -r '.status')
    echo "Build status for $build_id is $status"
    # Check if the status is not 'SUCCESS'
    if [ "$status" != "SUCCESS" ] && [ "$status" != "FAILURE" ]; then
      # Set all_done to 0 to continue the loop
      all_done=0
    fi
  done
  if [ $all_done -eq 0 ]; then
    echo "Not all builds are done, checking again in 2 seconds..."
    sleep 2
  fi
done