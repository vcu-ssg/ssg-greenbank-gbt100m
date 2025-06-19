import os
import re
import json
import subprocess
from pathlib import Path

from scripts.utils import run_subprocess, DOCKER_COMPOSE_PREFIX
from loguru import logger
from datetime import datetime

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

def run_colmap_model_analyzer(model_folder_in_container, stats_file ):
    """
    Run COLMAP model_analyzer inside container and save output as JSON in colmap/stats/model_analyzer.json.
    `model_folder_in_container` should be like /projects/.../colmap/sparse/0
    """

    # Derive output folder path (e.g., /projects/.../colmap)
    colmap_root = Path(model_folder_in_container).parents[1]
    
    # Extract scenario name (last component of root folder)
    scenario_name = os.path.basename(colmap_root)

    cmd = DOCKER_COMPOSE_PREFIX + [
        "run", "--rm",
        "--user", f"{os.getuid()}:{os.getgid()}",
        "colmap", "colmap", "model_analyzer",
        "--path", model_folder_in_container
    ]

    logger.info(f"📊 Running COLMAP model_analyzer for: {scenario_name}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        output = result.stderr
        
        stats = {
            "Scenario": scenario_name,
            "Timestamp": datetime.now().isoformat()
        }

        patterns = {
            "Cameras": r"\]\s+Cameras:\s+(\d+)",
            "Images": r"\]\s+Images:\s+(\d+)",
            "Registered Images": r"\]\s+Registered images:\s+(\d+)",
            "Points3D": r"\]\s+Points:\s+(\d+)",
            "Observations": r"\]\s+Observations:\s+(\d+)",
            "Mean Track Length": r"\]\s+Mean track length:\s+([\d\.]+)",
            "Mean Observations per Image": r"\]\s+Mean observations per image:\s+([\d\.]+)",
            "Mean Reprojection Error": r"\]\s+Mean reprojection error:\s+([\d\.]+)"
        }

        for key, pattern in patterns.items():
            stats[key] = "?"
            for line in output.splitlines():
                match = re.search(pattern, line)
                if match:
                    stats[key] = float(match.group(1)) if '.' in match.group(1) else int(match.group(1))
                    break

        with open(stats_file, "w") as f:
            json.dump(stats, f, indent=2)

        base = Path(stats_file)
        txt_filename = base.with_suffix(".txt")
        with open(txt_filename, "w") as f:
            f.write(output)

        logger.success(f"✅ ModelAnalyzer stats saved → {stats_file}")
        return stats

    except subprocess.CalledProcessError as e:
        logger.error(f"❌ model_analyzer failed for {scenario_name}: {e.output}")
        raise

def host_to_container_path(host_path):
    if not os.path.abspath(host_path).startswith(os.path.abspath("projects")):
        raise ValueError(f"Path {host_path} is outside of projects/ folder!")
    return "/projects/" + os.path.relpath(host_path, "projects")

def run_colmap_pipeline(image_path, colmap_output_folder):
    """ Created a COLMAP pipeline """
    # 1️⃣ Ensure host folders exist
    os.makedirs(colmap_output_folder, exist_ok=True)
    sparse_folder = os.path.join(colmap_output_folder, "sparse")
    os.makedirs(sparse_folder, exist_ok=True)
    stats_folder = os.path.join(colmap_output_folder,"stats")
    os.makedirs(stats_folder, exist_ok=True)
    stats_file = os.path.join(stats_folder, f"model_analyzer-sparse-0.json")

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
        run_colmap_model_analyzer(model_0_folder_in_container,stats_file)

        # 6️⃣ Count points (optional)
        from scripts.utils import count_ply_points
        num_points = count_ply_points(ply_output_path_host)
        logger.info(f"📈 COLMAP sparse model contains {num_points} points.")
    else:
        logger.warning("⚠️ Mapper did not produce a model — skipping PLY export.")


def run_colmap_point_filtering(input_model_host, output_model_host, min_track_len=2, max_reproj_error=4.0, min_tri_angle=1.5):
    """Run COLMAP point_filtering inside a Docker container with project-relative paths."""

    # Verify required file
    points3d_bin = os.path.join(input_model_host, "points3D.bin")
    if not os.path.exists(points3d_bin):
        logger.error(f"❌ points3D.bin not found in {input_model_host}")
        return

    os.makedirs(output_model_host, exist_ok=True)

    # Map to container paths
    input_model_container = host_to_container_path(input_model_host)
    output_model_container = host_to_container_path(output_model_host)
    ply_output_path_in_container = os.path.join(os.path.dirname(output_model_container),f"{os.path.basename(output_model_container)}.ply")

    run_subprocess([
        "colmap",
        "colmap",
        "point_filtering",
        "--input_path", input_model_container,
        "--output_path", output_model_container,
        "--min_track_len", str(min_track_len),
        "--max_reproj_error",str(max_reproj_error),
        "--min_tri_angle", str(min_tri_angle)
    ], "COLMAP Model Cleaner")
    
    run_colmap_model_converter(output_model_container, ply_output_path_in_container)

    stats_folder = os.path.dirname(os.path.dirname( output_model_host ))
    stats_file = os.path.join(stats_folder, f"stats/model_analyzer-sparse-{os.path.basename(output_model_host)}.json")
    run_colmap_model_analyzer(output_model_container,stats_file)
