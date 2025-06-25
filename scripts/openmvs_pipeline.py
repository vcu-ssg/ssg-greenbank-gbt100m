import os
import time
from pathlib import Path
from scripts.utils import run_subprocess
from loguru import logger

def host_to_container_path(host_path):
    if not os.path.abspath(host_path).startswith(os.path.abspath("projects")):
        raise ValueError(f"Path {host_path} is outside of projects/ folder!")
    return "/projects/" + os.path.relpath(host_path, "projects")


def run_interface_colmap(input_folder, output_mvs_file, image_folder):
    run_subprocess([
        "openmvs",
        "bin/InterfaceCOLMAP",
        "-i", input_folder,
        "-o", output_mvs_file,
        "-w", image_folder  # workspace root (needed for images)
    ], "OpenMVS: InterfaceCOLMAP")

def run_densify_point_cloud(mvs_file, image_folder):
    run_subprocess([
        "openmvs",
        "bin/DensifyPointCloud",
        mvs_file,
        "--working-folder", image_folder
    ], "OpenMVS: DensifyPointCloud")

def run_reconstruct_mesh(mvs_file):
    run_subprocess([
        "openmvs",
        "bin/ReconstructMesh",
        mvs_file
    ], "OpenMVS: ReconstructMesh")

def run_refine_mesh(mvs_file):
    run_subprocess([
        "openmvs",
        "bin/RefineMesh",
        mvs_file
    ], "OpenMVS: RefineMesh")

def run_texture_mesh(mvs_file, image_folder):
    run_subprocess([
        "openmvs",
        "bin/TextureMesh",
        mvs_file,
        "--working-folder", image_folder
    ], "OpenMVS: TextureMesh")

def convert_mesh_to_glb(input_mesh_path, output_glb_path):
    run_subprocess([
        "openmvs",
        "bin/meshlabserver",
        "-i", input_mesh_path,
        "-o", output_glb_path
    ], "Meshlab: Convert to GLB")



def mvs_pipeline(image_folder, sparse_model_folder, mvs_output_folder):
    """
    Run full OpenMVS pipeline.

    Parameters:
    - image_folder: host path to undistorted images (COLMAP output)
    - sparse_model_folder: host path to COLMAP sparse model (e.g., colmap/sparse/0)
    - mvs_output_folder: host path where OpenMVS results should go (e.g., mvs/0)
    """
    start = time.time()
    os.makedirs(mvs_output_folder, exist_ok=True)

    # Host-side filenames
    mvs_file = os.path.join(mvs_output_folder, "scene.mvs")
    dense_mesh_file = mvs_file.replace(".mvs", "_dense.mvs")
    mesh_refine_file = dense_mesh_file.replace("_dense.mvs", "_dense_mesh.mvs")
    mesh_texture_file = mesh_refine_file.replace("_mesh.mvs", "_mesh_refine.mvs")
    ply_file = Path(mvs_output_folder) / "scene_dense_mesh_refine_texture.ply"
    glb_file = Path(mvs_output_folder) / "scene.glb"

    # Convert to container paths
    image_folder_container = host_to_container_path(image_folder)
    input_folder_container = host_to_container_path(str(Path(sparse_model_folder)))
    mvs_file_container = host_to_container_path(mvs_file)
    dense_mesh_file_container = host_to_container_path(dense_mesh_file)
    mesh_refine_file_container = host_to_container_path(mesh_refine_file)
    mesh_texture_file_container = host_to_container_path(mesh_texture_file)
    ply_file_container = host_to_container_path(str(ply_file))
    glb_file_container = host_to_container_path(str(glb_file))

    logger.info("▶️ InterfaceCOLMAP")
    run_interface_colmap(input_folder_container, mvs_file_container, image_folder_container)

    logger.info("▶️ DensifyPointCloud")
    run_densify_point_cloud(mvs_file_container, image_folder_container)

    logger.info("▶️ ReconstructMesh")
    run_reconstruct_mesh(dense_mesh_file_container)

    logger.info("▶️ RefineMesh")
    run_refine_mesh(mesh_refine_file_container)

    logger.info("▶️ TextureMesh")
    run_texture_mesh(mesh_texture_file_container, image_folder_container)

    # Convert to GLB (check for host-side file existence)
    if ply_file.exists():
        logger.info(f"▶️ Convert {ply_file.name} to GLB")
        convert_mesh_to_glb(ply_file_container, glb_file_container)
        logger.success(f"✅ OpenMVS pipeline complete: {glb_file}")
    else:
        logger.warning(f"⚠️ Expected PLY file not found: {ply_file}")

    logger.info(f"⏱️ Elapsed: {time.time() - start:.1f}s")
