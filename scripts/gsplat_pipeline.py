import os
import sys
from scripts.utils import run_subprocess
from loguru import logger

def host_to_container_path(host_path: str) -> str:
    """Convert a host path like data/frames/... to container path /data/frames/..."""
    abs_host = os.path.abspath(host_path)
    abs_data_root = os.path.abspath("data")

    if not abs_host.startswith(abs_data_root):
        raise ValueError(f"Path {host_path} must be within the project ./data directory.")

    rel_path = os.path.relpath(abs_host, abs_data_root)
    return os.path.join("/data", rel_path)


def run_gsplat2_training(scene, frames_dir, sparse_dir, output_dir):
    logger.info(f"🟢 Running gsplat for {scene}")
    logger.info(f"📸 Host Images      : {frames_dir}")
    logger.info(f"📈 Host Sparse model: {sparse_dir}")
    logger.info(f"💾 Host Output path : {output_dir}")

    # Validate and create host-side output directory
    try:
        os.makedirs(output_dir, exist_ok=True)
        logger.success(f"📁 Ensured output directory: {output_dir}")
    except Exception as e:
        logger.error(f"❌ Failed to create output directory {output_dir}: {e}")
        sys.exit(1)

    # Convert to container paths
    frames_container = host_to_container_path(frames_dir)
    sparse_container = host_to_container_path(sparse_dir)
    output_container = host_to_container_path(output_dir)

    logger.info(f"📸 Container Images      : {frames_container}")
    logger.info(f"📈 Container Sparse model: {sparse_container}")
    logger.info(f"💾 Container Output path : {output_container}")

    model_container = os.path.join(sparse_container, "sparse", "0")

# https://medium.com/data-science/turn-yourself-into-a-3d-gaussian-splat-3a2bc59a770f
# resolution=1                      # default 1
# sh_degree=3                       # default 3
# position_lr_init=0.00016          # default = 0.00016, large scale -> 0.000016
# scaling_lr=0.005                  # default = 0.005, large scale -> 0.001
# iterations=30000                  # default 30000
# densify_from_iter=500             # default 500
# densify_until_iter=15000          # default 15000
# test_iterations="7000 30000"      # default 7000 30000
# save_iterations="7000 30000"      # default 7000 30000
# data_device=cpu

    cmd = [
        "gsplat2",
        "python", "train.py",
        "--data_device=cpu",
        "--resolution=8",
        "--sh_degree=1",
        "--test_iterations=-1",
        "--source_path", sparse_container,     # ✅ this is the COLMAP project root
        "--model_path", model_container,       # ✅ full path to sparse/0
        "--images", frames_container
    ]

    run_subprocess(cmd, f"gsplat2 [{scene}]")
