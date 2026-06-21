#!/bin/bash
set -eufx

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
ldconfig -p | grep libcuda
ls -l /usr/local/cuda/lib64/ | grep libcuda
ls -l /usr/local/nvidia/lib64/ | grep libcuda
python3 -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('CUDA version:', torch.version.cuda); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"
python3 -c "import torch; print(torch.__version__)"
ls -lh /data/ssd/
SOURCE_ROOT=$1
SSD_ROOT=$2
MODEL_FOLDER=$4
if rclone check ${SOURCE_ROOT}/${MODEL_FOLDER} ${SSD_ROOT}/${MODEL_FOLDER} --one-way --size-only; then
    echo "Rclone check passed"
else
    echo "Rclone check failed"
    RANDOM_DIR=$(mktemp -d "${SSD_ROOT}/copy-XXXXXXXX")
    gsutil -m cp -r -n ${SOURCE_ROOT}/${MODEL_FOLDER} $RANDOM_DIR
    rm -rf ${SSD_ROOT}/${MODEL_FOLDER}
    mv -n ${RANDOM_DIR}/${MODEL_FOLDER}/ ${SSD_ROOT}/${MODEL_FOLDER}/
    rm -rf ${RANDOM_DIR}
fi

echo "Starting VLLM server ...\n"

# file path for lora modules from args
models_base_path="${SSD_ROOT}/${MODEL_FOLDER}/base/" # e.g. /root/model/base
cuda_visible_devices=$3 # e.g. 0,1,2,3

echo "models_base_path: $models_base_path\n"
echo "cuda_visible_devices: $cuda_visible_devices\n"

export CUDA_VISIBLE_DEVICES=$cuda_visible_devices
export VLLM_ALLOW_RUNTIME_LORA_UPDATING=True
export VLLM_PLUGINS="gcs_bucket_resolver"
export GCS_BUCKET_LORA_RESOLVER_CACHE_DIR="${SOURCE_ROOT}/${MODEL_FOLDER}/lora/"
export SSD_BUCKET_LORA_RESOLVER_CACHE_DIR="${SSD_ROOT}/${MODEL_FOLDER}/lora/"
pip3 install -e custom_lora_plugin

# Debug: Check if LoRA directory exists and has content
echo "LoRA directory contents:"
ls -la "${SSD_ROOT}/${MODEL_FOLDER}/lora/" || echo "LoRA directory not found"

python3 start_vllm.py \
        --model $models_base_path \
        --port 8002 \
        --host 0.0.0.0 \
        --gpu-memory-utilization 0.95 \
        --max-num-seqs 16 \
        --uvicorn-log-level warning \
        --max-lora-rank 32 \
        --max-cpu-loras 256 \
        --max-loras 24 \
        --enable-lora \
        --swap-space 50 \
        --enable-prefix-caching \
        --max-model-len 16000 \
        --max-num-batched-tokens 65528 \
        --structured-outputs-config '{"backend": "guidance"}' \
        --served-model-name llama-3.1-8b-instruct &

# Capture the process ID
VLLM_PID=$!

./start_vllm_post_process.sh $SSD_ROOT $MODEL_FOLDER

# Wait for VLLM to finish before exiting script
wait $VLLM_PID
