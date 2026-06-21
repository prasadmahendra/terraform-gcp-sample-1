#!/bin/bash
set -eufx

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="9.0"  # Add this for H100
ldconfig -p | grep libcuda
ls -l /usr/local/cuda/lib64/ | grep libcuda
ls -l /usr/local/nvidia/lib64/ | grep libcuda
python3 -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('CUDA version:', torch.version.cuda); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"
python3 -c "import torch; print(torch.__version__)"
ls -lh "$2" || true
SOURCE_ROOT=$1
SSD_ROOT=$2
MODEL_FOLDER=$4
MODEL_NAME=$5
TENSOR_PARALLEL_SIZE=${6:-2}
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
# Account for CUDA graph memory during profiling to avoid OOM at graph capture
export VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1
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
        --gpu-memory-utilization 0.90 \
        --max-num-seqs 256 \
        --uvicorn-log-level warning \
        --tensor-parallel-size $TENSOR_PARALLEL_SIZE \
        --max-lora-rank 128 \
        --max-cpu-loras 256 \
        --max-loras 24 \
        --enable-lora \
        --enable-prefix-caching \
        --max-model-len 16000 \
        -O3 \
        --limit-mm-per-prompt '{"image": 1}' \
        --skip-mm-profiling \
        --max-num-batched-tokens 65528 \
        --structured-outputs-config '{"backend": "guidance"}' \
        --language-model-only \
        --speculative-config '{"method": "mtp", "num_speculative_tokens": 1}' \
        --mamba-cache-mode=align \
        --mamba-block-size=8 \
        --served-model-name $MODEL_NAME &

# Capture the process ID
VLLM_PID=$!

./start_vllm_post_process.sh $SSD_ROOT $MODEL_FOLDER

# Wait for VLLM to finish before exiting script
wait $VLLM_PID
