import os
import subprocess
from pathlib import Path

def run_pipeline(frame_dir, colmap_dir, output_format="ply"):
    os.makedirs(colmap_dir, exist_ok=True)
    database_path = os.path.join(colmap_dir, "database.db")
    sparse_dir = os.path.join(colmap_dir, "sparse")
    dense_dir = os.path.join(colmap_dir, "dense")
    os.makedirs(sparse_dir, exist_ok=True)
    os.makedirs(dense_dir, exist_ok=True)

    # Feature extraction
    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "feature_extractor",
        "--database_path", "/workspace/database.db",
        "--image_path", "/images"
    ], check=True)

    # Feature matching
    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "exhaustive_matcher",
        "--database_path", "/workspace/database.db"
    ], check=True)

    # SfM (Structure from Motion)
    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "mapper",
        "--database_path", "/workspace/database.db",
        "--image_path", "/images",
        "--output_path", "/workspace/sparse"
    ], check=True)

    # MVS (dense stereo)
    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(frame_dir)}:/images",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "image_undistorter",
        "--image_path", "/images",
        "--input_path", "/workspace/sparse/0",
        "--output_path", "/workspace/dense",
        "--output_type", "COLMAP"
    ], check=True)

    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "patch_match_stereo",
        "--workspace_path", "/workspace/dense",
        "--workspace_format", "COLMAP",
        "--PatchMatchStereo.geom_consistency", "true"
    ], check=True)

    subprocess.run([
        "docker", "run", "--rm", "--gpus", "all",
        "-v", f"{os.path.abspath(colmap_dir)}:/workspace",
        "colmap/colmap",
        "stereo_fusion",
        "--workspace_path", "/workspace/dense",
        "--workspace_format", "COLMAP",
        "--input_type", "geometric",
        "--output_path", f"/workspace/dense/fused.ply"
    ], check=True)

    print(f"COLMAP pipeline complete. Output in {dense_dir}/fused.ply")
