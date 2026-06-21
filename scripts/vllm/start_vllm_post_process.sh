#!/bin/bash
set -eufx

SSD_ROOT=$1
MODEL_FOLDER=$2

# Wait until port 8002 is accepting connections
echo "Waiting for VLLM to be ready..."
while ! nc -zv localhost 8002; do
    echo "VLLM is not ready yet. Waiting..."
    sleep 15
done

echo "VLLM is up. Continuing..."
ls -la "${SSD_ROOT}/${MODEL_FOLDER}/lora/" || echo "LoRA directory not found"
sleep 5

# Test all LoRAs with curl requests
echo "Testing all LoRAs..."
LORA_DIR="${SSD_ROOT}/${MODEL_FOLDER}/lora/"
if [ -d "$LORA_DIR" ]; then
    lora_names=$(find "$LORA_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    for lora_name in $lora_names; do
        echo "Testing LoRA: $lora_name"
        curl -X POST http://localhost:8002/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$lora_name\",
                    \"messages\": [
                        {\"role\": \"user\", \"content\": \"Hello, how are you?\"}
                    ],
                    \"max_tokens\": 2,
                    \"temperature\": 0.0
                }" \
                --max-time 30 \
                --silent \
                --show-error
            
            echo -e "\n---\n"
    done
else
    echo "LoRA directory not found: $LORA_DIR"
fi

echo "Testing all LoRAs completed"