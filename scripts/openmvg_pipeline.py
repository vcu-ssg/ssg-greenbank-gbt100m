import os
import sys
import subprocess
import time
import json

from loguru import logger


# Configure Loguru
os.makedirs("logs", exist_ok=True)
logger.remove()  # Remove default handler
logger.add(sys.stderr, level="INFO", colorize=True, format="<green>{time:HH:mm:ss}</green> | <level>{level}</level> | <level>{message}</level>")
logger.add("logs/pipeline.log", level="DEBUG", format="{time} | {level} | {message}")

project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

frames_dir = os.path.join(project_root, "data", "frames")
openmvs_dir = os.path.join(project_root, "data", "openmvs")

# Always point explicitly to the docker-compose.yml
DOCKER_COMPOSE_PREFIX = [
    "docker", "compose", "-f", "./docker/docker-compose.yml"
]

def run_subprocess(cmd_suffix, step_name):
    """
    Run a subprocess with live console output AND log file capture via Loguru.
    """
    full_cmd = DOCKER_COMPOSE_PREFIX + [
        "run", "--rm",
        "--user", f"{os.getuid()}:{os.getgid()}"
    ] + cmd_suffix

    logger.info(f"👉 Running [{step_name}]: {' '.join(full_cmd)}")

    start_time = time.time()

    process = subprocess.Popen(
        full_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    try:
        with process.stdout:
            for line in process.stdout:
                line = line.rstrip()
                if line:
                    logger.info(f"[{step_name}] {line}")  # Live log each line with step prefix

        returncode = process.wait()
        duration = time.time() - start_time

        if returncode == 0:
            logger.success(f"✅ Step succeeded: {step_name} (Elapsed time: {duration:.1f} sec)")
        else:
            logger.error(f"❌ Error during step: {step_name} (Exit code {returncode})")
            logger.error(f"❌ Aborting pipeline after failed step: {step_name}")
            sys.exit(returncode)

    except Exception as e:
        logger.exception(f"❌ Exception during step: {step_name}: {str(e)}")
        sys.exit(1)


def validate_sfm_data_paths(sfm_json_path: str) -> None:
    """
    Checks whether all image paths in the OpenMVG sfm_data.json are relative.
    This ensures downstream OpenMVS will correctly locate images.
    """
    with open(sfm_json_path, encoding="utf-8") as f:
        data = json.load(f)

    views = data.get("views", [])
    bad_paths = []

    for view in views:
        path = view["value"]["ptr_wrapper"]["data"]["filename"]
        if os.path.isabs(path):
            bad_paths.append(path)

    if bad_paths:
        logger.error("❌ sfm_data.json contains absolute image paths. These will break OpenMVS.")
        for p in bad_paths[:5]:  # Limit to first 5 for readability
            logger.error(f"  - {p}")
        logger.error("👉 Ensure you're passing a consistent relative image path to SfMInit_ImageListing.")
        logger.error("👉 Current recommendation: mount your data root at /data and use `-i /data/frames`.")
        logger.error("❌ Aborting pipeline to prevent wasted processing.")
        sys.exit(1)
    else:
        logger.info("✅ All image paths in sfm_data.json are relative — OK for OpenMVS.")
        


def export_sparse_ply(sfm_bin_path, output_ply_path):
    run_subprocess([
        "openmvg",
        "openMVG_main_openMVG2PLY",
        "-i", sfm_bin_path,
        "-o", output_ply_path
    ], "Export Sparse Point Cloud (PLY)")

def export_dense_ply(openmvs_dir, output_ply_path):
    run_subprocess([
        "openmvs",
        "ExportPointCloud",
        "-w", openmvs_dir,
        "scene_dense.mvs",
        "--output-file", output_ply_path
    ], "Export Dense Point Cloud (PLY)")

def export_mesh_ply(openmvs_dir, output_ply_path):
    run_subprocess([
        "openmvs",
        "ExportMesh",
        "-w", openmvs_dir,
        "scene_dense_mesh.mvs",
        "--output-file", output_ply_path
    ], "Export Mesh (PLY)")

def export_textured_mesh_ply(openmvs_dir, output_ply_path):
    run_subprocess([
        "openmvs",
        "ExportMesh",
        "-w", openmvs_dir,
        "scene_dense_mesh_texture.mvs",
        "--output-file", output_ply_path
    ], "Export Textured Mesh (PLY)")
    
def count_ply_points(ply_path):
    """Count number of points in a PLY file (assuming ascii or binary with header)."""
    if not os.path.exists(ply_path):
        logger.error(f"PLY file not found: {ply_path}")
        return 0

    with open(ply_path, "rb") as f:
        header_lines = []
        while True:
            line = f.readline()
            if not line:
                break
            header_lines.append(line.decode(errors="ignore").strip())
            if line.strip() == b"end_header":
                break

    # Look for line: element vertex NNN
    for line in header_lines:
        if line.startswith("element vertex"):
            parts = line.split()
            if len(parts) == 3:
                try:
                    return int(parts[2])
                except ValueError:
                    pass

    logger.error(f"Could not parse number of points in PLY header: {ply_path}")
    return 0

def check_and_select_best_matches(match_files, min_valid_matches=10, min_matches_per_pair=10):
    """
    Check multiple match files, select the best one for SfM, or abort.

    Args:
        match_files: list of match file paths (e.g. [matches.f.txt, matches.e.txt])
        min_valid_matches: Minimum number of valid image pairs required.
        min_matches_per_pair: Minimum number of matches required per image pair.

    Returns:
        Path to selected match file for SfM (str)
    """
    def count_valid_pairs(match_file):
        valid_pairs = 0
        total_pairs = 0

        with open(match_file, "r") as f:
            while True:
                line = f.readline()
                if not line:
                    break

                tokens = line.strip().split()
                if len(tokens) != 2:
                    continue  # malformed line

                img1_id, img2_id = map(int, tokens)
                matches_line = f.readline()
                matches = matches_line.strip().split()

                num_matches = len(matches) // 2

                total_pairs += 1

                if num_matches >= min_matches_per_pair:
                    valid_pairs += 1

        logger.info(f"ℹ️ [{match_file}] → {valid_pairs} valid pairs (≥{min_matches_per_pair} matches), total pairs: {total_pairs}")
        return valid_pairs

    logger.info("🔍 Checking match statistics to select best match file...")

    results = []
    for mf in match_files:
        try:
            valid_pairs = count_valid_pairs(mf)
            results.append((mf, valid_pairs))
        except Exception as e:
            logger.warning(f"⚠️ Could not read match file {mf}: {str(e)}")
            results.append((mf, -1))  # force low score if failed to read

    # Select best file
    results_sorted = sorted(results, key=lambda x: x[1], reverse=True)
    best_file, best_valid_pairs = results_sorted[0]

    if best_valid_pairs < min_valid_matches:
        logger.error(f"❌ No match file passed the threshold of {min_valid_matches} valid pairs.")
        logger.error(f"❌ Aborting pipeline prior to SfM.")
        sys.exit(1)
    else:
        logger.success(f"✅ Selected match file for SfM: {best_file} ({best_valid_pairs} valid pairs)")
        return best_file


def run_pipeline(frame_dir, openmvg_dir, openmvs_dir, enable_texturing=True, sfm_engine="GLOBAL", matches_ratio=0.6):
    """ hardwared pipeline"""
    logger.info("🚀 Starting OpenMVG + OpenMVS pipeline ...")

    if 1:
        # 1️⃣ Run openMVG_main_SfMInit_ImageListing
        run_subprocess([
            "openmvg",
            "openMVG_main_SfMInit_ImageListing",
            "-i", "/data/frames",
            "-d", "/usr/local/lib/openMVG/sensor_width_camera_database.txt",
            "-o", "/data/openmvg",
            "-f", "4.5"
        ], "openMVG_main_SfMInit_ImageListing")

        # 2️⃣ Run openMVG_main_ComputeFeatures
        run_subprocess([
            "openmvg",
            "openMVG_main_ComputeFeatures",
            "-i", "/data/openmvg/sfm_data.json",
            "-o", "/data/openmvg/matches"
        ], "openMVG_main_ComputeFeatures")

        # 3️⃣ Run openMVG_main_ComputeMatches FUNDAMENTAL
        run_subprocess([
            "openmvg",
            "openMVG_main_ComputeMatches",
            "-i", "/data/openmvg/sfm_data.json",
            "-o", "/data/openmvg/matches",
            "--ratio", str(matches_ratio),
            "--output_file", "/data/openmvg/matches/matches.f.txt",
        ], "openMVG_main_ComputeMatches (FUNDAMENTAL)")

        # 3️⃣ Run openMVG_main_ComputeMatches ESSENTIAL
        run_subprocess([
            "openmvg",
            "openMVG_main_ComputeMatches",
            "-i", "/data/openmvg/sfm_data.json",
            "-o", "/data/openmvg/matches",
            "--ratio", str(matches_ratio),
            "--output_file", "/data/openmvg/matches/matches.e.txt"
        ], "openMVG_main_ComputeMatches (ESSENTIAL)")


        # 🔍 Export Matches Visualization SVG
        for matchfile in ["matches.f.txt", "matches.e.txt"]:
            run_subprocess([
                "openmvg",
                "openMVG_main_exportMatches",
                "-i", "/data/openmvg/sfm_data.json",
                "-d", "/data/openmvg/matches",
                "-o", f"/data/openmvg/matches/matches_visualization_{matchfile.replace('.txt','.svg')}",
                "-m", f"/data/openmvg/matches/{matchfile}"
            ], f"Export Matches Visualization ({matchfile})")
    
    match_files = [
        "data/openmvg/matches/matches.f.txt",
        "data/openmvg/matches/matches.e.txt"
    ]

    selected_match_file = check_and_select_best_matches(
        match_files,
        min_valid_matches=10,
        min_matches_per_pair=10
    )
  
    # 4️⃣ Run openMVG_main_SfM
    run_subprocess([
        "openmvg",
        "openMVG_main_SfM",
        "-i", "/data/openmvg/sfm_data.json",
        "-m", "/data/openmvg/matches",
        "-o", "/data/openmvg/reconstruction_global" if sfm_engine == "GLOBAL" else "/data/openmvg/reconstruction_incremental",
        "--sfm_engine", sfm_engine,
        "--match_file", os.path.basename(selected_match_file)
    ], f"openMVG_main_SfM ({sfm_engine})")


    export_sparse_ply(
        sfm_bin_path=f"{recon_path}/sfm_data.bin",
        output_ply_path="data/visuals/sparse.ply"
    )

    # Convert to JSON to inspect number of poses
    run_subprocess([
        "openmvg",
        "openMVG_main_ConvertSfM_DataFormat",
        "-i", "/data/openmvg/reconstruction_incremental/sfm_data.bin",
        "-o", "/data/openmvg/reconstruction_incremental/sfm_data.json"
    ], "openMVG_main_ConvertSfM_DataFormat")

    # Check number of poses
    with open("data/openmvg/reconstruction_incremental/sfm_data.json") as f:
        data = json.load(f)

    num_poses = len(data.get("views", {}))
    logger.info(f"Number of views (poses) reconstructed: {num_poses}")

    MIN_POSES = 3
    if num_poses < MIN_POSES:
        logger.error(f"❌ Too few poses ({num_poses}) — aborting pipeline.")
        sys.exit(1)

    validate_sfm_data_paths("data/openmvg/reconstruction_incremental/sfm_data.json")

    # Convert to OpenMVS format
    recon_path = "/data/openmvg/reconstruction_global" if sfm_engine == "GLOBAL" else "/data/openmvg/reconstruction_incremental"

    run_subprocess([
        "openmvg",
        "openMVG_main_openMVG2openMVS",
        "-i", f"{recon_path}/sfm_data.bin",
        "-d", "/data/openmvs",
        "-o", "/data/openmvs/scene.mvs"
    ], "openMVG_main_openMVG2openMVS")

    # 6️⃣ Run OpenMVS DensifyPointCloud
    
    # First link frames into /data/openmvs

    run_subprocess([
        "openmvs",
        "bash", "-c",
        "ln -sf /data/frames/*.jpg /data/openmvs/"
    ], "Link images into openmvs folder")

    run_subprocess([
        "openmvs",
        "DensifyPointCloud",
        "-w", "/data/openmvs",
        "scene.mvs"
    ], "OpenMVS DensifyPointCloud")
    
    export_dense_ply(
        openmvs_dir="/data/openmvs",
        output_ply_path="data/visuals/scene_dense.ply"
    )    

    num_dense_points = count_ply_points("data/openmvs/scene_dense.ply")
    logger.info(f"scene_dense.ply contains {num_dense_points} points")

    MIN_POINTS_FOR_MESH = 1000
    if num_dense_points < MIN_POINTS_FOR_MESH:
        logger.error(f"❌ Aborting pipeline — too few dense points ({num_dense_points}) for ReconstructMesh.")
        sys.exit(1)


    # 7️⃣ Run OpenMVS ReconstructMesh
    run_subprocess([
        "openmvs",
        "ReconstructMesh",
        "-w", "/data/openmvs",
        "scene_dense.mvs"
    ], "OpenMVS ReconstructMesh")

    export_mesh_ply(
        openmvs_dir="/data/openmvs",
        output_ply_path="data/visuals/scene_dense_mesh.ply"
    )

    # 8️⃣ Run OpenMVS TextureMesh (optional)
    if enable_texturing:
        run_subprocess([
            "openmvs",
            "TextureMesh",
            "-w", "/data/openmvs",
            "scene_dense_mesh.mvs"
        ], "OpenMVS TextureMesh")

    export_textured_mesh_ply(
        openmvs_dir="/data/openmvs",
        output_ply_path="data/visuals/scene_dense_mesh_textured.ply"
    )

    logger.info("✅ OpenMVG + OpenMVS pipeline complete.")

