This example below does the following:
1. Copy the `ft-caraway-20240515` checkpoint model files from the staging (training) bucket `spiffy-partners` to the deployed service bucket `spiffy-llm-inference-service-dev` (sub paths under this bucket will be correctly placed by the script)
2. Runs the NFS transfer agents to stage the files from `spiffy-llm-inference-service-dev` on to the inference service compute nodes to make it available to them
3. Restart the inference service `llm-inference-service-llama-3-70b` so the new model files are loaded by the inference vllm server


```bash
bash scripts/inference-service/deploy-lora-weights.sh \
        -a deploy-lora \
        -m llama-3-70b-instruct \
        -s gs://spiffy-partners/chord/carawayhome/models/ft-caraway-20240515/ep3step250 \
        -d gs://spiffy-llm-inference-service-dev \
        -c ft-caraway-20240515 \
        -g llm-inference-service-llama-3-70b \
        -e dev
```

And a templated example for different environments:
```bash
PARTNER=curated
MODELNAME=ft-curated-20240515
CHECKPOINT=ep2step150
ENV=prod

bash scripts/inference-service/deploy-lora-weights.sh \
         -a deploy-lora \
         -m llama-3-70b-instruct \
         -s gs://spiffy-partners/${PARTNER}/models/${MODELNAME}/${CHECKPOINT} \
         -d gs://spiffy-llm-inference-service-${ENV} \
         -c $MODELNAME \
         -g llm-inference-service-llama-3-70b \
         -e $ENV
```
