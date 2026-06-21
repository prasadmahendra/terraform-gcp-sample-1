#!/bin/bash
# Generic single-GPU vLLM launcher for a dense model pinned to ONE H100 MIG slice
# (3g.40gb => ~40GB VRAM + 3/7 of the SMs). Two of these Pods co-locate on a single
# physical H100 partitioned via MIG (node pool gke-default-a3-highgpu-1g-mig-pool),
# letting two independent models share one card for better GPU utilization.
#
# Args:
#   $1 source_root           e.g. /data/llm-service   (GCS-fuse mount with weights)
#   $2 ssd_root              e.g. /data/ssd           (node-local SSD cache)
#   $3 cuda_visible_devices  e.g. 0                   (the single MIG device in the Pod)
#   $4 model_folder          e.g. qwen3-8b            (folder under source_root, has base/)
#   $5 served_model_name     e.g. qwen3-8b            (OpenAI-API model id)
set -eufx

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
export LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="9.0" # H100
python3 -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"

SOURCE_ROOT=$1
SSD_ROOT=$2
MODEL_FOLDER=$4
MODEL_NAME=$5

# Sync weights from the GCS-fuse mount to node-local SSD (idempotent).
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

models_base_path="${SSD_ROOT}/${MODEL_FOLDER}/base/" # e.g. /data/ssd/qwen3-8b/base
cuda_visible_devices=$3

echo "models_base_path: $models_base_path"
echo "cuda_visible_devices: $cuda_visible_devices"

export CUDA_VISIBLE_DEVICES=$cuda_visible_devices
# Account for CUDA graph memory during profiling to avoid OOM at graph capture on
# the smaller (40GB) MIG slice.
export VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1

# A MIG slice is a single, non-poolable device => tensor-parallel-size 1.
# gpu-memory-utilization 0.90 of the 40GB slice (~36GB) leaves headroom for the
# CUDA context, activations and KV cache.
python3 start_vllm.py \
        --model $models_base_path \
        --port 8002 \
        --host 0.0.0.0 \
        --gpu-memory-utilization 0.90 \
        --max-num-seqs 64 \
        --uvicorn-log-level warning \
        --tensor-parallel-size 1 \
        --enable-prefix-caching \
        --max-model-len 16000 \
        --max-num-batched-tokens 16384 \
        --structured-outputs-config '{"backend": "guidance"}' \
        --served-model-name $MODEL_NAME &

# Capture the process ID
VLLM_PID=$!

./start_vllm_post_process.sh $SSD_ROOT $MODEL_FOLDER

# Wait for VLLM to finish before exiting script
wait $VLLM_PID
