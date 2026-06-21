

# Have num_models number of different LoRA models
#   - Each model has a random system prompt of random length between 800 and 2000 tokens
#
# Make batch of batch_size number of requests where batch size is large, e.g. 1000 or 10000
#   - Each request has a random user prompt of length between 1000 and 14000 from a random model
#   - Each request has a random output length of size 50 - 300 tokens
#
# Run request in batch with num_workers different workers and check to see:
#   - Average sequence length
#   - How many workers can we have before we start throwing errors? should be about 64K / average sequence length
#   - average number of requests 


def go(batch_size: int = 500, num_workers: int = 8):
    from interactive_debug_vllm import get_vllm_client, model_size_to_url
    import requests
    from transformers import AutoTokenizer
    import random
    import torch
    import os

    url = model_size_to_url("70b")
    vllm_client = get_vllm_client(url, api_key="sk-")

    r = requests.get(f"{url}/models")
    available_models = [m["id"] for m in r.json()["data"] if m["id"].startswith("ft-")]
    base_model_info = [m for m in r.json()["data"] if m["id"] == "llama-3.1-70b-instruct"]
    base_model_path = base_model_info[0]["root"]

    print(f"Available models: {available_models}")
    print(f"Number of models: {len(available_models)}")

    tokenizer = AutoTokenizer.from_pretrained(base_model_path)

    def _rand_string(_num_tokens: int) -> str:
        _low = 5
        _high = tokenizer.vocab_size - 1
        _token_ids = torch.randint(low=_low, high=_high, size=(_num_tokens, ))
        return tokenizer.decode(_token_ids)

    # make the system prompts
    system_prompts = {}
    for model in available_models:
        random_prompt = _rand_string(random.randint(800, 2000))
        num_tokens_random_prompt = len(tokenizer.encode(random_prompt))
        system_prompts[model] = [random_prompt, num_tokens_random_prompt]

    # make the batch
    batch = []
    max_seq_len = 14000
    for i in range(batch_size):
        model = random.choice(available_models)
        output_length = random.randint(50, 300)
        user_prompt = _rand_string(random.randint(1000, max_seq_len - output_length - system_prompts[model][1]))
        messages = [
            {
                "role": "system",
                "content": system_prompts[model][0]
            },
            {
                "role": "user",
                "content": user_prompt,
            }
        ]
        batch.append(
            {
                "id": i,
                "messages": messages,
                "kwargs": {
                    "model": model,
                    "max_tokens": output_length,
                },
            }
        )

    num_tokens_in_batch = sum(
        len(tokenizer.apply_chat_template(ele["messages"]))
        for ele in batch
    )
    average_seq_len = num_tokens_in_batch / batch_size
    print(f"Number of tokens in batch: {num_tokens_in_batch}")
    print(f"Average sequence length: {average_seq_len}")
    print(f"Expected number of workers to saturate max sequence length: {64_000 / average_seq_len}")
    print(f"Number of workers: {num_workers}")

    import time
    start_time = time.time()
    responses = vllm_client.get_batch_chat_responses(batch, num_workers=num_workers)
    end_time = time.time()

go(250, num_workers=8)