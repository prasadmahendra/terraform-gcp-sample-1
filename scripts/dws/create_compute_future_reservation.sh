#!/bin/bash

PROJECT_ID="spiffy-prod"
VM_COUNT=1
#REGION="us-west1-a"
REGION="us-central1-c"
#MACHINE_TYPE="a3-ultragpu-8g"
MACHINE_TYPE="a3-highgpu-8g"

# RFC3339 formatted date
START_TIME=$(date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ")
END_TIME=$(date -u -v+31d +"%Y-%m-%dT%H:%M:%SZ")

echo "Start Time: $START_TIME"
echo "End Time:   $END_TIME"

# https://cloud.google.com/blog/products/compute/introducing-dynamic-workload-scheduler
gcloud beta compute future-reservations create inf-surge-$MACHINE_TYPE-block-$REGION \
  --zone=$REGION \
  --machine-type=$MACHINE_TYPE \
  --start-time="$START_TIME" \
  --end-time="$END_TIME" \
  --auto-delete-auto-created-reservations \
  --require-specific-reservation \
  --total-count="$VM_COUNT" \
  --description="Future reservation for inference surge calendar block" \
  --name-prefix="vllm" \
  --project="$PROJECT_ID"
