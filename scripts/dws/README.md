
Build docker file in `scli` repo

```
gcloud auth application-default login
gcloud auth login

cd ~/git/scli
./bin/build_docker_sft.sh
```


## Using DWS

See: https://cloud.google.com/blog/products/compute/introducing-dynamic-workload-scheduler
See: https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest

In the dynamic work scheduler, the entry point is a script that sets hyperparameters and runs training.  Storage is mounted as a file system from the `gs://spiffy-train-dev` bucket.

To create a training job, use
```
./model_train_job_create.sh org_short_name yymmdd
```

Checking job status
```
./model_train_job_status.sh dev  job_id
```

### Debugging GPU work loads with DWS

An easy way to debug VLLM and model training jobs is to create a job with the same docker image and storage/networking/etc environment as the regular job, but set the entrypoint to `sleep`.  Submit the job, wait a few minutes for it to start, then connect to the running container with a shell.

```
./model_train_job_create.sh debug yyyymmdd

# Wait for it to start. Check console or this command to find the pod name.
kubectl get pods --namespace=apps-services-ns

# Once running, run a command like this with the pod name
kubectl exec -it --namespace=apps-services-ns $POD_NAME -- /bin/bash
```

For VLLM specifically, this command will start the 70B model on 2xA100, with two fine tuned models:
```
./start_vllm_a100.sh /spiffy-train-dev/base-models/llama-3.1-70b-instruct /spiffy-train-dev/trained-models/supergoop/data_generation_20241119/ 0,1
```

Logs for a particular pod, associated with a job: https://console.cloud.google.com/logs/query;query=resource.labels.namespace_name%3D%22apps-services-ns%22%0Aresource.type%3D%22k8s_pod%22%0Aresource.labels.pod_name%3D%22ft-supergoop-20250123-7557d7d8-47a0-4d86-9492-04384fd447329x9md%22;cursorTimestamp=2025-01-27T20:35:49Z;duration=PT1H?project=spiffy-ai-dev

List of all jobs: https://console.cloud.google.com/kubernetes/workload/overview?project=spiffy-ai-dev


#### Networking
Gateway API: https://kubernetes.io/docs/concepts/services-networking/gateway/

