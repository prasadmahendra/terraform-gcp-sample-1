import os
import subprocess
import shutil
import tempfile
from typing import Optional

from vllm.lora.request import LoRARequest
from vllm.lora.resolver import LoRAResolver, LoRAResolverRegistry
from vllm.entrypoints.openai.api_server import logger

class GCSBucketLoRAResolver(LoRAResolver):
    def __init__(self, lora_gcs_dir: str, lora_ssd_dir: str) -> None:
        self.lora_gcs_dir = lora_gcs_dir
        self.lora_ssd_dir = lora_ssd_dir

    async def resolve_lora(self, base_model_name: str,
                           lora_name: str) -> Optional[LoRARequest]:
        logger.info(f"Resolving LoRA: {lora_name} for base model: {base_model_name}")
        gcs_lora_path = os.path.join(self.lora_gcs_dir, lora_name)
        ssd_lora_path = os.path.join(self.lora_ssd_dir, lora_name)
        if os.path.exists(gcs_lora_path):
            logger.info(f"GCS LoRA path exists: {gcs_lora_path}")
            if os.path.exists(ssd_lora_path) and self.check_files_sync(self.lora_gcs_dir, lora_name, self.lora_ssd_dir):
                logger.info(f"Files are synchronized between {gcs_lora_path} and {ssd_lora_path}")
                return await self.resolve_lora_helper(lora_name, ssd_lora_path)
            else:
                logger.info(f"Files are not synchronized between {gcs_lora_path} and {ssd_lora_path}")
                self.copy_files(gcs_lora_path, ssd_lora_path)
                logger.info(f"Copied files from {gcs_lora_path} to {ssd_lora_path}")
                return await self.resolve_lora_helper(lora_name, ssd_lora_path)
        return None

    async def resolve_lora_helper(self, lora_name: str, lora_path: str) -> Optional[LoRARequest]:
        logger.info(f"LoRA path exists: {lora_path}")
        adapter_config_path = os.path.join(lora_path, "adapter_config.json")
        if os.path.exists(adapter_config_path):
            logger.info(f"Adapter config path exists: {adapter_config_path}")
            lora_request = LoRARequest(lora_name=lora_name,
                                        lora_int_id=abs(
                                            hash(lora_name)),
                                        lora_path=lora_path)
            
            logger.info(f"Returning LoRA request: {lora_request.lora_name}, {lora_request.lora_int_id}, {lora_request.lora_path}")
            return lora_request
        return None

    def check_files_sync(self, source_root: str, model_folder: str, ssd_root: str) -> bool:
        """
        Check if files are synchronized between source and SSD using rclone.
        
        Args:
            source_root: Root directory of the source (e.g., GCS mount)
            model_folder: Name of the model folder to check
            ssd_root: Root directory of the SSD
            
        Returns:
            True if files are synchronized, False otherwise
        """
        source_path = os.path.join(source_root, model_folder)
        ssd_path = os.path.join(ssd_root, model_folder)
        
        cmd = [
            "rclone", "check",
            source_path,
            ssd_path,
            "--one-way",
            "--size-only"
        ]
        
        logger.info(f"Running rclone check: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode == 0:
                logger.info(f"Files are synchronized between {source_path} and {ssd_path}")
                return True
            else:
                logger.warning(f"Files are not synchronized. Return code: {result.returncode}")
                logger.warning(f"stderr: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error running rclone check: {e}")
            return False

    def copy_files(self, source: str, destination: str) -> bool:
        """
        Copy files from source to destination using gsutil with atomic operation.
        This mirrors the shell script behavior:
        1. Create a temp directory under source
        2. Copy source to temp directory
        3. Remove old destination
        4. Move temp contents to destination
        5. Clean up temp directory
        
        Args:
            source: Full path to the source directory
            destination: Full path to the destination directory
            
        Returns:
            True if copy was successful, False otherwise
        """
        # Get parent directory of destination (SSD_ROOT) and folder name
        dest_parent = os.path.dirname(destination)
        folder_name = os.path.basename(destination)
        
        # Step 1: Create temporary directory with pattern "copy-XXXXXXXX"
        temp_dir = tempfile.mkdtemp(prefix="copy-", dir=dest_parent)
        
        try:
            # Step 2: Copy source to temp directory
            cmd = [
                "gsutil", "-m", "cp", "-r", "-n",
                source,
                temp_dir
            ]
            
            logger.info(f"Running gsutil copy: {' '.join(cmd)}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode != 0:
                logger.error(f"Failed to copy files. Return code: {result.returncode}")
                logger.error(f"stderr: {result.stderr}")
                logger.error(f"stdout: {result.stdout}")
                shutil.rmtree(temp_dir, ignore_errors=True)
                return False
            
            # Step 3: Remove old destination
            if os.path.exists(destination):
                logger.info(f"Removing old destination: {destination}")
                shutil.rmtree(destination)
            
            # Step 4: Move temp contents to destination
            temp_source_path = os.path.join(temp_dir, folder_name)
            cmd = ["mv", "-n", temp_source_path, destination]
            
            logger.info(f"Running mv: {' '.join(cmd)}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode != 0:
                logger.error(f"Failed to move files. Return code: {result.returncode}")
                logger.error(f"stderr: {result.stderr}")
                shutil.rmtree(temp_dir, ignore_errors=True)
                return False
            
            # Step 5: Clean up temp directory
            shutil.rmtree(temp_dir, ignore_errors=True)
            
            logger.info(f"Successfully copied files from {source} to {destination}")
            return True
            
        except Exception as e:
            logger.error(f"Error during copy operation: {e}")
            shutil.rmtree(temp_dir, ignore_errors=True)
            return False

    
        
def register_gcs_bucket_resolver() -> None:
    """Register the GCS Bucket LoRA Resolver with vLLM"""

    lora_gcs_dir = os.getenv('GCS_BUCKET_LORA_RESOLVER_CACHE_DIR')
    lora_ssd_dir = os.getenv('SSD_BUCKET_LORA_RESOLVER_CACHE_DIR')
    logger.info(f"Registering GCS Bucket LoRA Resolver with gcs dir: {lora_gcs_dir} and ssd dir: {lora_ssd_dir}")
    gcs_bucket_resolver = GCSBucketLoRAResolver(lora_gcs_dir, lora_ssd_dir)
    LoRAResolverRegistry.register_resolver("GCS Bucket Resolver",
                                            gcs_bucket_resolver)
    logger.info(f"Registered GCS Bucket LoRA Resolver with gcs dir: {lora_gcs_dir} and ssd dir: {lora_ssd_dir}")