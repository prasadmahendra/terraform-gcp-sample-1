#!/bin/bash -e

#wget https://dl.google.com/cloudsql/cloud_sql_proxy.$(uname | tr '[:upper:]' '[:lower:]').amd64 -O cloud_sql_proxy
#chmod +x cloud_sql_proxy
#brew install cloud-sql-proxy

# An optional argument to specify the port.
PORT=5432

while getopts ":p:" opt; do
  case ${opt} in
    p )
      PORT=$OPTARG
      ;;
    \? )
      echo "Usage: cmd [-p port]"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

PSQL_CONN_NAME="spiffy-prod:us-central1:maindb-288a2197"
cloud-sql-proxy ${PSQL_CONN_NAME} -p ${PORT}
