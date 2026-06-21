input_secret_name=$1

declare -a secret_array=($input_secret_name)
for i in "${secret_array[@]}"
do
    echo "copying secret $i=$input_secret_name"
    SECRET_NAME="${i}"
    SECRET_VALUE=$(gcloud secrets versions access "latest" --secret=${SECRET_NAME} --project=spiffy-ai-dev)
    rm -f secret_migrate_tmp
    echo $SECRET_VALUE > secret_migrate_tmp
    $(gcloud secrets create ${SECRET_NAME} --project spiffy-prod --data-file=secret_migrate_tmp)
done
rm -f secret_migrate_tmp