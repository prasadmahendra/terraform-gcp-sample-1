#!/bin/bash
set -eufox pipefail

PROJECT_ID=spiffy-prod
ORG_ID=spiffy
PACKAGE_ID=vllm-openai
PACKAGE_VERSION=v0.21.0_20260616
REGION=us-west1
REPO_URL=us-docker.pkg.dev

# Keep verifier logic in sync with pymono source of truth.
rm -rf ./rule_based_verifiers.py
cp "../../../pymono/spiffy/service/commerce_api/tools/evaluation/rule_based_verifiers.py" ./rule_based_verifiers.py

docker build -t ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} --platform linux/amd64 -f Dockerfile_v021 .

docker tag ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION}
docker push ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION}

# Only uncomment and run the following lines to explicitly update the latest tag in production
# docker tag ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:latest
# docker push ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:latest
