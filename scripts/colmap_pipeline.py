import os
import subprocess
from pathlib import Path

from scripts.utils import run_subprocess
from loguru import logger


def run_colmap_feature_extractor(image_path, db_path):
    run_subprocess([
        "colmap",
        "colmap",
        "feature_extractor",
        "--database_path", db_path,
        "--image_path", image_path,
        "--ImageReader.single_camera", "1",
        "--SiftExtraction.use_gpu", "0",
        "--SiftExtraction.gpu_index", "0",
        "--SiftExtraction.estimate_affine_shape", "0",
        "--SiftExtraction.domain_size_pooling", "0",
        "--SiftExtraction.num_threads", "8" 
    ], "COLMAP FeatureExtractor")

def run_colmap_feature_extractor2(image_path, db_path):
    run_subprocess([
        "colmap",
        "colmap",
        "feature_extractor",
        "--database_path", db_path,
        "--image_path", image_path,
        "--ImageReader.single_camera", "1",
        "--ImageReader.camera_model", "PINHOLE",          # assume pinhole, can be changed if needed
        "--SiftExtraction.use_gpu", "0",                   # CPU for stability
        "--SiftExtraction.num_threads", "8",               # 8 is good starting point
        "--SiftExtraction.estimate_affine_shape", "0",     # faster, fine for drone
        "--SiftExtraction.domain_size_pooling", "0",       # faster, fine for drone
        "--SiftExtraction.max_image_size", "3200",         # important: limit to ~3000-3500px max
    ], "COLMAP FeatureExtractor")

def run_colmap_exhaustive_matcher(db_path):
    run_subprocess([
        "colmap",
        "colmap",
        "exhaustive_matcher",
        "--database_path", db_path,
        "--SiftMatching.use_gpu", "0",          # 🚀 CRUCIAL
        "--SiftMatching.num_threads", "8"  # safe limit
    ], "COLMAP ExhaustiveMatcher")

def run_colmap_sequential_matcher(db_path):
    run_subprocess([
        "colmap",
        "colmap",
        "sequential_matcher",
        "--database_path", db_path,
        "--SiftMatching.use_gpu", "0",
        "--SiftMatching.num_threads", "8",
        "--SequentialMatching.overlap", "5",  # Match to 5 neighbors forward and backward
    ], "COLMAP SequentialMatcher")

def run_colmap_sequential_matcher2(db_path):
    run_subprocess([
        "colmap",
        "colmap",
        "sequential_matcher",
        "--database_path", db_path,
        "--SiftMatching.use_gpu", "0",
        "--SiftMatching.num_threads", "8",
        "--SequentialMatching.overlap", "5",         # Tune this for your FPS
        "--SequentialMatching.quadratic_overlap", "0", # Don't scale overlap with time
        "--SequentialMatching.loop_detection", "0",    # Optional: disable loop detection for linear flight
    ], "COLMAP SequentialMatcher")

def run_colmap_mapper(db_path, image_path, output_path):
    run_subprocess([
        "colmap",
        "colmap",
        "mapper",
        "--database_path", db_path,
        "--image_path", image_path,
        "--output_path", output_path,
        "--Mapper.num_threads", "8"  # safe limit
    ], "COLMAP Mapper (Sparse Reconstruction)")

def run_colmap_model_converter(input_model_path, output_ply_path):
    run_subprocess([
        "colmap",
        "colmap",
        "model_converter",
        "--input_path", input_model_path,
        "--output_path", output_ply_path,
        "--output_type", "PLY"
    ], "COLMAP ModelConverter (Export PLY)")

def host_to_container_path(host_path):
    if not os.path.abspath(host_path).startswith(os.path.abspath("data")):
        raise ValueError(f"Path {host_path} is outside of data/ folder!")
    return "/data/" + os.path.relpath(host_path, "data")

def run_colmap_pipeline(image_path, colmap_output_folder):
    # 1️⃣ Ensure host folders exist
    os.makedirs(colmap_output_folder, exist_ok=True)
    sparse_folder = os.path.join(colmap_output_folder, "sparse")
    os.makedirs(sparse_folder, exist_ok=True)

    # 2️⃣ Compute host paths
    db_path_host = os.path.join(colmap_output_folder, "db.db")

    # 3️⃣ Map to container paths
    image_path_in_container = host_to_container_path(image_path)
    db_path_in_container = host_to_container_path(db_path_host)
    sparse_folder_in_container = host_to_container_path(sparse_folder)
    model_0_folder_in_container = os.path.join(sparse_folder_in_container, "0")
    ply_output_path_in_container = os.path.join(sparse_folder_in_container, "0.ply")

    model_0_folder_host = os.path.join(sparse_folder, "0")
    ply_output_path_host = os.path.join(sparse_folder, "0.ply")

    # 4️⃣ Run pipeline steps with CONTAINER paths
    run_colmap_feature_extractor2(image_path_in_container, db_path_in_container)
    run_colmap_sequential_matcher(db_path_in_container)
    run_colmap_mapper(db_path_in_container, image_path_in_container, sparse_folder_in_container)

    # 5️⃣ Check if model was produced
    points3D_bin_host = os.path.join(model_0_folder_host, "points3D.bin")
    if os.path.exists(points3D_bin_host):
        logger.info(f"✅ Mapper produced model — exporting PLY to {ply_output_path_host}")
        run_colmap_model_converter(model_0_folder_in_container, ply_output_path_in_container)

        # 6️⃣ Count points (optional)
        from scripts.utils import count_ply_points
        num_points = count_ply_points(ply_output_path_host)
        logger.info(f"📈 COLMAP sparse model contains {num_points} points.")
    else:
        logger.warning("⚠️ Mapper did not produce a model — skipping PLY export.")

