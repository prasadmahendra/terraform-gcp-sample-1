#!/bin/bash -e
gcloud_auth_list=$(gcloud auth list)

regex="(.*\*[ ]+)([a-zA-Z0-9_\.]+@[a-zA-Z0-9_\.]+)"
set active_user=""

if [[ "${gcloud_auth_list[@]}" =~ $regex ]]; then
    active_user="${BASH_REMATCH[2]}"
else
    echo "No match found. in => ${gcloud_auth_list[@]}"
fi

if [ -z "$active_user" ]; then
    echo "No active user found"
    gcloud auth application-default login
else
    echo "GCP active user is: $active_user"
fi


