# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <project_id>"
  exit 1
fi

# Store the argument in a variable
PROJECT=$1
REGION=$2

# todo: login only if not already logged in
# gcloud auth application-default login


# for prod only
if [ "$PROJECT" == "spiffy-prod" ]; then
  echo "Setting up gke-default region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-default --region $REGION --project $PROJECT

  echo "Setting up gke-dws-primary-region region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-dws-primary-region --region $REGION --project $PROJECT

  echo "Setting up gke-us-west1 region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-us-west1 --region us-west1 --project $PROJECT
else
  echo "Setting up gke-default region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-default --region $REGION --project $PROJECT

  echo "Setting up gke-dws-secondary-region region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-dws-secondary-region --region us-central1 --project $PROJECT

  echo "Setting up gke-us-central1 region: $REGION project: $PROJECT"
  gcloud container clusters get-credentials gke-us-central1 --region us-central1 --project $PROJECT
fi