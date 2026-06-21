## Inference services


### Testing Examples

If the services are up successfully then you should be able to do the following and get a response with the deployed models config:

```bash
curl https://inference-70b-chat.dev.spiffy.ai/v1/models | jq
curl https://inference-chat.dev.spiffy.ai/v1/models | jq
curl https://inference.dev.spiffy.ai/v1/models | jq

curl -vvv https://text-embed-default.dev.spiffy.ai/embed -X POST -d '{"inputs":"What is Deep Learning?"}' -H 'Content-Type: application/json'
curl -vvv https://text-embed-default.spiffy.ai/embed -X POST -d '{"inputs":"What is Deep Learning?"}' -H 'Content-Type: application/json'
```


Sample Results

```json
{
  "object": "list",
  "data": [
    {
      "id": "llama-2-70b-chat",
      "object": "model",
      "created": 1712950547,
      "owned_by": "vllm",
      "root": "llama-2-70b-chat",
      "parent": null,
      "permission": [
        {
          "id": "modelperm-625c473d2ad94de9b6ae4ebb4aff7397",
          "object": "model_permission",
          "created": 1712950547,
          "allow_create_engine": false,
          "allow_sampling": true,
          "allow_logprobs": true,
          "allow_search_indices": false,
          "allow_view": true,
          "allow_fine_tuning": false,
          "organization": "*",
          "group": null,
          "is_blocking": false
        }
      ]
    },
    {
      "id": "curated-ft-20231229",
      "object": "model",
      "created": 1712950547,
      "owned_by": "vllm",
      "root": "llama-2-70b-chat",
      "parent": null,
      "permission": [
        {
          "id": "modelperm-d4f5def2246e404890b33cb6610990f6",
          "object": "model_permission",
          "created": 1712950547,
          "allow_create_engine": false,
          "allow_sampling": true,
          "allow_logprobs": true,
          "allow_search_indices": false,
          "allow_view": true,
          "allow_fine_tuning": false,
          "organization": "*",
          "group": null,
          "is_blocking": false
        }
      ]
    }
  ]
}
```

## Test generation services


### Testing Examples

If the services are up successfully then you should be able to do the following and get a response with the deployed models config:

```bash
curl -vvv https://text-generation-default.dev.spiffy.ai/v1/models | jq
```

Sample Results

```json
{
  "object": "list",
  "data": [
    {
      "id": "Snowflake/snowflake-arctic-embed-m-v1.5",
      "object": "model",
      "created": 0,
      "owned_by": "Snowflake/snowflake-arctic-embed-m-v1.5"
    }
  ]
}
```