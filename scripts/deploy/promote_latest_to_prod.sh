#!/bin/bash
set -e

SERVICE_GROUP=$1
PROMOTE_COMMIT_SHA=$2
REPOSITORY=$SERVICE_GROUP
if [ -z "$SERVICE_GROUP" ]; then
  echo "SERVICE_GROUP is not set. Exiting..."
  exit 1
fi

# SERVICE_GROUP must be one of the following: pymono, webapp-mono, spiffy-react-components or envive-analytics-sdk"
if [ "$SERVICE_GROUP" != "pymono" ] && [ "$SERVICE_GROUP" != "webapp-admin" ] && [ "$SERVICE_GROUP" != "spiffy-react-components" ] && [ "$SERVICE_GROUP" != "shopify-app" ] && [ "$SERVICE_GROUP" != "envive-analytics-sdk" ]; then
  echo "SERVICE_GROUP must be one of the following: pymono, webapp-admin, shopify-app, spiffy-react-components or envive-analytics-sdk"
  exit 1
fi

if [ -z "$PROMOTE_COMMIT_SHA" ]; then
  echo "PROMOTE_COMMIT_SHA is not set. Exiting..."
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

all_trigger_names=$(gcloud builds triggers list --region=us-central1 --project=spiffy-prod --filter="name:promote-" --format="json" | jq '[.[].name]')
all_trigger_names_condensed=$(echo $all_trigger_names | jq -r '.[] | select(test("promote-'$REPOSITORY$MONO_REPO_ENTRYPOINT_ID'"))')

echo "\nFound triggers:\n$all_trigger_names_condensed for SERVICE_GROUP=$SERVICE_GROUP\n\n"

echo "Looking for [$PROMOTABLE_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
all_prod_tags=$(gcloud container images list-tags us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY --filter="tags:$PROMOTABLE_TAG*" --format="get(tags)" --limit=unlimited)
# if no tags are found, look for the latest tag
if [ -z "$all_prod_tags" ]; then
  echo "Unable to locate [$PROMOTABLE_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
  exit 1
fi

echo "Found [$PROMOTABLE_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY --> $all_prod_tags"
matching_tags_array=()
for tag in $all_prod_tags; do
  # split the tag into an array by ;
  IFS=';' read -ra tag_parts <<< "$tag"
  for part in "${tag_parts[@]}"; do
    echo "Part: $part"
    # if the part contains the commit sha, then we have the correct tag
    if [[ $part == *"$PROMOTABLE_TAG"* ]]; then
      echo "Found matching tag: $part"
      # put $part in to matching_tags_array
      matching_tags_array+=("$part")
    fi
  done
done

# if no tags are found, exit
if [ ${#matching_tags_array[@]} -eq 0 ]; then
  echo "Unable to locate matching tags for [$PROMOTABLE_TAG] on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
  exit 1
fi

# print all matching tags
echo "\nMatching tags:"
counter=1
for matching_tag in "${matching_tags_array[@]}"; do
  echo "$counter. $matching_tag"
  counter=$((counter+1))
done

# if matching_tags_array size is > 1 then exit
if [ ${#matching_tags_array[@]} -gt 1 ]; then
  echo "ERROR: Found multiple matching tags for [$PROMOTABLE_TAG] on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
  exit 1
fi
# get the first element of the array
matching_tag=${matching_tags_array[0]}
# Sanity check: assert that the matching tag contains $PROMOTABLE_TAG
if [[ $matching_tag != *"$PROMOTABLE_TAG"* ]]; then
  echo "ERROR: Matching tag does not contain $PROMOTABLE_TAG"
  exit 1
fi
# set $PROMOTABLE_TAG to the matching tag
PROMOTE_COMMIT_SHA=$matching_tag
echo "\nNow promoting PROMOTE_COMMIT_SHA=$PROMOTABLE_TAG to prod $all_trigger_names_condensed ..."

# Extract each name and iterate
build_ids=""
for name in $all_trigger_names_condensed; do
  echo "Running $name..."
  # Run the gcloud command and extract build ID directly
  build_id=$(gcloud builds triggers run "$name" --substitutions=_PROMOTE_COMMIT_SHA="${PROMOTABLE_TAG}" --region=us-central1 --project=spiffy-prod --format="value(metadata.build.id)")
  echo "Running [finished] $name"
  build_ids="$build_ids $build_id"
done

# status changes go from QUEUED -> WORKING -> SUCCESS
all_done=0
while [ $all_done -ne 1 ]; do
  # Assume all builds are done unless we find one that isn't
  all_done=1

  for build_id in $build_ids; do
    # get build status
    status=$(gcloud builds describe $build_id --project=spiffy-prod --region=us-central1 --format="value(status)")
    echo "Build status for $build_id is $status"
    # Check if the status is not 'SUCCESS' or 'FAILURE'
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