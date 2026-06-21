#!/bin/bash
set -eufox pipefail

PROJECT_ID=spiffy-prod
ORG_ID=spiffy
PACKAGE_ID=vllm-openai
PACKAGE_VERSION=v0.10.1.1_20260226
REGION=us-west1
REPO_URL=us-docker.pkg.dev

# Keep verifier logic in sync with pymono source of truth.
rm -rf ./rule_based_verifiers.py
cp "../../../pymono/spiffy/service/commerce_api/tools/evaluation/rule_based_verifiers.py" ./rule_based_verifiers.py

docker build -t ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} --platform linux/amd64 -f Dockerfile_gemma .

docker tag ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION}
docker push ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION}

docker tag ${ORG_ID}/${PACKAGE_ID}:${PACKAGE_VERSION} ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:latest
docker push ${REPO_URL}/${PROJECT_ID}/${ORG_ID}/${PACKAGE_ID}:latest
