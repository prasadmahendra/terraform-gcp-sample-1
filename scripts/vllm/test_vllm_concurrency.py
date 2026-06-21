import subprocess
import threading
import time
import concurrent.futures
import json
import requests
import random

# Replace with your actual vLLM endpoints and payloads
VLLM_URL = "http://localhost:8002"
UNLOAD_ENDPOINT = f"{VLLM_URL}/v1/unload_lora_adapter"
LOAD_ENDPOINT = f"{VLLM_URL}/v1/load_lora_adapter"
CHAT_ENDPOINT = f"{VLLM_URL}/v1/chat/completions"

def curl_post(url, json_data):
    """Helper to run curl POST with JSON payload."""
    cmd = ["curl", "-X", "POST", url, "-H", "Content-Type: application/json", "-d", json_data]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout.strip()

def http_post(url, json_data):
    """HTTP POST using requests library."""
    try:
        response = requests.post(url, json=json_data, timeout=30)
        return response.status_code, response.text
    except Exception as e:
        return None, str(e)

def unload_lora(lora_name):
    """Unload LoRA weights."""
    payload = json.dumps({"lora_name": lora_name})
    print(f"Unloading LoRA weights: {lora_name}")
    
    # Try HTTP first, fallback to curl
    status, resp = http_post(UNLOAD_ENDPOINT, {"lora_name": lora_name})
    print(f"Unload response (HTTP {status}):", resp)
    if status != 200:
        resp = curl_post(UNLOAD_ENDPOINT, payload)
        print("Unload response (curl):", resp)
    else:
        print(f"Unload response (HTTP {status}):", resp)
    
    return resp

def load_lora(lora_name, lora_path):
    """Load LoRA weights."""
    payload = json.dumps({"lora_name": lora_name, "lora_path": lora_path})
    print(f"Loading LoRA weights: {lora_name}")
    
    # Try HTTP first, fallback to curl
    status, resp = http_post(LOAD_ENDPOINT, {"lora_name": lora_name, "lora_path": lora_path})
    print(f"Load response (HTTP {status}):", resp)
    if status != 200:
        resp = curl_post(LOAD_ENDPOINT, payload)
        print("Load response (curl):", resp)
    else:
        print(f"Load response (HTTP {status}):", resp)
    
    return resp

def send_request(prompt, server_url="http://localhost:8002/v1/chat/completions", lora_name=None):
    """Send a single request to vLLM server using HTTP requests with optional LoRA context"""
    try:
        payload = {
            "model": lora_name,
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 50,
            "temperature": 0.0
        }
        
        start_time = time.time()
        response = requests.post(server_url, json=payload)
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "response": result["choices"][0]["message"]["content"],
                "latency": end_time - start_time,
                "lora_used": lora_name
            }
        else:
            return {
                "success": False,
                "error": f"HTTP {response.status_code}",
                "latency": end_time - start_time,
                "lora_used": lora_name
            }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "latency": 0,
            "lora_used": lora_name
        }

def generate_random_prompt(length=200):
    """Generate a random prompt of specified length"""
    # Create a more realistic prompt with words and sentences
    words = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
        "will", "would", "could", "should", "may", "might", "can", "must", "shall",
        "computer", "technology", "science", "research", "development", "analysis", "system",
        "data", "information", "knowledge", "learning", "intelligence", "algorithm", "program",
        "software", "hardware", "network", "database", "application", "service", "platform",
        "user", "client", "server", "request", "response", "process", "function", "method",
        "variable", "constant", "parameter", "argument", "result", "output", "input",
        "test", "experiment", "evaluation", "performance", "efficiency", "optimization",
        "problem", "solution", "challenge", "opportunity", "innovation", "creativity",
        "quality", "reliability", "security", "privacy", "scalability", "flexibility"
    ]
    
    prompt = ""
    while len(prompt) < length:
        if random.random() < 0.3:  # 30% chance to add punctuation
            prompt += random.choice([". ", "! ", "? ", ", "])
        else:
            word = random.choice(words)
            if prompt and not prompt.endswith(" "):
                prompt += " "
            prompt += word
    
    # Trim to exact length and ensure it ends properly
    prompt = prompt[:length].strip()
    if not prompt.endswith((".", "!", "?")):
        prompt += "."
    
    return prompt

def send_concurrent_requests(server_url, num_concurrent, max_workers, prompt_length=200, lora_name=None):
    """Send a batch of concurrent requests with optional LoRA context"""
    print(f"  Sending requests with LoRA context: {lora_name if lora_name else 'None (base model)'}")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(send_request, generate_random_prompt(prompt_length), server_url, lora_name) for _ in range(num_concurrent)]
        
        results = []
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    
    return results
    
def main():
    print("=== vLLM LoRA Concurrency Test ===")
    print(f"vLLM URL: {VLLM_URL}")
    print(f"Chat endpoint: {CHAT_ENDPOINT}")
    print(f"LoRA endpoints: {UNLOAD_ENDPOINT}, {LOAD_ENDPOINT}")
    print("-" * 50)
    
    # Step 1: Unload LoRA weights
    #print("\n1. UNLOADING LoRA WEIGHTS")
    #print("=" * 30)
    #unload_response = unload_lora("ft-caraway-20241027")
    #print(unload_response)
    
    # Wait a moment for unload to complete
    print("Waiting 5 seconds for unload to complete...")
    time.sleep(5)
    
    # variables
    server = "http://localhost:8002/v1/chat/completions"
    actual_concurrent = 2
    max_workers = 2
    prompt_length = 200

    # Step 2 & 3: Send parallel requests AND load LoRA weights simultaneously
    #print("\n2. SENDING PARALLEL REQUESTS (No LoRA) + LOADING LoRA WEIGHTS")
    #print("=" * 60)
    
    # Start both operations simultaneously using threads
    def run_parallel_requests():
        return send_concurrent_requests(server, actual_concurrent, max_workers, prompt_length, "ft-spanx-20250304")
    
    def run_load_lora():
        time.sleep(2)
        return load_lora("ft-caraway-20241027", "/data/ssd/llama-3.1-70b-instruct/lora/ft-caraway-20241027")
    
    # Create threads for both operations
    #with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    #    # Submit both tasks
    #    requests_future = executor.submit(run_parallel_requests)
    #    load_future = executor.submit(run_load_lora)
        
    #    # Wait for both to complete
    #    results = requests_future.result()
    #    load_response = load_future.result()
    
    #print(f"\nLoRA Load Response: {load_response}")
        
    # Print batch results
    #successful = [r for r in results if r["success"]]
    #failed = [r for r in results if not r["success"]]
        
    #print(f"  ✓ Successful: {len(successful)}, ✗ Failed: {len(failed)}")
        
    #if successful:
    #    latencies = [r["latency"] for r in successful]
    #    avg_latency = sum(latencies) / len(latencies)
    #    min_latency = min(latencies)
    #    max_latency = max(latencies)
    #    print(f"  Average latency: {avg_latency:.3f}s (min: {min_latency:.3f}s, max: {max_latency:.3f}s)")
    #    [print(r["response"]) for r in successful]
        
    #if failed:
    #    print(f"  Errors:")
    #    error_counts = {}
    #    for result in failed:
    #        error = result["error"]
    #        error_counts[error] = error_counts.get(error, 0) + 1
            
    #    for error, count in error_counts.items():
    #        print(f"    - {error}: {count} times")
    
    # Wait a moment for load to complete
    print("Waiting 3 seconds for load to settle...")
    time.sleep(3)
    
    # Step 4: Send parallel requests (with LoRA context)
    print("\n4. SENDING PARALLEL REQUESTS (With LoRA Context)")
    print("=" * 50)
    # Send concurrent requests with specific LoRA context
    results_with_lora = send_concurrent_requests(server, actual_concurrent, max_workers, prompt_length, "ft-spanx-20250306")
        
    # Print batch results
    successful = [r for r in results_with_lora if r["success"]]
    failed = [r for r in results_with_lora if not r["success"]]
        
    print(f"  ✓ Successful: {len(successful)}, ✗ Failed: {len(failed)}")
        
    if successful:
        latencies = [r["latency"] for r in successful]
        avg_latency = sum(latencies) / len(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        print(f"  Average latency: {avg_latency:.3f}s (min: {min_latency:.3f}s, max: {max_latency:.3f}s)")
        [print(r["response"]) for r in successful]
        
    if failed:
        print(f"  Errors:")
        error_counts = {}
        for result in failed:
            error = result["error"]
            error_counts[error] = error_counts.get(error, 0) + 1
            
        for error, count in error_counts.items():
            print(f"    - {error}: {count} times")
    
    
    print("\n=== TEST COMPLETE ===")

if __name__ == "__main__":
    main()