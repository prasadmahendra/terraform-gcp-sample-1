#!/bin/bash
set -eufx

gcloud auth login --project=spiffy-prod
gcloud auth configure-docker us-docker.pkg.dev
docker build -t us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest -f docker/Dockerfile-codecov .
docker push us-docker.pkg.dev/spiffy-prod/spiffy/codecov:latest