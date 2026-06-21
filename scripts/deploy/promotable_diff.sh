#!/bin/bash
set -e

SERVICE_GROUP=$1
SWITCH_TO_MAIN_BY_DEFAULT=${2:-true}
REPOSITORY=$SERVICE_GROUP
if [ -z "$SERVICE_GROUP" ]; then
  echo "SERVICE_GROUP is not set. Exiting..."
  exit 1
fi

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

# git checkout and assert we are on "main" branch
if [ "$SWITCH_TO_MAIN_BY_DEFAULT" = true ] ; then
  echo "Switching to main branch and pulling latest changes..."
  git checkout main
  git pull
else
  echo "Not switching branches. Using current branch: $(git branch --show-current)"
fi

# get all the other tags on the same image, one of them is the git commit sha
echo "Looking for [$PROD_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
all_prod_tags=$(gcloud container images list-tags us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY --filter="tags=$PROD_TAG" --format="get(tags)" --limit=unlimited)

echo "Looking for [$DEV_TAG] tags on us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY"
all_dev_tags=$(gcloud container images list-tags us-docker.pkg.dev/spiffy-prod/spiffy/$REPOSITORY --filter="tags=$DEV_TAG" --format="get(tags)" --limit=unlimited)

echo "all_prod_tags: $all_prod_tags"
echo "all_dev_tags: $all_dev_tags"

# all_tags is a string like this: fa10bd6e6372697e300fc703470a8d4cb59c0780-svc-common;latest-202405.231835.44-svc-common;latest-svc-common
# extract the tag that matches patterns like fa10bd6e6372697e300fc703470a8d4cb59c0780-svc-common

dev_git_commit_sha=$(echo "$all_dev_tags" | grep -oE "[a-f0-9]{40}($MONO_REPO_ENTRYPOINT_ID)?")
dev_git_commit_sha=$(echo "$dev_git_commit_sha" | grep -oE '[a-f0-9]{40}')
if [ -n "$all_dev_tags" ]; then
  echo "Dev tags found=$all_dev_tags. Continuing..."
  dev_git_commit_sha=$(echo "$all_dev_tags" | grep -oE "[a-f0-9]{40}($MONO_REPO_ENTRYPOINT_ID)?")

  #
  # Why is head -n1 used here?
  #
  # If there are multiple dev tags matching the pattern, we will use the first one
  # This happens when we have a mono repo that gets built for multiple services.
  # (The same container image may be output for different commits)
  #
  # example: dev_git_commit_sha=4821e46d38f940ee315866ab1df8bdcccca17bb1
  #           52fde645162a9f6ff096c70dd3d8f2bbc85f7861
  #           a2cc5cf0d1a7008ac7951d0495a5c7c1d9ff68e8
  # then take "4821e46d38f940ee315866ab1df8bdcccca17bb1" as the dev_git_commit_sha

  dev_git_commit_sha=$(echo "$dev_git_commit_sha" | grep -oE '[a-f0-9]{40}' | head -n1)
  echo "Dev commit sha found. Continuing..."
else
  echo "Unable to locate dev tags. Exiting..."
  exit 1
fi

if [ -n "$all_prod_tags" ]; then
  echo "Prod tags found=$all_prod_tags. Continuing..."
  prod_git_commit_sha=$(echo "$all_prod_tags" | grep -oE "[a-f0-9]{40}($MONO_REPO_ENTRYPOINT_ID)?")

  #
  # Why is head -n1 used here?
  #
  # If there are multiple prod tags matching the pattern, we will use the first one
  # This happens when we have a mono repo that gets built for multiple services.
  # (The same container image may be output for different commits)
  #
  # example: prod_git_commit_sha=4821e46d38f940ee315866ab1df8bdcccca17bb1
  #           52fde645162a9f6ff096c70dd3d8f2bbc85f7861
  #           a2cc5cf0d1a7008ac7951d0495a5c7c1d9ff68e8
  # then take "4821e46d38f940ee315866ab1df8bdcccca17bb1" as the prod_git_commit_sha

  prod_git_commit_sha=$(echo "$prod_git_commit_sha" | grep -oE '[a-f0-9]{40}' | head -n1)
  echo "Prod commit sha found. Continuing..."
else
  echo "Unable to locate prod_git_commit_sha. Brand new service?\n"
  release_note="
  ==============
  [$SERVICE_GROUP] Release Notes:
  ==============
  Current PROD version: NONE
  Current DEV version: $dev_git_commit_sha

  ==============
  "
  # Print the release note
  echo "$release_note"
  exit 1
fi

# Print the matching tag
echo "=================================================="
echo "prod_git_commit_sha=$prod_git_commit_sha"
echo "dev_git_commit_sha=$dev_git_commit_sha"
echo "=================================================="

commit_list=$(git log --pretty=format:"%h:  %s%n    [by %an]%n" "$prod_git_commit_sha".."$dev_git_commit_sha")

# Pretty print the git diff for a release note
release_note="
==============
[$SERVICE_GROUP] Release Notes:
==============
Current PROD version: $prod_git_commit_sha
Current DEV version: $dev_git_commit_sha

$commit_list

==============
"

# Print the release note
echo "$release_note"
