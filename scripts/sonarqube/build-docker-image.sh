#!/bin/bash -e

rm -Rf cloud-builders-community
git clone git@github.com:GoogleCloudPlatform/cloud-builders-community.git
cp my_cloudbuild.yaml cloud-builders-community/sonarqube
cd cloud-builders-community/sonarqube


gcloud builds submit . --config=my_cloudbuild.yaml --project=spiffy-prod
