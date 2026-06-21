
# Use this script to copy checkpoints to the local machine, and start the VLLM server for interactive debugging.
# First, start a debug DWS job with the VLLM container (see scripts/dws), and wait for the machine to start.
# Then connect to the machine with kubectl by running the following command:
#      ./scripts/dws/connect_to_running_job.sh test-debug

# Then use this script to copy the checkpoints.

copy_checkpoint() {
    _org=$1
    _date=$2
    _size=$3

    # check if _size is set, and if not set it to 70b
    if [ -z "$_size" ]; then
        _size="70b"
    fi

    # if size is 70b, then datadir is trained-models
    # elif size is 8b then trained-models-llama-3.1-8b
    if [ "$_size" == "70b" ]; then
        _datadir="trained-models"
    elif [ "$_size" == "8b" ]; then
        _datadir="trained-models-llama-3.1-8b"
    else
        echo "Unknown size: $_size"
        exit 1
    fi

    _loradir="lora-${_size}"
    mkdir -p /tmp/${_loradir}/ft-${_org}-${_date}
    cp -r /spiffy-train-dev/${_datadir}/${_org}/data_generation_${_date}/final_checkpoint/* /tmp/${_loradir}/ft-${_org}-${_date}
}

# 70b
copy_checkpoint coterie 20241025
copy_checkpoint spanx 20250306
copy_checkpoint uncle-arnies 20241110
copy_checkpoint supergoop 20241119

copy_checkpoint mantra-brand 20250211
copy_checkpoint jordan-craig 20250313
copy_checkpoint carbahn 20250213
copy_checkpoint caraway 20241027
copy_checkpoint little-words-project 20241115


# This command will start 70B model on 4 GPUs
# ./start_vllm_h100.sh /spiffy-train-dev/base-models/llama-3.1-70b-instruct /tmp/lora/   0,1,2,3


########
copy_checkpoint coterie 20241025 8b
copy_checkpoint little-words-project 20241115 8b
copy_checkpoint spanx 20241126 8b
copy_checkpoint supergoop 20241119 8b
copy_checkpoint uncle-arnies 20241110 8b

# ./start_vllm_h100.sh /spiffy-train-dev/base-models/llama-3.1-70b-instruct /tmp/lora-70b/   0,1,2,3


# start vllm server
# ./start_vllm_llama8b_1xa100.sh /spiffy-train-dev/base-models/llama-3.1-8b-instruct /tmp/lora-8b/  5  8

pip install ipython

# see interactive_vllm_debug.py
