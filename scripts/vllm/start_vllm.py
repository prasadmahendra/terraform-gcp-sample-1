#!/usr/bin/env python3
"""
Custom vLLM server startup script that replaces the main function in 
vllm.entrypoints.openai.api_server and passes kwargs to run_server.
"""

from vllm.entrypoints.openai.api_server import run_server, logger
from vllm.entrypoints.openai.cli_args import make_arg_parser, validate_parsed_serve_args
from vllm.entrypoints.utils import cli_env_setup
from vllm.utils.argparse_utils import FlexibleArgumentParser
import uvloop

if __name__ == "__main__":
    # This is a custom script that replaces the main function in 
    # vllm.entrypoints.openai.api_server and passes kwargs to run_server.
    cli_env_setup()
    parser = FlexibleArgumentParser(
        description="vLLM OpenAI-Compatible RESTful API server.")
    parser = make_arg_parser(parser)
    args = parser.parse_args()
    validate_parsed_serve_args(args)

    # Define uvicorn kwargs with backlog and limit_concurrency parameters based on model size
    model_name = args.served_model_name[0]

    # Determine model size and set appropriate backlog and concurrency limits
    if '70b' in model_name.lower():
        # 70B model - lower concurrency due to lower rate of requests
        backlog = 32
        limit_concurrency = 32
    elif '8b' in model_name.lower():
        # 8B model - higher concurrency due to higher rate of requests
        backlog = 64
        limit_concurrency = 64
    else:
        # Default values for unknown model sizes
        backlog = 32
        limit_concurrency = 32
    
    uvicorn_kwargs = {
        "backlog": backlog,
        "limit_concurrency": limit_concurrency
    }
    
    logger.info(f"Model: {model_name}")
    logger.info(f"Setting backlog: {backlog}, limit_concurrency: {limit_concurrency}")

    uvloop.run(run_server(args, **uvicorn_kwargs))